extends Node2D
class_name BattleController

## 戰鬥控制器信號
signal skill_gauge_changed(current: int, max: int)
signal turn_changed(turn: int)
signal battle_ended(victory: bool)
signal smash_ready(ready: bool)
signal skill_ready(ready: bool)

## 戰場引用
@export var battlefield: Node2D
@export var ui_controller: Node

## 技能量表
const MAX_SKILL_GAUGE: int = 5
var current_skill_gauge: float = 0.0

## 回合系統
var current_turn: int = 1
var player_moves_this_turn: int = 0
var is_player_turn: bool = true

## 隊伍
var player_team: Team
var current_active_unit: Unit = null

## 輸入狀態
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_current_pos: Vector2
var can_use_smash: bool = false
var can_use_skill: bool = false

## 1-More 系統
var one_more_available: bool = false

## 弱點觸發記錄（避免重複觸發）
var weakness_hit_enemies: Array = []  # 記錄本回合已觸發弱點的敵人

## Debug 設定
@export var debug_enabled: bool = true
@export var show_physics_debug: bool = false

## 戰場設定
const MIN_LAUNCH_POWER: float = 300.0
const MAX_LAUNCH_POWER: float = 2500.0
const POWER_SCALE: float = 2.5
const MAX_POWER_THRESHOLD: float = 200.0  # 拖曳超過此距離就使用最大 power

func _ready():
	add_to_group("battle_controller")

	# 初始化隊伍
	player_team = Team.new()
	add_child(player_team)

	# 連接信號
	skill_gauge_changed.connect(_on_skill_gauge_changed)

	# 連接所有敵人的死亡信號
	call_deferred("_connect_enemy_signals")

	# 設置初始活躍單位
	call_deferred("_initialize_active_unit")

	print("[BattleController] Initialized")

## 連接敵人信號
func _connect_enemy_signals():
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died.bind(enemy))

## 初始化活躍單位
func _initialize_active_unit():
	var player_units = get_tree().get_nodes_in_group("player")
	if not player_units.is_empty():
		current_active_unit = player_units[0]
		print("[BattleController] Initial active unit: ", current_active_unit.unit_name)

func _process(delta):
	if is_player_turn:
		_handle_input()

	# 更新 UI
	if ui_controller and ui_controller.has_method("update_turn"):
		ui_controller.update_turn(current_turn)

## 處理輸入
func _handle_input():
	# 開始拖曳
	if Input.is_action_just_pressed("ui_click") and not is_dragging and current_active_unit:
		if not current_active_unit.is_moving:
			is_dragging = true
			drag_start_pos = get_global_mouse_position()
			drag_current_pos = drag_start_pos
			can_use_smash = false
			can_use_skill = current_skill_gauge >= current_active_unit.command_skill_cost
			skill_ready.emit(can_use_skill)

	# 拖曳中
	if is_dragging:
		drag_current_pos = get_global_mouse_position()

		# 計算方向和力度
		var direction = drag_start_pos - drag_current_pos
		var drag_distance = direction.length()

		# 如果拖曳距離超過閾值，直接使用最大 power
		var power: float
		if drag_distance >= MAX_POWER_THRESHOLD:
			power = MAX_LAUNCH_POWER
		else:
			power = drag_distance * POWER_SCALE
			power = clamp(power, MIN_LAUNCH_POWER, MAX_LAUNCH_POWER)

		# 繪製拖曳軌跡（可選）- 持續重繪以顯示動畫
		queue_redraw()

	# 結束拖曳（發射）
	if Input.is_action_just_released("ui_click") and is_dragging:
		is_dragging = false
		_launch_unit()
		queue_redraw()

	# 移動中點擊：Smash 或 Skill
	if Input.is_action_just_pressed("ui_click") and not is_dragging:
		if current_active_unit and current_active_unit.is_moving:
			if can_use_skill and current_skill_gauge >= current_active_unit.command_skill_cost:
				_trigger_skill()
			elif can_use_smash:
				_trigger_smash()

## 發射單位
func _launch_unit():
	if not current_active_unit:
		return

	var direction = drag_start_pos - drag_current_pos
	var drag_distance = direction.length()

	if drag_distance < 10.0:  # 太短不發射
		return

	# 清空弱點觸發記錄（新的一次行動開始）
	weakness_hit_enemies.clear()
	print("[BattleController] Weakness hit tracking cleared for new action")

	# 如果拖曳距離超過閾值，直接使用最大 power
	var power: float
	if drag_distance >= MAX_POWER_THRESHOLD:
		power = MAX_LAUNCH_POWER
		print("[BattleController] MAX POWER! Launching unit with power: ", power)
	else:
		power = drag_distance * POWER_SCALE
		power = clamp(power, MIN_LAUNCH_POWER, MAX_LAUNCH_POWER)
		print("[BattleController] Launching unit with power: ", power, " (", int((power / MAX_LAUNCH_POWER) * 100), "%)")

	current_active_unit.launch(direction.normalized(), power)

	# 允許 Smash
	can_use_smash = true
	smash_ready.emit(true)

	# 等待移動結束
	await get_tree().create_timer(0.1).timeout
	_wait_for_movement_end()

## 等待移動結束
func _wait_for_movement_end():
	while current_active_unit and current_active_unit.is_moving:
		await get_tree().create_timer(0.1).timeout

	# 移動結束
	_on_movement_ended()

## 移動結束處理
func _on_movement_ended():
	can_use_smash = false
	smash_ready.emit(false)

	# 檢查是否觸發 1-More
	if not one_more_available:
		_end_player_move()
	else:
		print("[BattleController] 1-More! Extra move granted.")
		one_more_available = false

## 觸發 Smash
func _trigger_smash():
	if not current_active_unit or not current_active_unit.is_moving:
		return

	print("[BattleController] SMASH triggered!")

	# Stop the player's movement
	var smash_position = current_active_unit.global_position
	current_active_unit.stop_movement()

	# Instantiate the ripple effect
	var ripple_scene = preload("res://scenes/SmashRipple.tscn")
	if ripple_scene:
		var ripple = ripple_scene.instantiate() as SmashRipple
		if ripple:
			ripple.global_position = smash_position
			
			# Configure the ripple via setup function
			var smash_multiplier = 1.5
			var damage = current_active_unit.atk * smash_multiplier
			var attribute = current_active_unit.attribute
			ripple.setup(damage, attribute)
			
			# Add to the scene and set a high Z-index to ensure visibility
			ripple.z_index = 100
			add_child(ripple)
			print("[BattleController] Smash ripple instance created at: ", ripple.global_position)

	# Smash has been used
	can_use_smash = false
	smash_ready.emit(false)

## 觸發技能
func _trigger_skill():
	if not current_active_unit:
		return

	if current_skill_gauge < current_active_unit.command_skill_cost:
		return

	print("[BattleController] Command Skill triggered!")

	# 消耗技能量表
	add_skill_gauge(-float(current_active_unit.command_skill_cost))

	# 觸發單位技能
	current_active_unit.trigger_command_skill()

	# 停止移動
	current_active_unit.stop_movement()

	can_use_skill = false
	skill_ready.emit(false)

## 增加技能量表
func add_skill_gauge(amount: float):
	current_skill_gauge += amount
	current_skill_gauge = clamp(current_skill_gauge, 0.0, float(MAX_SKILL_GAUGE))
	skill_gauge_changed.emit(floor(current_skill_gauge), MAX_SKILL_GAUGE)

## 結束玩家移動
func _end_player_move():
	player_moves_this_turn += 1

	# 等待所有物理慣性結束後，才開始敵人行動
	await _wait_for_all_units_stopped()

	# 所有敵人行動倒數 -1，並逐一執行行動
	await _process_enemy_actions()

	# 重新選擇下一個活躍單位
	_select_next_unit()

## 等待所有單位停止移動
func _wait_for_all_units_stopped():
	print("[BattleController] Waiting for all units to stop...")

	var max_wait_time = 5.0  # 最多等待 5 秒
	var wait_elapsed = 0.0
	var check_interval = 0.1

	while wait_elapsed < max_wait_time:
		var any_moving = false

		# 檢查所有玩家單位
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			if player.is_moving:
				any_moving = true
				break

		# 檢查所有敵人單位
		if not any_moving:
			var enemies = get_tree().get_nodes_in_group("enemy")
			for enemy in enemies:
				if enemy.is_moving:
					any_moving = true
					break

		# 如果所有單位都停止了，結束等待
		if not any_moving:
			print("[BattleController] All units stopped. Proceeding to enemy actions.")
			return

		# 繼續等待
		await get_tree().create_timer(check_interval).timeout
		wait_elapsed += check_interval

	print("[BattleController] Wait timeout reached. Forcing stop.")

## 處理敵人行動（逐一執行）
func _process_enemy_actions():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return

	print("\n[BattleController] === Processing Enemy Actions ===")
	
	# First, decrease all enemy counters due to the player's move
	print("  Player launched -> All enemies action count -1")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.current_hp > 0:
			enemy.decrease_action_count(1)

	# Give a small delay for the UI to update if needed
	await get_tree().create_timer(0.5).timeout

	# Now, execute actions for enemies whose counter is at or below zero, one by one
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.current_hp <= 0:
			continue

		if enemy.current_action_count <= 0:
			print("  -> Executing ", enemy.unit_name, "'s action...")
			enemy.execute_action()
			enemy.reset_action_count() # Reset the counter immediately after starting the action
			
			# Wait for this specific enemy's action to complete
			await _wait_for_enemy_action_complete(enemy)
			
			# A small pause between enemy actions
			await get_tree().create_timer(0.5).timeout

	print("[BattleController] === Enemy Actions Complete ===\n")

## 等待敵人行動完成
func _wait_for_enemy_action_complete(enemy: Enemy):
	var max_wait_time = 5.0  # 最多等待 5 秒
	var wait_elapsed = 0.0
	var check_interval = 0.1

	while wait_elapsed < max_wait_time:
		# 檢查敵人是否還在移動
		if not is_instance_valid(enemy):
			return

		if not enemy.is_moving:
			print("[BattleController] Enemy ", enemy.unit_name, " action complete.")
			return

		await get_tree().create_timer(check_interval).timeout
		wait_elapsed += check_interval

	print("[BattleController] Enemy action timeout. Forcing stop.")

## 選擇下一個單位
func _select_next_unit():
	var frontline = player_team.get_frontline_members()
	if frontline.is_empty():
		_check_battle_end()
		return

	# 簡單輪換：選第一個活著的
	current_active_unit = frontline[0]
	print("[BattleController] Next unit: ", current_active_unit.unit_name)

## 檢查戰鬥結束
func _check_battle_end():
	var alive_players = player_team.get_alive_members()
	var alive_enemies = get_tree().get_nodes_in_group("enemy").filter(func(e): return e.current_hp > 0)

	if alive_players.is_empty():
		battle_ended.emit(false)
		print("[BattleController] Battle Lost!")
	elif alive_enemies.is_empty():
		battle_ended.emit(true)
		print("[BattleController] Battle Won!")

## 取得附近敵人
func _get_nearby_enemies(pos: Vector2, radius: float) -> Array:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearby = []
	for enemy in enemies:
		if enemy.global_position.distance_to(pos) <= radius:
			nearby.append(enemy)
	return nearby

## 敵人死亡處理
func _on_enemy_died(enemy: Enemy):
	print("[BattleController] Enemy died: ", enemy.unit_name)
	one_more_available = true

	# 延遲刪除敵人
	await get_tree().create_timer(0.5).timeout
	enemy.queue_free()

	# 檢查戰鬥結束
	_check_battle_end()

## 繪製拖曳軌跡
func _draw():
	if is_dragging and current_active_unit:
		var direction = drag_start_pos - drag_current_pos
		var drag_distance = direction.length()
		var arrow_end = current_active_unit.global_position + direction.normalized() * 100

		# 如果達到最大 power，顯示特殊顏色
		var line_color = Color.YELLOW
		var circle_color = Color.RED
		var line_width = 3.0

		if drag_distance >= MAX_POWER_THRESHOLD:
			line_color = Color.ORANGE_RED  # 達到最大 power 時變成橙紅色
			circle_color = Color.ORANGE_RED
			line_width = 5.0  # 線條更粗

			# 繪製脈衝效果圓圈
			var pulse = abs(sin(Time.get_ticks_msec() * 0.01))
			draw_circle(arrow_end, 10.0 + pulse * 5.0, Color(1.0, 0.3, 0.0, 0.3 + pulse * 0.3))

		draw_line(current_active_unit.global_position, arrow_end, line_color, line_width)
		draw_circle(arrow_end, 10.0, circle_color)

## 設置當前單位
func set_active_unit(unit: Unit):
	current_active_unit = unit
	print("[BattleController] Active unit set to: ", unit.unit_name)

## UI 回調
func _on_skill_gauge_changed(current: int, max: int):
	if ui_controller and ui_controller.has_method("update_skill_gauge"):
		ui_controller.update_skill_gauge(current, max)

## 使用 Soul Chip
func use_soul_chip(unit: Unit) -> bool:
	if unit.use_soul_chip():
		print("[BattleController] Soul Chip used for ", unit.unit_name)
		return true
	return false

## 設置 Debug 模式
func set_debug_mode(enabled: bool):
	debug_enabled = enabled
	if enabled:
		print("[BattleController] Debug mode enabled")

## 切換物理可視化
func toggle_physics_debug():
	show_physics_debug = not show_physics_debug
	get_tree().debug_collisions_hint = show_physics_debug

## 檢查並記錄弱點觸發（避免重複觸發）
func check_and_record_weakness_hit(enemy) -> bool:
	# 檢查該敵人是否已經在本次行動中觸發過弱點
	if enemy in weakness_hit_enemies:
		print("[BattleController] Weakness already triggered for ", enemy.unit_name, " this action - IGNORING")
		return false

	# 記錄此敵人已觸發弱點
	weakness_hit_enemies.append(enemy)
	print("[BattleController] Weakness triggered for ", enemy.unit_name, " - RECORDED")
	return true
