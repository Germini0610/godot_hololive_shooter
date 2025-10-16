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

## Smash 演出控制
var is_smash_performing: bool = false  # Smash 演出進行中
var dying_enemies: Array[Enemy] = []   # 正在播放死亡動畫的敵人列表

## 1-More 系統
var one_more_available: bool = false

## 弱點觸發記錄（避免重複觸發）
var weakness_hit_enemies: Array = []  # 記錄本回合已觸發弱點的敵人

## Debug 設定
@export var debug_enabled: bool = true
@export var show_physics_debug: bool = false

## Demo 模式設定
@export var enable_ina_skill_demo: bool = true  # 啟用 Ina 技能演示
var skill_demo_controller: InaSkillDemo = null
var player_control_enabled: bool = false  # 演示完成前禁用玩家控制

## 戰場設定
const MIN_LAUNCH_POWER: float = 300.0
const MAX_LAUNCH_POWER: float = 2500.0
const POWER_SCALE: float = 2.5
const MAX_POWER_THRESHOLD: float = 200.0  # 拖曳超過此距離就使用最大 power

## Smash 演出設定（底層邏輯配置）
const SMASH_PERFORMANCE_DURATION: float = 1.2  # Smash 演出總時長（波紋 + VFX + 緩衝）
const SMASH_RIPPLE_DURATION: float = 1.0      # 波紋擴散時長
const SMASH_BUFFER_TIME: float = 0.2          # 演出緩衝時間

## 敵人死亡演出設定（底層邏輯配置）
const ENEMY_FADEOUT_DURATION: float = 0.8    # 敵人淡出動畫時長
const ENEMY_DEATH_DELAY: float = 0.9         # 敵人死亡總等待時長（必須 >= 淡出時長 + 小緩衝）

func _init():
	# 底層邏輯初始化
	print("[BattleController] Initializing core logic...")
	print("[BattleController] - Smash performance duration: ", SMASH_PERFORMANCE_DURATION, "s")
	print("[BattleController] - Ripple duration: ", SMASH_RIPPLE_DURATION, "s")
	print("[BattleController] - Buffer time: ", SMASH_BUFFER_TIME, "s")
	print("[BattleController] - Enemy death delay: ", ENEMY_DEATH_DELAY, "s")
	print("[BattleController] - Enemy fadeout duration: ", ENEMY_FADEOUT_DURATION, "s")

func _ready():
	add_to_group("battle_controller")

	# 初始化隊伍
	player_team = Team.new()
	add_child(player_team)

	# 尋找 UI 控制器
	await get_tree().process_frame
	var ui_nodes = get_tree().get_nodes_in_group("battle_ui")
	if ui_nodes.size() > 0:
		ui_controller = ui_nodes[0]
		print("[BattleController] UI Controller found: ", ui_controller.name)
	else:
		print("[BattleController] WARNING: UI Controller not found!")

	# 連接信號
	skill_gauge_changed.connect(_on_skill_gauge_changed)

	# 連接所有敵人的死亡信號
	call_deferred("_connect_enemy_signals")

	# 設置初始活躍單位
	call_deferred("_initialize_active_unit")

	# 初始化技能演示控制器
	if enable_ina_skill_demo:
		call_deferred("_initialize_skill_demo")

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

## 初始化技能演示
func _initialize_skill_demo():
	# 檢查是否有 Ina 單位
	var player_units = get_tree().get_nodes_in_group("player")
	var ina_unit: InaUnit = null

	for unit in player_units:
		if unit is InaUnit:
			ina_unit = unit
			break

	if not ina_unit:
		print("[BattleController] No Ina unit found, skipping demo")
		player_control_enabled = true
		return

	# 創建演示控制器
	skill_demo_controller = InaSkillDemo.new()
	add_child(skill_demo_controller)

	# 連接信號
	skill_demo_controller.all_demos_finished.connect(_on_skill_demo_finished)

	# 獲取敵人列表
	var enemies = get_tree().get_nodes_in_group("enemy")

	# 開始演示序列
	print("[BattleController] Starting Ina skill demonstration...")
	player_control_enabled = false  # 禁用玩家控制
	skill_demo_controller.start_demo_sequence(ina_unit, enemies, self)

## 演示完成回調
func _on_skill_demo_finished():
	print("[BattleController] Skill demo finished, enabling player control")
	player_control_enabled = true

func _process(delta):
	if is_player_turn:
		_handle_input()

	# 更新 UI
	if ui_controller and ui_controller.has_method("update_turn"):
		ui_controller.update_turn(current_turn)

## 處理輸入
func _handle_input():
	# 如果演示模式啟用且玩家控制未啟用，忽略輸入
	if enable_ina_skill_demo and not player_control_enabled:
		return

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
	while current_active_unit and (current_active_unit.is_moving or is_smash_performing):
		await get_tree().create_timer(0.1).timeout

	# 如果 Smash 正在演出，不要在這裡調用 _on_movement_ended()
	# 因為 Smash 會自己調用
	if not is_smash_performing:
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

## ========== 底層邏輯：Smash 演出控制 ==========
## 執行 Smash 演出流程（可被重複調用的底層方法）
##
## 這是核心的演出控制邏輯，確保以下流程順序：
## 1. 玩家發射 → 移動中 → 點擊觸發 Smash
## 2. 立即停止移動 + 設置演出標志
## 3. 波紋擴散 + 擊中敵人 + VFX 播放
## 4. 【暫停演出時間】← 提升打擊感的關鍵！
## 5. 清除演出標志 → 敵人開始行動
##
## 使用方式：
##   _perform_smash_sequence(position, damage, attribute)
##
## 配置常量：
##   SMASH_PERFORMANCE_DURATION - 總演出時長
##   SMASH_RIPPLE_DURATION - 波紋時長
##   SMASH_BUFFER_TIME - 緩衝時間
func _perform_smash_sequence(smash_position: Vector2, damage: float, attribute: Attribute.Type, is_ina: bool = false, ina_flip_range: float = 0.0) -> void:
	print("[BattleController] ========== Smash Performance Sequence Started ==========")

	# 步驟 1：設置演出標志，阻止流程繼續
	is_smash_performing = true
	print("[BattleController] Step 1: Performance flag set - flow paused")

	# 步驟 2：停止玩家移動（如果單位仍然有效）
	if current_active_unit and is_instance_valid(current_active_unit) and current_active_unit.is_inside_tree():
		current_active_unit.linear_velocity = Vector2.ZERO
		current_active_unit.angular_velocity = 0.0
		current_active_unit.stop_movement()
		print("[BattleController] Step 2: Player stopped at ", smash_position)
	else:
		print("[BattleController] Step 2: Player unit invalid/disappeared, but continuing with Smash effects")

	# 步驟 3：觸發角色特效（如 Ina 翻牌）
	# !! 修正：即使單位消失，也要播放特效 !!
	if is_ina:
		print("[BattleController] Step 3: Triggering Ina flip card effect")
		# 嘗試調用單位方法（如果單位還在）
		if current_active_unit and is_instance_valid(current_active_unit) and current_active_unit.is_inside_tree():
			current_active_unit.on_flip_card(smash_position)
		else:
			# 單位已消失，直接播放特效和執行吸血邏輯
			print("[BattleController] Unit disappeared, manually triggering flip card effects")
			_manual_ina_flip_card(smash_position, ina_flip_range)

	# 步驟 4：生成波紋特效
	print("[BattleController] Step 4: Creating ripple effect...")
	_spawn_smash_ripple(smash_position, damage, attribute)

	# 步驟 5：等待演出完成（波紋 + VFX + 緩衝時間）
	print("[BattleController] Step 5: Waiting for performance (", SMASH_PERFORMANCE_DURATION, "s)...")
	await get_tree().create_timer(SMASH_PERFORMANCE_DURATION).timeout

	# 步驟 6：等待所有正在死亡的敵人完成動畫
	if not dying_enemies.is_empty():
		print("[BattleController] Step 6: Waiting for ", dying_enemies.size(), " dying enemies to finish death animations...")
		await _wait_for_all_death_animations()
		print("[BattleController] All death animations completed!")
	else:
		print("[BattleController] Step 6: No dying enemies, continuing...")

	# 步驟 7：清除演出標志，恢復流程
	is_smash_performing = false
	print("[BattleController] Step 7: Performance complete - flow resumed")
	print("[BattleController] ========== Smash Performance Sequence Ended ==========")

	# 步驟 8：調用移動結束處理
	_on_movement_ended()

## 等待所有死亡動畫完成（底層方法）
func _wait_for_all_death_animations() -> void:
	var max_wait_time = 2.0  # 最多等待 2 秒
	var wait_elapsed = 0.0
	var check_interval = 0.1

	while wait_elapsed < max_wait_time:
		# 清理已經無效的敵人引用
		dying_enemies = dying_enemies.filter(func(e): return is_instance_valid(e) and e.is_inside_tree())

		# 如果所有死亡動畫都完成了
		if dying_enemies.is_empty():
			print("[BattleController] All dying enemies cleared")
			return

		print("[BattleController] Still waiting for ", dying_enemies.size(), " enemies to finish death animations...")
		await get_tree().create_timer(check_interval).timeout
		wait_elapsed += check_interval

	print("[BattleController] WARNING: Death animation wait timeout, forcing continue")
	dying_enemies.clear()

## 生成 Smash 波紋（底層方法）
func _spawn_smash_ripple(position: Vector2, damage: float, attribute: Attribute.Type) -> void:
	var ripple_scene = preload("res://scenes/SmashRipple.tscn")
	if not ripple_scene:
		print("[BattleController] ERROR: Failed to load ripple scene")
		return

	var ripple = ripple_scene.instantiate()
	if not ripple:
		print("[BattleController] ERROR: Failed to instantiate ripple")
		return

	ripple.global_position = position
	ripple.z_index = 100

	if ripple.has_method("setup"):
		ripple.setup(damage, attribute)

	# 添加到戰場
	var battlefield = get_parent()
	if battlefield:
		battlefield.add_child(ripple)
		print("[BattleController] Ripple spawned at ", position, " with damage ", damage)
	else:
		add_child(ripple)
		print("[BattleController] WARNING: Battlefield not found, added to BattleController")

## 觸發 Smash（上層調用接口）
func _trigger_smash():
	if not current_active_unit or not current_active_unit.is_moving:
		return

	print("[BattleController] SMASH triggered!")

	# 禁用 Smash 按鈕
	can_use_smash = false
	smash_ready.emit(false)

	# !! 重要：立即保存單位數據，防止單位在碰撞中消失導致數據丟失 !!
	var smash_position = current_active_unit.global_position
	var smash_multiplier = 1.5
	var damage = current_active_unit.atk * smash_multiplier
	var attribute = current_active_unit.attribute
	var unit_type = current_active_unit.get_script()  # 保存單位類型以判斷是否為 InaUnit
	var is_ina = current_active_unit is InaUnit
	var ina_flip_range = current_active_unit.flip_range if is_ina else 0

	# 調用底層演出方法（傳遞保存的數據）
	_perform_smash_sequence(smash_position, damage, attribute, is_ina, ina_flip_range)

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
	var old_gauge = current_skill_gauge
	current_skill_gauge += amount
	current_skill_gauge = clamp(current_skill_gauge, 0.0, float(MAX_SKILL_GAUGE))
	var gauge_filled = int(floor(current_skill_gauge))
	print("[BattleController] Skill Gauge: ", "%.3f" % old_gauge, " -> ", "%.3f" % current_skill_gauge, " (+", "%.3f" % amount, ") | Filled: ", gauge_filled, "/", MAX_SKILL_GAUGE)
	skill_gauge_changed.emit(gauge_filled, MAX_SKILL_GAUGE)

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

## ========== 底層邏輯：敵人死亡處理 ==========
## 敵人死亡處理（徹底優化版本）
## 問題修復：
## 1. 防止重複調用 queue_free
## 2. 安全的實例檢查
## 3. 死亡演出效果
## 4. 正確的 1-More 觸發時機
func _on_enemy_died(enemy: Enemy):
	# 第一重保護：檢查敵人是否有效
	if not is_instance_valid(enemy):
		print("[BattleController] WARNING: Invalid enemy in _on_enemy_died")
		return

	# 第二重保護：檢查是否在場景樹中
	if not enemy.is_inside_tree():
		print("[BattleController] WARNING: Enemy not in tree in _on_enemy_died")
		return

	# 第三重保護：防止重複處理（使用元數據標記）
	if enemy.has_meta("_death_processed"):
		print("[BattleController] Enemy ", enemy.unit_name, " death already processed, skipping")
		return

	enemy.set_meta("_death_processed", true)
	print("[BattleController] ========== Enemy Death Sequence Started ==========")
	print("[BattleController] Enemy died: ", enemy.unit_name)

	# 添加到正在死亡的敵人列表（用於 Smash 演出等待）
	if not dying_enemies.has(enemy):
		dying_enemies.append(enemy)
		print("[BattleController] Added to dying_enemies list (total: ", dying_enemies.size(), ")")

	# 立即觸發 1-More（在演出開始時就授予，不等待）
	one_more_available = true
	print("[BattleController] 1-More granted!")

	# 停止敵人的所有行動和物理
	if enemy.has_method("stop_movement"):
		enemy.stop_movement()
	enemy.linear_velocity = Vector2.ZERO
	enemy.angular_velocity = 0.0

	# 播放死亡演出（淡出效果）並等待完成
	print("[BattleController] Playing death animation...")
	var death_tween = _play_enemy_death_effect(enemy)

	# 等待 Tween 動畫完成
	if death_tween:
		print("[BattleController] Waiting for death animation tween to finish...")
		await death_tween.finished
		print("[BattleController] Death animation tween completed!")
	else:
		# 如果 Tween 創建失敗，使用固定延遲作為後備
		print("[BattleController] WARNING: Tween not created, using fallback delay...")
		await get_tree().create_timer(ENEMY_DEATH_DELAY).timeout

	# 再次檢查敵人是否仍然有效（可能在等待期間被其他邏輯刪除）
	if not is_instance_valid(enemy):
		print("[BattleController] Enemy already removed during death animation")
		_check_battle_end()
		return

	if not enemy.is_inside_tree():
		print("[BattleController] Enemy already removed from tree")
		_check_battle_end()
		return

	# 從正在死亡列表中移除
	if dying_enemies.has(enemy):
		dying_enemies.erase(enemy)
		print("[BattleController] Removed from dying_enemies list (remaining: ", dying_enemies.size(), ")")

	# 安全刪除敵人
	print("[BattleController] Safely removing enemy...")
	call_deferred("_safe_remove_enemy", enemy)

	# 檢查戰鬥結束（使用延遲確保敵人已被移除）
	await get_tree().process_frame
	_check_battle_end()

	print("[BattleController] ========== Enemy Death Sequence Ended ==========")

## 播放敵人死亡特效（返回 Tween 以便等待完成）
func _play_enemy_death_effect(enemy: Enemy) -> Tween:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return null

	# 創建淡出動畫
	var tween = create_tween()
	tween.set_parallel(true)

	# 淡出
	tween.tween_property(enemy, "modulate:a", 0.0, ENEMY_FADEOUT_DURATION)

	# 縮小效果
	tween.tween_property(enemy, "scale", Vector2(0.5, 0.5), ENEMY_FADEOUT_DURATION)

	# 可選：輕微旋轉（RigidBody2D 一定有 rotation 屬性）
	tween.tween_property(enemy, "rotation", enemy.rotation + PI * 2, ENEMY_FADEOUT_DURATION)

	# 返回 Tween 對象以便調用者等待完成
	return tween

## 安全移除敵人（底層方法）
func _safe_remove_enemy(enemy: Enemy) -> void:
	# 最終檢查
	if not is_instance_valid(enemy):
		print("[BattleController] Cannot remove enemy: already invalid")
		return

	if not enemy.is_inside_tree():
		print("[BattleController] Cannot remove enemy: not in tree")
		return

	# 斷開所有信號連接（防止死亡後還觸發信號）
	if enemy.has_signal("died"):
		# 嘗試斷開，即使已經斷開也不會報錯
		if enemy.died.is_connected(_on_enemy_died):
			enemy.died.disconnect(_on_enemy_died)

	# 執行刪除
	print("[BattleController] Executing queue_free on ", enemy.unit_name)
	enemy.queue_free()

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
	if ui_controller and ui_controller.has_method("update_skill_gauge_realtime"):
		# 傳遞實際的浮點數能量值以支援即時進度顯示
		ui_controller.update_skill_gauge_realtime(current_skill_gauge, max)

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

## 啟用玩家控制（由演示控制器調用）
func enable_player_control():
	player_control_enabled = true
	print("[BattleController] Player control enabled")

## 跳過技能演示
func skip_skill_demo():
	if skill_demo_controller and skill_demo_controller.is_demo_active():
		skill_demo_controller.skip_demo()

## 手動觸發 Ina 翻牌效果（當單位已消失時使用）
func _manual_ina_flip_card(flip_position: Vector2, flip_range: float):
	"""當 Ina 單位消失後，手動觸發翻牌特效和吸血邏輯"""
	print("[BattleController] Manual Ina flip card triggered at ", flip_position)

	# 1. 播放 VFX 10（癲狂吸血特效）
	InaVFX.spawn_madness_drain_vfx(flip_position, get_tree().root)

	# 2. 獲取附近敵人並執行吸血
	const PASSIVE_SKILL_HP_DRAIN_PERCENT: float = 0.20  # 吸收敵人20%血量
	var nearby_enemies = _get_nearby_enemies(flip_position, flip_range)
	print("[BattleController] Found ", nearby_enemies.size(), " nearby enemies for flip card")

	var total_absorbed: int = 0

	for enemy in nearby_enemies:
		if enemy and is_instance_valid(enemy) and enemy.current_hp > 0:
			# 吸收敵人20%血量
			var drain_amount = int(enemy.current_hp * PASSIVE_SKILL_HP_DRAIN_PERCENT)
			drain_amount = max(1, drain_amount)

			enemy.take_damage(drain_amount, false)
			total_absorbed += drain_amount

			# 顯示傷害浮字
			var damage_label = preload("res://scripts/DamageLabel.gd").new()
			damage_label.global_position = enemy.global_position
			get_tree().root.add_child(damage_label)
			damage_label.setup(drain_amount, false, false)

			print("  Drained ", drain_amount, " HP from ", enemy.unit_name)

	print("[BattleController] Manual flip card complete. Total HP absorbed: ", total_absorbed)
