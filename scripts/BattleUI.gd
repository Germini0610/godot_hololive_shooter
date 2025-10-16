extends CanvasLayer
class_name BattleUI

## UI 元件引用
@onready var skill_gauge_container = $TopBar/MarginContainer/HBoxContainer/SkillGaugeContainer
@onready var team_display = $BottomPanel/MarginContainer/TeamDisplay
@onready var turn_label = $TopBar/MarginContainer/HBoxContainer/TurnLabel

## 技能量表節點
var gauge_segments: Array[PanelContainer] = []

## 卡片詳細視窗引用
var card_detail_window: CardDetailWindow = null

## 玩家單位引用
var player_unit: Unit = null

func _ready():
	_setup_skill_gauge()
	_setup_team_display()
	_setup_card_detail_window()

	# 尋找玩家單位
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_unit = players[0]

## 設置技能量表
func _setup_skill_gauge():
	if not skill_gauge_container:
		print("[BattleUI] ERROR: skill_gauge_container not found!")
		return

	print("[BattleUI] Setting up skill gauge...")
	# 創建 5 個量表段（寬型長方形風格，使用 ProgressBar）
	for i in range(5):
		# 使用 PanelContainer 來獲得更好的樣式控制
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 40)  # 寬型長方形

		# 創建外框樣式（減少內邊距）
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.2, 0.2, 0.25, 1.0)
		style_box.border_width_left = 3
		style_box.border_width_top = 3
		style_box.border_width_right = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color(0.4, 0.4, 0.5, 1.0)
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		# 設置內邊距為 0，讓進度條填滿整個 Panel
		style_box.content_margin_left = 0
		style_box.content_margin_top = 0
		style_box.content_margin_right = 0
		style_box.content_margin_bottom = 0

		panel.add_theme_stylebox_override("panel", style_box)

		# 使用 ProgressBar 來顯示即時進度
		var progress_bar = ProgressBar.new()
		progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		progress_bar.min_value = 0.0
		progress_bar.max_value = 1.0
		progress_bar.value = 0.0
		progress_bar.show_percentage = false
		progress_bar.name = "GaugeProgress"

		# 創建進度條樣式（金色填充）
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(1.0, 0.84, 0.0, 1.0)  # 金色
		fill_style.corner_radius_top_left = 5
		fill_style.corner_radius_top_right = 5
		fill_style.corner_radius_bottom_left = 5
		fill_style.corner_radius_bottom_right = 5

		# 創建背景樣式（深灰色）
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
		bg_style.corner_radius_top_left = 5
		bg_style.corner_radius_top_right = 5
		bg_style.corner_radius_bottom_left = 5
		bg_style.corner_radius_bottom_right = 5

		progress_bar.add_theme_stylebox_override("fill", fill_style)
		progress_bar.add_theme_stylebox_override("background", bg_style)

		panel.add_child(progress_bar)
		skill_gauge_container.add_child(panel)
		gauge_segments.append(panel)
		print("[BattleUI] Created gauge segment ", i)

	print("[BattleUI] Skill gauge setup complete. Total segments: ", gauge_segments.size())

## 更新技能量表（支援即時進度顯示）
func update_skill_gauge_realtime(current_gauge: float, max: int):
	if gauge_segments.size() == 0:
		print("[BattleUI] ERROR: No gauge segments! Reinitializing...")
		_setup_skill_gauge()
		return

	# 計算每個格子的進度
	for i in range(gauge_segments.size()):
		var panel = gauge_segments[i]
		var progress_bar = panel.get_node_or_null("GaugeProgress")

		if not progress_bar:
			print("  ERROR: GaugeProgress not found in segment ", i)
			continue

		# 計算此格子應該顯示的進度
		var segment_progress = clamp(current_gauge - float(i), 0.0, 1.0)
		progress_bar.value = segment_progress

		# 更新外框顏色
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.2, 0.2, 0.25, 1.0)
		style_box.border_width_left = 3
		style_box.border_width_top = 3
		style_box.border_width_right = 3
		style_box.border_width_bottom = 3
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		# 設置內邊距為 0
		style_box.content_margin_left = 0
		style_box.content_margin_top = 0
		style_box.content_margin_right = 0
		style_box.content_margin_bottom = 0

		# 如果已經滿了或正在填充，使用金色邊框
		if segment_progress > 0.0:
			style_box.border_color = Color(1.0, 0.84, 0.0, 1.0)
		else:
			style_box.border_color = Color(0.4, 0.4, 0.5, 1.0)

		panel.add_theme_stylebox_override("panel", style_box)

## 更新技能量表（舊版本，保留向後兼容）
func update_skill_gauge(current: int, max: int):
	# 將整數版本轉換為浮點數版本
	update_skill_gauge_realtime(float(current), max)

## 設置隊伍顯示
func _setup_team_display():
	if not team_display:
		return

	# 顯示 5 個位置（怪物彈珠風格 - 簡潔橫向排列）
	var positions = ["Leader", "Front-1", "Front-2", "Standby", "Friend"]
	for i in range(5):
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)

		# 單位圖示
		if i == 0:
			# Leader 使用 user.png，並添加點擊功能
			var button = Button.new()
			button.custom_minimum_size = Vector2(100, 100)
			button.flat = true
			button.name = "LeaderButton"

			# 創建圖片作為按鈕背景
			var texture_rect = TextureRect.new()
			texture_rect.custom_minimum_size = Vector2(100, 100)
			var user_texture = load("res://material/user.png")
			texture_rect.texture = user_texture
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(texture_rect)

			button.pressed.connect(_on_leader_card_clicked)
			vbox.add_child(button)

			# 添加血條
			var hp_bar = ProgressBar.new()
			hp_bar.custom_minimum_size = Vector2(90, 12)
			hp_bar.max_value = 100.0
			hp_bar.value = 100.0
			hp_bar.show_percentage = false
			hp_bar.modulate = Color.GREEN
			hp_bar.name = "LeaderHPBar"
			vbox.add_child(hp_bar)

			# 血量文字
			var hp_label = Label.new()
			hp_label.text = "1000/1000"
			hp_label.add_theme_font_size_override("font_size", 24)  # 从 16 增大到 24
			hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hp_label.name = "LeaderHPLabel"
			vbox.add_child(hp_label)
		else:
			# 其他位置用灰色方塊
			var circle = ColorRect.new()
			circle.custom_minimum_size = Vector2(100, 100)
			circle.color = Color(0.5, 0.5, 0.5, 1.0)
			vbox.add_child(circle)

			# 空白佔位（保持對齊）
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(90, 28)
			vbox.add_child(spacer)

		# 單位名稱
		var label = Label.new()
		label.text = positions[i]
		label.add_theme_font_size_override("font_size", 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)

		team_display.add_child(vbox)

## 更新回合數
func update_turn(turn: int):
	if turn_label:
		turn_label.text = "Turn: " + str(turn)

## 顯示敵人行動倒數（移除，不再需要）
func update_enemy_action_count(enemy_name: String, count: int):
	pass  # 敵人資訊直接顯示在戰場上

## 顯示傷害浮字
func show_damage_text(damage: int, position: Vector2, is_weakness: bool = false):
	var label = Label.new()
	label.text = str(damage)
	label.global_position = position
	label.modulate = Color.YELLOW if is_weakness else Color.WHITE

	# 添加到場景
	add_child(label)

	# 動畫：向上飄並淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func(): label.queue_free())

## 顯示技能名稱
func show_skill_name(skill_name: String):
	var label = Label.new()
	label.text = skill_name
	label.position = Vector2(get_viewport().size.x / 2, 100)
	label.add_theme_font_size_override("font_size", 64)  # 從 32 放大到 64
	add_child(label)

	# 淡出
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.finished.connect(func(): label.queue_free())

## 更新 Leader 血條
func update_leader_hp(current_hp: int, max_hp: int):
	if not team_display:
		return

	if team_display.get_child_count() == 0:
		return

	var leader_vbox = team_display.get_child(0)
	if not leader_vbox:
		return

	# 更新血條
	var hp_bar = leader_vbox.get_node_or_null("LeaderHPBar")
	if hp_bar:
		var hp_percentage = (float(current_hp) / float(max_hp)) * 100.0
		hp_bar.value = hp_percentage

		# 根據血量改變顏色
		if hp_percentage > 60:
			hp_bar.modulate = Color.GREEN
		elif hp_percentage > 30:
			hp_bar.modulate = Color.YELLOW
		else:
			hp_bar.modulate = Color.RED

	# 更新血量文字
	var hp_label = leader_vbox.get_node_or_null("LeaderHPLabel")
	if hp_label:
		hp_label.text = str(current_hp) + "/" + str(max_hp)

## 設置卡片詳細視窗
func _setup_card_detail_window():
	var card_window_scene = preload("res://scenes/CardDetailWindow.tscn")
	if card_window_scene:
		card_detail_window = card_window_scene.instantiate()
		add_child(card_detail_window)

## 點擊 Leader 卡片回調
func _on_leader_card_clicked():
	if card_detail_window and player_unit:
		card_detail_window.show_card_details(player_unit)
