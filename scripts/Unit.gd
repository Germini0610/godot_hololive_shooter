extends RigidBody2D
class_name Unit

## 單位信號
signal hp_changed(new_hp: int, max_hp: int)
signal died()
signal damaged(damage: int, is_weakness: bool)

## 單位屬性
@export var unit_name: String = "Unit"
@export var attribute: Attribute.Type = Attribute.Type.RED
@export var max_hp: int = 1000
@export var atk: int = 100
@export var is_player_unit: bool = true

## 技能相關
@export var command_skill_cost: int = 3  # 0~5
@export var command_skill_name: String = "Command Skill"

## Soul Chip（自救次數）
@export var soul_chips: int = 3

## 弱點設定（扇形區域）
@export var weakness_center_angle: float = 180.0  # 弱點中心角度（預設：背後）
@export var weakness_arc_angle: float = 40.0  # 弱點扇形角度範圍（左右各20度）

## 運行時屬性
var current_hp: int
var current_buffs: Array[Dictionary] = []  # {type: "atk", value: 1.5, duration: -1}
var is_moving: bool = false
var velocity_magnitude: float = 0.0
var collision_enabled: bool = true
var skip_collision_restore: bool = false  # Smash 時跳過碰撞恢復
var is_active_attacker: bool = false  # 是否為主動攻擊者（主動移動 vs 被推動）
var trail_positions: Array[Vector2] = []  # 軌跡位置
const TRAIL_LENGTH: int = 10
const TRAIL_SPAWN_DISTANCE: float = 15.0
var last_trail_position: Vector2 = Vector2.ZERO

## 移動相關
const STOP_VELOCITY_THRESHOLD: float = 60.0  # 提高閾值，讓單位更快停止
const MAX_SPEED: float = 2500.0

## UI 引用
# 血條已移除，顯示在隊伍欄位

func _ready():
	current_hp = max_hp
	contact_monitor = true
	max_contacts_reported = 10
	body_entered.connect(_on_body_entered)

	# 關閉重力（俯視角 2D 彈珠台遊戲）
	gravity_scale = 0.0

	# 設置物理材質以增加彈力
	var new_material = PhysicsMaterial.new()
	new_material.bounce = 0.5
	physics_material_override = new_material

	# 提高線性阻尼，讓單位減速更快
	linear_damp = 1.0

	# 鎖定旋轉，防止圖片因碰撞而旋轉
	lock_rotation = true

	# 設置碰撞層
	if is_player_unit:
		collision_layer = 1  # Player layer
		collision_mask = 6   # Enemy layer (2) + Wall layer (4) = 6
	else:
		collision_layer = 2  # Enemy layer
		collision_mask = 7   # Player layer (1) + Enemy layer (2) + Wall layer (4) = 7（敵人之間也可以碰撞）

	last_trail_position = global_position

	# 連接 HP 變化信號並初始化顯示
	hp_changed.connect(_on_hp_changed)
	_update_hp_display()

	# 調整碰撞體大小以匹配視覺大小
	_adjust_collision_shape()

	# 為敵人添加弱點指示器
	if not is_player_unit:
		# 隨機化弱點方向（扇形弱點）
		weakness_center_angle = randf_range(0, 360)

		print("[", unit_name, "] Weakness initialized:")
		print("  Center angle: ", "%.1f" % weakness_center_angle, "°")
		print("  Arc angle: ", weakness_arc_angle, "° (±", weakness_arc_angle/2, "°)")

		_create_weakness_indicator()

func _physics_process(delta):
	velocity_magnitude = linear_velocity.length()

	# 更新軌跡效果
	_update_trail()

	# 檢查是否該停止移動
	if is_moving and velocity_magnitude < STOP_VELOCITY_THRESHOLD:
		stop_movement()

## 發射單位（給予速度）
func launch(direction: Vector2, power: float):
	var launch_velocity = direction.normalized() * power
	launch_velocity = launch_velocity.limit_length(MAX_SPEED)
	linear_velocity = launch_velocity
	is_moving = true
	is_active_attacker = true  # 主動發射，可造成傷害
	collision_enabled = true
	print("[Launch] ", unit_name, " launched as ACTIVE ATTACKER")

## 停止移動
func stop_movement():
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	is_moving = false
	is_active_attacker = false  # 停止時清除攻擊者狀態
	trail_positions.clear()  # 清除軌跡
	queue_redraw()

## 碰撞處理
func _on_body_entered(body):
	if not collision_enabled or not is_moving:
		return

	var battle_controllers = get_tree().get_nodes_in_group("battle_controller")
	var battle_controller = null
	if battle_controllers.size() > 0:
		battle_controller = battle_controllers[0]

	if body.is_in_group("enemy") and is_player_unit:
		# During the player's turn, any collision from a player unit to an enemy deals damage.
		if battle_controller and battle_controller.is_player_turn:
			_handle_enemy_collision(body)
		else:
			# If it's not the player's turn, or controller is not found, do nothing.
			# The collision will be handled from the enemy's perspective.
			pass

	elif body.is_in_group("player") and not is_player_unit:
		# An enemy hitting a player. Only deal damage if the enemy is the active attacker.
		if is_active_attacker:
			_handle_player_collision(body)
		else:
			print("[Collision] ", unit_name, " (PASSIVE) hit player but deals NO damage")

	elif body.is_in_group("enemy") and not is_player_unit:
		# Enemy-to-enemy collision never deals damage, only physics.
		_handle_enemy_to_enemy_collision(body)

## 處理與敵人碰撞
func _handle_enemy_collision(enemy):
	if not enemy.has_method("take_damage"):
		return

	var speed_scale = velocity_magnitude / MAX_SPEED
	var collision_point = global_position  # 攻擊者的位置
	var is_weakness = _check_weakness(enemy, collision_point)

	# 計算傷害
	var base_damage = atk * speed_scale
	var attr_multiplier = Attribute.get_multiplier(attribute, enemy.attribute)
	var buff_multiplier = _calculate_buff_multiplier()
	var weakness_multiplier = 1.5 if is_weakness else 1.0

	var final_damage = int(base_damage * attr_multiplier * buff_multiplier * weakness_multiplier)

	# Debug 輸出
	_print_damage_info(enemy, final_damage, speed_scale, attr_multiplier, buff_multiplier, is_weakness)

	# 造成傷害
	enemy.take_damage(final_damage, is_weakness)
	damaged.emit(final_damage, is_weakness)

	# 顯示傷害浮字
	_spawn_damage_label(enemy.global_position, final_damage, is_weakness)

	# 累積技能量表（由 BattleController 處理）
	if is_player_unit:
		var skill_gain = speed_scale * 20.0  # 根據速度給予能量
		get_tree().call_group("battle_controller", "add_skill_gauge", skill_gain)

	# 應用擊退效果（讓敵人被推動）
	_apply_knockback(enemy, speed_scale)

## 處理與玩家碰撞
func _handle_player_collision(player):
	if not player.has_method("take_damage"):
		return

	var speed_scale = velocity_magnitude / MAX_SPEED
	var collision_point = global_position
	var is_weakness = _check_weakness(player, collision_point)

	# 敵人攻擊玩家的傷害計算
	var base_damage = atk * speed_scale
	var attr_multiplier = Attribute.get_multiplier(attribute, player.attribute)
	var buff_multiplier = _calculate_buff_multiplier()
	var weakness_multiplier = 1.5 if is_weakness else 1.0

	var final_damage = int(base_damage * attr_multiplier * buff_multiplier * weakness_multiplier)

	player.take_damage(final_damage, is_weakness)

	# 顯示傷害浮字
	_spawn_damage_label(player.global_position, final_damage, is_weakness)

	# 應用擊退效果（讓玩家被推動）
	_apply_knockback(player, speed_scale)

## 處理敵人之間碰撞
func _handle_enemy_to_enemy_collision(other_enemy):
	# 敵人之間碰撞只產生物理推動效果，不造成傷害
	if is_instance_valid(other_enemy):
		# 計算碰撞力傳遞
		var push_direction = (other_enemy.global_position - global_position).normalized()

		# 增強力傳遞（從 50% 提高到 70%）
		var push_power = velocity_magnitude * 0.7

		# 如果對方已經在移動，疊加力量而非替換
		if other_enemy.linear_velocity.length() > 100.0:
			# 混合速度，保留原有動量
			var new_velocity = other_enemy.linear_velocity * 0.4 + push_direction * push_power * 0.6
			other_enemy.linear_velocity = new_velocity
		else:
			# 直接推動
			other_enemy.linear_velocity = push_direction * push_power

		# 設置狀態
		other_enemy.is_moving = true
		other_enemy.is_active_attacker = false  # 被推動的敵人不是主動攻擊者
		other_enemy.collision_enabled = true

		print("[Enemy Collision] ", unit_name, " pushed ", other_enemy.unit_name,
			  " with power ", "%.0f" % push_power, " (PASSIVE)")

## 檢查是否命中弱點（扇形區域判定）
func _check_weakness(target, collision_point: Vector2) -> bool:
	# 檢查目標是否有弱點屬性
	if not ("weakness_center_angle" in target and "weakness_arc_angle" in target):
		return false

	# 計算攻擊方向相對於目標的角度
	var to_attacker = collision_point - target.global_position
	var attack_angle = rad_to_deg(to_attacker.angle())

	# 正規化角度到 0-360
	if attack_angle < 0:
		attack_angle += 360

	# 計算弱點扇形範圍
	var weakness_center = target.weakness_center_angle
	var half_arc = target.weakness_arc_angle / 2.0
	var weakness_start = fmod(weakness_center - half_arc + 360, 360)
	var weakness_end = fmod(weakness_center + half_arc + 360, 360)

	# 檢查是否在弱點扇形範圍內
	var is_hit = false
	if weakness_start <= weakness_end:
		# 正常範圍（不跨越0度）
		is_hit = attack_angle >= weakness_start and attack_angle <= weakness_end
	else:
		# 跨越0度的範圍
		is_hit = attack_angle >= weakness_start or attack_angle <= weakness_end

	# 調試輸出
	print("[Weakness Check - Arc]")
	print("  Attack angle: ", "%.1f" % attack_angle, "°")
	print("  Weakness range: ", "%.1f" % weakness_start, "° - ", "%.1f" % weakness_end, "°")
	print("  Center: ", "%.1f" % weakness_center, "° (±", half_arc, "°)")
	print("  HIT: ", is_hit)

	return is_hit

## 計算 Buff 倍率
func _calculate_buff_multiplier() -> float:
	var multiplier = 1.0
	for buff in current_buffs:
		if buff.type == "atk":
			multiplier *= buff.value
	return multiplier

## 受到傷害
func take_damage(damage: int, is_weakness: bool = false):
	current_hp -= damage
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		die()

## 死亡
func die():
	died.emit()
	# 不立即刪除，由 BattleController 決定
	collision_enabled = false
	visible = false

## 使用 Soul Chip 復活
func use_soul_chip() -> bool:
	if soul_chips > 0:
		soul_chips -= 1
		current_hp = max_hp
		hp_changed.emit(current_hp, max_hp)
		visible = true
		collision_enabled = true
		return true
	return false

## 添加 Buff
func add_buff(buff_type: String, value: float, duration: float = -1.0):
	current_buffs.append({
		"type": buff_type,
		"value": value,
		"duration": duration,
		"timer": 0.0
	})

## 清除 Buff
func clear_buffs():
	current_buffs.clear()

## Debug 輸出傷害資訊
func _print_damage_info(target, damage: int, speed_scale: float, attr_mult: float, buff_mult: float, is_weak: bool):
	print("=== Damage Info ===")
	print("Attacker: ", unit_name, " (", Attribute.get_attribute_name(attribute), ")")
	var target_name = target.unit_name if "unit_name" in target else "Unknown"
	print("Target: ", target_name, " (", Attribute.get_attribute_name(target.attribute), ")")
	print("Speed Scale: ", "%.2f" % speed_scale)
	print("Attribute Multiplier: ", "%.2f" % attr_mult)
	print("Buff Multiplier: ", "%.2f" % buff_mult)
	print("Weakness Hit: ", is_weak)
	print("Final Damage: ", damage)
	print("==================")

## 觸發 Command Skill
func trigger_command_skill():
	print("[", unit_name, "] Command Skill: ", command_skill_name)
	# 子類別覆寫實作技能效果
	_execute_command_skill()

## 技能實作（子類別覆寫）
func _execute_command_skill():
	# 預設：範圍多段傷害
	var nearby_enemies = _get_nearby_enemies(200.0)
	for enemy in nearby_enemies:
		if enemy.has_method("take_damage"):
			var skill_damage = int(atk * 2.0)
			enemy.take_damage(skill_damage, false)
			print("Skill hit ", enemy.unit_name, " for ", skill_damage, " damage")

## 取得附近敵人（純距離檢測，不產生物理交互）
func _get_nearby_enemies(radius: float) -> Array:
	var enemies = []
	var target_group = "enemy" if is_player_unit else "player"
	var all_targets = get_tree().get_nodes_in_group(target_group)

	for target in all_targets:
		if target != self and is_instance_valid(target):
			var distance = global_position.distance_to(target.global_position)
			if distance <= radius:
				enemies.append(target)

	return enemies

## 生成傷害浮字
func _spawn_damage_label(position: Vector2, damage: int, is_weakness: bool):
	var damage_label = preload("res://scripts/DamageLabel.gd").new()
	damage_label.global_position = position
	get_tree().root.add_child(damage_label)
	damage_label.setup(damage, is_weakness, false)

## 應用擊退效果
func _apply_knockback(target, speed_scale: float):
	if not is_instance_valid(target):
		return

	# 計算擊退方向（從攻擊者指向目標）
	var knockback_direction = (target.global_position - global_position).normalized()

	# 增強擊退力度（提高基礎值和最大值）
	# 擊退力度與攻擊者速度成正比，範圍：800 ~ 2500
	var knockback_power = lerp(800.0, 2500.0, speed_scale)

	# 如果是弱點命中，額外增強擊退
	var collision_point = global_position
	var is_weakness = _check_weakness(target, collision_point)
	if is_weakness:
		knockback_power *= 2.0  # 弱點命中時擊退力增強 100%

	# 計算最終擊退速度
	var knockback_velocity = knockback_direction * knockback_power

	# 應用擊退速度
	target.linear_velocity = knockback_velocity

	# 設置目標為移動狀態（讓它可以繼續滑行）
	target.is_moving = true
	target.is_active_attacker = false  # 被推動的不是主動攻擊者，不能造成傷害
	target.collision_enabled = true

	print("[Knockback] ", unit_name, " knocked back ", target.unit_name,
		  " with power ", "%.0f" % knockback_power, " (speed scale: ", "%.2f" % speed_scale, ")",
		  " | Weakness: ", is_weakness,
		  " - Target is now PASSIVE (cannot deal damage)")

## 更新軌跡效果
func _update_trail():
	# 只在高速移動時顯示軌跡（速度 > 500）
	if velocity_magnitude > 500.0 and is_moving:
		# 檢查是否移動足夠距離才添加新軌跡點
		var distance_moved = global_position.distance_to(last_trail_position)
		if distance_moved >= TRAIL_SPAWN_DISTANCE:
			trail_positions.append(global_position)
			last_trail_position = global_position

			# 限制軌跡長度
			if trail_positions.size() > TRAIL_LENGTH:
				trail_positions.pop_front()

			queue_redraw()
	elif trail_positions.size() > 0:
		# 速度降低時逐漸消失
		trail_positions.pop_front()
		queue_redraw()

## 繪製軌跡效果
func _draw():
	if trail_positions.size() < 2:
		return

	# 繪製漸變軌跡
	for i in range(trail_positions.size() - 1):
		var alpha = float(i) / float(trail_positions.size())
		var width = 8.0 * alpha
		var start = to_local(trail_positions[i])
		var end = to_local(trail_positions[i + 1])

		# 根據單位屬性決定軌跡顏色
		var trail_color = Color.WHITE
		match attribute:
			Attribute.Type.RED:
				trail_color = Color(1.0, 0.3, 0.3, alpha * 0.6)
			Attribute.Type.BLUE:
				trail_color = Color(0.3, 0.5, 1.0, alpha * 0.6)
			Attribute.Type.GREEN:
				trail_color = Color(0.3, 1.0, 0.3, alpha * 0.6)
			Attribute.Type.BLACK:
				trail_color = Color(0.3, 0.3, 0.3, alpha * 0.6)
			Attribute.Type.WHITE:
				trail_color = Color(1.0, 1.0, 1.0, alpha * 0.6)
			Attribute.Type.GOLD:
				trail_color = Color(1.0, 0.84, 0.0, alpha * 0.6)
			Attribute.Type.SILVER:
				trail_color = Color(0.75, 0.75, 0.75, alpha * 0.6)

		draw_line(start, end, trail_color, width)

## HP 變化回調
func _on_hp_changed(new_hp: int, _max_hp: int):
	_update_hp_display()

## 更新 HP 顯示
func _update_hp_display():
	# 如果是玩家單位，更新隊伍欄位的血條
	if is_player_unit:
		var ui = get_tree().get_nodes_in_group("battle_ui")
		if ui.size() > 0 and ui[0].has_method("update_leader_hp"):
			ui[0].update_leader_hp(current_hp, max_hp)
	else:
		# 敵人單位，更新自己的血條
		var hp_bar = get_node_or_null("HPBar")
		if hp_bar and hp_bar is ProgressBar:
			hp_bar.max_value = float(max_hp)
			hp_bar.value = float(current_hp)

## 調整碰撞體大小以匹配視覺大小
func _adjust_collision_shape():
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		# 找到視覺精靈節點
		var sprite_node = get_node_or_null("Sprite")
		var base_radius = 30.0

		if sprite_node:
			if sprite_node is CircleSprite:
				# 如果是自定義圓形精靈，使用其半徑
				base_radius = sprite_node.radius
			elif sprite_node is Sprite2D and sprite_node.texture:
				# 如果是 Sprite2D，根據紋理大小和縮放計算合適的半徑
				var texture_size = sprite_node.texture.get_size()
				var scale = sprite_node.scale
				var avg_size = (texture_size.x * scale.x + texture_size.y * scale.y) / 2.0
				base_radius = avg_size / 2.0

		# 玩家單位的碰撞體積擴大 30%，讓視覺碰撞更符合邏輯
		if is_player_unit:
			collision_shape.shape.radius = base_radius * 1.3
			print("[", unit_name, "] Player collision radius enlarged: ", base_radius, " -> ", collision_shape.shape.radius)
		else:
			collision_shape.shape.radius = base_radius

## 創建弱點指示器
func _create_weakness_indicator():
	# 創建一個節點來顯示弱點區域
	var weakness_node = Node2D.new()
	weakness_node.name = "WeaknessIndicator"
	weakness_node.z_index = -1  # 顯示在單位後方

	# 加載並設置腳本
	var script_path = "res://scripts/WeaknessIndicator.gd"
	if ResourceLoader.exists(script_path):
		var script = load(script_path)
		weakness_node.set_script(script)

	add_child(weakness_node)

## 繪製弱點區域（已棄用 - 改用 WeaknessIndicator.gd）
func _draw_weakness_on_node(node: Node2D):
	# 此函數已被 WeaknessIndicator.gd 取代
	pass
