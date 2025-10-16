extends Unit
class_name Enemy

## 敵人專屬信號
signal action_ready()
signal action_count_changed(new_count: int)

## 敵人專屬屬性
@export var action_count_max: int = 3
@export var action_type: ActionType = ActionType.CHARGE

## 行動類型
enum ActionType {
	CHARGE,      # 衝撞玩家
	SKILL,       # 釋放技能
	TRAP,        # 布置陷阱
	BUFF         # 自我強化
}

## 運行時屬性
var current_action_count: int

func _ready():
	super._ready()
	current_action_count = action_count_max
	add_to_group("enemy")
	is_player_unit = false
	_update_action_count_display()

	# 物理參數現在由 Unit.gd 控制

## 減少行動倒數
func decrease_action_count(amount: int = 1):
	var old_count = current_action_count
	current_action_count -= amount

	var reason = ""
	if amount == 1:
		reason = "(Player launch or weakness hit)"
	else:
		reason = "(Multiple decrease)"

	print("    [", unit_name, "] Action count: ", old_count, " -> ", current_action_count, " ", reason)
	action_count_changed.emit(current_action_count)

	# 立即更新顯示
	_update_action_count_display()

	# 如果倒數歸零，執行行動並重置
	if current_action_count <= 0:
		print("    [", unit_name, "] ACTION READY!")
		action_ready.emit()

## 增加行動倒數
func increase_action_count(amount: int = 1):
	var old_count = current_action_count
	current_action_count += amount
	# 移除上限限制，允許弱點命中時超過最大值

	print("    [", unit_name, "] Action count: ", old_count, " -> ", current_action_count, " (Weakness hit reward)")
	action_count_changed.emit(current_action_count)

	# 立即更新顯示
	_update_action_count_display()


## 重置行動倒數
func reset_action_count():
	current_action_count = action_count_max
	action_count_changed.emit(current_action_count)
	_update_action_count_display()

## 執行行動
func execute_action():
	match action_type:
		ActionType.CHARGE:
			_execute_charge()
		ActionType.SKILL:
			_execute_skill()
		ActionType.TRAP:
			_execute_trap()
		ActionType.BUFF:
			_execute_buff()

## 衝撞行動
func _execute_charge():
	print("[", unit_name, "] Executing CHARGE action")

	# 找到最近的玩家單位
	var target = _find_nearest_player()
	if target:
		var direction = (target.global_position - global_position).normalized()
		var charge_power = 1500.0
		launch(direction, charge_power)

		# 移動中途隨機觸發 Smash（70% 機率，提高觸發率）
		var rand_value = randf()
		print("  Smash check: ", "%.2f" % rand_value, " > 0.3 = ", rand_value > 0.3)
		if rand_value > 0.3:  # 70% 機率
			var delay = randf_range(0.2, 0.5)  # 縮短延遲
			print("  Smash will trigger in ", "%.2f" % delay, " seconds")
			await get_tree().create_timer(delay).timeout
			print("  After delay: is_moving = ", is_moving)
			if is_moving:
				_trigger_enemy_smash()
			else:
				print("  Smash cancelled - enemy stopped moving")

## 技能行動
func _execute_skill():
	print("[", unit_name, "] Executing SKILL action")

	# 範圍攻擊
	var nearby_players = _get_nearby_players(300.0)
	for player in nearby_players:
		if player.has_method("take_damage"):
			var skill_damage = int(atk * 1.5)
			player.take_damage(skill_damage, false)

## 陷阱行動
func _execute_trap():
	print("[", unit_name, "] Executing TRAP action")

	# Enemy4 (Black Shadow) 不再放置陷阱
	if unit_name == "Black Shadow":
		print("  Black Shadow's trap ability disabled - no automatic damage")
		return

	# 在當前位置生成陷阱區域
	var trap_scene = preload("res://scenes/AreaTrap.tscn")
	if trap_scene:
		var trap = trap_scene.instantiate()
		trap.global_position = global_position
		trap.damage = atk
		trap.owner_attribute = attribute
		get_parent().add_child(trap)

## 強化行動
func _execute_buff():
	print("[", unit_name, "] Executing BUFF action")

	# 給自己添加攻擊 Buff
	add_buff("atk", 1.5, 10.0)

## 找到最近的玩家單位
func _find_nearest_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	var nearest = null
	var min_distance = INF

	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = player

	return nearest

## 取得附近玩家（純距離檢測，不產生物理交互）
func _get_nearby_players(radius: float) -> Array:
	var players = []
	var all_players = get_tree().get_nodes_in_group("player")

	for player in all_players:
		if player != self and is_instance_valid(player):
			var distance = global_position.distance_to(player.global_position)
			if distance <= radius:
				players.append(player)

	return players

## 敵人觸發 Smash
func _trigger_enemy_smash():
	if not is_moving:
		return

	print("[", unit_name, "] Enemy SMASH triggered!")

	# 1. 記錄敵人位置、速度和碰撞設定，並立即停止移動
	var enemy_position = global_position
	var enemy_velocity = linear_velocity
	var enemy_angular = angular_velocity
	var enemy_layer = collision_layer
	var enemy_mask = collision_mask

	# 記錄所有玩家位置、速度和碰撞設定
	var player_states = {}
	var all_players = get_tree().get_nodes_in_group("player")
	for player in all_players:
		player_states[player] = {
			"position": player.global_position,
			"velocity": player.linear_velocity,
			"angular": player.angular_velocity,
			"layer": player.collision_layer,
			"mask": player.collision_mask
		}
		# 設置標記，防止碰撞恢復邏輯干擾
		player.skip_collision_restore = true
		# 立即停止玩家移動
		player.linear_velocity = Vector2.ZERO
		player.angular_velocity = 0.0
		# 完全隔離物理
		player.collision_layer = 0
		player.collision_mask = 0

	# 停止敵人移動並完全隔離
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = 0
	collision_mask = 0

	# 2. 造成 AoE 傷害
	var smash_radius = 150.0
	var smash_multiplier = 1.5

	var nearby_players = _get_nearby_players(smash_radius)
	for player in nearby_players:
		var base_damage = atk * smash_multiplier
		var attr_multiplier = Attribute.get_multiplier(attribute, player.attribute)
		var final_damage = int(base_damage * attr_multiplier)
		player.take_damage(final_damage, false)

		# 顯示傷害浮字
		_spawn_damage_label(player.global_position, final_damage, false)

		print("Enemy Smash hit ", player.unit_name, " for ", final_damage, " damage")

	# 3. 等待物理引擎處理完畢
	await get_tree().process_frame
	await get_tree().process_frame

	# 4. 恢復敵人自己的狀態（位置不變，速度歸零，恢復碰撞）
	global_position = enemy_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = enemy_layer
	collision_mask = enemy_mask
	stop_movement()  # 設置 is_moving = false

	# 5. 恢復所有玩家狀態（位置不變，恢復原本的速度和碰撞）
	for player in player_states:
		if is_instance_valid(player):
			var state = player_states[player]
			player.global_position = state.position
			player.linear_velocity = state.velocity  # 恢復原本的速度
			player.angular_velocity = state.angular
			player.collision_layer = state.layer
			player.collision_mask = state.mask
			# 清除標記
			player.skip_collision_restore = false

## 覆寫受到傷害（命中弱點時增加敵人行動倒數）
func take_damage(damage: int, is_weakness: bool = false):
	print("==========================================")
	print("[", unit_name, "] *** TAKE_DAMAGE CALLED ***")
	print("  Damage: ", damage)
	print("  Is Weakness: ", is_weakness)
	print("  Current Action Count: ", current_action_count)
	super.take_damage(damage, is_weakness)

	# 弱點命中時增加敵人行動數（延遲敵人行動，對玩家有利）
	# 可以重複觸發 - 每次命中弱點都會增加行動數
	if is_weakness:
		print("  >>> WEAKNESS HIT! Increasing enemy action count (delaying enemy action)...")
		increase_action_count(1)
		print("  >>> New Action Count: ", current_action_count)
	else:
		print("  >>> NOT a weakness hit, no action count change")
	print("==========================================")

## 更新行動倒數顯示
func _update_action_count_display():
	var label = get_node_or_null("ActionCountLabel")
	if label:
		label.text = str(current_action_count)
		# 弱點命中時顯示特效
		if current_action_count < action_count_max:
			label.modulate = Color(1.0, 0.5, 0.5)  # 紅色閃爍
			var tween = get_tree().create_tween()
			tween.tween_property(label, "modulate", Color.WHITE, 0.3)
	else:
		print("[Warning] ActionCountLabel not found on ", unit_name)
