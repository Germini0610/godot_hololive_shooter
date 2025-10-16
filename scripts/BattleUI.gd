extends CanvasLayer
class_name BattleUI

## UI 元件引用
@onready var skill_gauge_container = $TopBar/MarginContainer/HBoxContainer/SkillGaugeContainer
@onready var team_display = $BottomPanel/MarginContainer/TeamDisplay
@onready var turn_label = $TopBar/MarginContainer/HBoxContainer/TurnLabel

## 技能量表節點
var gauge_segments: Array[ColorRect] = []

func _ready():
	_setup_skill_gauge()
	_setup_team_display()

## 設置技能量表
func _setup_skill_gauge():
	if not skill_gauge_container:
		return

	# 創建 5 個量表段（怪物彈珠風格）
	for i in range(5):
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(60, 60)
		color_rect.color = Color(0.3, 0.3, 0.3, 0.9)  # 深灰色

		skill_gauge_container.add_child(color_rect)
		gauge_segments.append(color_rect)

## 更新技能量表
func update_skill_gauge(current: int, max: int):
	for i in range(gauge_segments.size()):
		if i < current:
			gauge_segments[i].color = Color(0.0, 1.0, 1.0, 1.0)  # 青色（怪物彈珠風格）
		else:
			gauge_segments[i].color = Color(0.3, 0.3, 0.3, 0.9)  # 深灰色

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
			# Leader 使用 user.png
			var texture_rect = TextureRect.new()
			texture_rect.custom_minimum_size = Vector2(100, 100)
			var user_texture = load("res://material/user.png")
			texture_rect.texture = user_texture
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			vbox.add_child(texture_rect)

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
			hp_label.add_theme_font_size_override("font_size", 16)
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
