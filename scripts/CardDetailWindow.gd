extends Control
class_name CardDetailWindow

## UI 元件引用
@onready var close_button = $Panel/CloseButton
@onready var unit_name_label = $Panel/HeaderPanel/UnitName
@onready var stats_label = $Panel/ScrollContainer/VBoxContainer/StatsPanel/MarginContainer/StatsContainer/StatsLabel
@onready var leader_skill_label = $Panel/ScrollContainer/VBoxContainer/LeaderSkillPanel/MarginContainer/LeaderSkillContainer/SkillLabel
@onready var command_skill_label = $Panel/ScrollContainer/VBoxContainer/CommandSkillPanel/MarginContainer/CommandSkillContainer/SkillLabel
@onready var passive_skill_label = $Panel/ScrollContainer/VBoxContainer/PassiveSkillPanel/MarginContainer/PassiveSkillContainer/SkillLabel
@onready var awaken_skill_label = $Panel/ScrollContainer/VBoxContainer/AwakenSkillPanel/MarginContainer/AwakenSkillContainer/SkillLabel

func _ready():
	hide()
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

## 顯示卡片詳細資料
func show_card_details(unit: Unit):
	if not unit:
		return

	# 設置單位名稱
	if unit_name_label:
		unit_name_label.text = unit.unit_name

	# 設置三圍數據
	if stats_label:
		stats_label.text = "攻擊：" + str(unit.atk) + "\n"
		stats_label.text += "移動：" + str(unit.move_stat) + "\n"
		stats_label.text += "翻牌範圍：" + str(unit.flip_range) + "\n"
		stats_label.text += "HP：" + str(unit.current_hp) + " / " + str(unit.max_hp)

	# 設置隊長技能
	if leader_skill_label:
		leader_skill_label.text = unit.leader_skill_name + "\n" + unit.leader_skill_description

	# 設置大招
	if command_skill_label:
		command_skill_label.text = unit.command_skill_name + "\n" + unit.command_skill_description

	# 設置被動技能
	if passive_skill_label:
		passive_skill_label.text = unit.passive_skill_name + "\n" + unit.passive_skill_description

	# 設置覺醒技能
	if awaken_skill_label:
		awaken_skill_label.text = unit.awaken_skill_name + "\n" + unit.awaken_skill_description

	show()

## 關閉按鈕回調
func _on_close_button_pressed():
	hide()

## 點擊視窗外部關閉
func _input(event):
	if visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 檢查點擊是否在面板外
			var panel = $Panel
			if panel:
				var panel_rect = panel.get_global_rect()
				if not panel_rect.has_point(event.position):
					hide()
