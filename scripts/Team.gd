extends Node
class_name Team

## 隊伍信號
signal team_changed()
signal leader_skill_activated(skill_name: String)
signal link_skill_activated(skill_name: String)

## 隊伍位置枚舉
enum Position {
	LEADER,
	FRONTLINE_1,
	FRONTLINE_2,
	STANDBY,
	FRIEND
}

## 隊伍成員
var members: Dictionary = {
	Position.LEADER: null,
	Position.FRONTLINE_1: null,
	Position.FRONTLINE_2: null,
	Position.STANDBY: null,
	Position.FRIEND: null
}

## Leader Skill 定義
class LeaderSkill:
	var name: String
	var description: String
	var target_attributes: Array[Attribute.Type] = []  # 空陣列代表全體
	var buff_type: String = "atk"  # "atk", "hp", "skill_gauge"
	var buff_value: float = 1.2

	func _init(skill_name: String = "Leader Skill", buff_t: String = "atk", buff_v: float = 1.2):
		name = skill_name
		buff_type = buff_t
		buff_value = buff_v

## Link Skill 定義
class LinkSkill:
	var name: String
	var description: String
	var required_attributes: Array[Attribute.Type] = []  # 需要特定屬性組合
	var effect_type: String = "damage"  # "damage", "heal", "buff"
	var effect_value: float = 1.5

	func _init(skill_name: String = "Link Skill", eff_t: String = "damage", eff_v: float = 1.5):
		name = skill_name
		effect_type = eff_t
		effect_value = eff_v

## 當前技能
var leader_skill: LeaderSkill = null
var link_skill: LinkSkill = null

func _ready():
	pass

## 設置成員
func set_member(position: Position, unit: Unit):
	members[position] = unit
	team_changed.emit()

	# 如果是 Leader，應用 Leader Skill
	if position == Position.LEADER and unit:
		_apply_leader_skill()

	# 檢查是否觸發 Link Skill
	_check_link_skill()

## 取得成員
func get_member(position: Position) -> Unit:
	return members.get(position, null)

## 取得 Leader
func get_leader() -> Unit:
	return members.get(Position.LEADER, null)

## 取得所有活著的成員
func get_alive_members() -> Array[Unit]:
	var alive: Array[Unit] = []
	for pos in members:
		var unit = members[pos]
		if unit and unit.current_hp > 0:
			alive.append(unit)
	return alive

## 取得前線成員（Leader + Frontline1 + Frontline2）
func get_frontline_members() -> Array[Unit]:
	var frontline: Array[Unit] = []
	for pos in [Position.LEADER, Position.FRONTLINE_1, Position.FRONTLINE_2]:
		var unit = members[pos]
		if unit and unit.current_hp > 0:
			frontline.append(unit)
	return frontline

## 應用 Leader Skill
func _apply_leader_skill():
	var leader = get_leader()
	if not leader:
		return

	# 建立預設 Leader Skill（根據 Leader 屬性）
	leader_skill = LeaderSkill.new("Leader Buff", "atk", 1.3)

	print("[Team] Leader Skill activated: ", leader_skill.name)
	leader_skill_activated.emit(leader_skill.name)

	# 對符合條件的成員應用 Buff
	for pos in members:
		var unit = members[pos]
		if unit:
			# 檢查是否符合目標屬性
			if leader_skill.target_attributes.is_empty() or unit.attribute in leader_skill.target_attributes:
				unit.add_buff(leader_skill.buff_type, leader_skill.buff_value, -1.0)  # 永久 Buff

## 檢查並觸發 Link Skill
func _check_link_skill():
	var frontline = get_frontline_members()
	if frontline.size() < 2:
		return

	# 簡單範例：若前線有兩個相同屬性，觸發 Link Skill
	var attributes = []
	for unit in frontline:
		attributes.append(unit.attribute)

	# 檢查是否有重複屬性
	var has_link = false
	for i in range(attributes.size()):
		for j in range(i + 1, attributes.size()):
			if attributes[i] == attributes[j]:
				has_link = true
				break
		if has_link:
			break

	if has_link:
		link_skill = LinkSkill.new("Attribute Link", "damage", 1.5)
		print("[Team] Link Skill activated: ", link_skill.name)
		link_skill_activated.emit(link_skill.name)

## 設置自訂 Leader Skill
func set_custom_leader_skill(skill: LeaderSkill):
	leader_skill = skill
	_apply_leader_skill()

## 設置自訂 Link Skill
func set_custom_link_skill(skill: LinkSkill):
	link_skill = skill

## 取得隊伍總攻擊力（含 Buff）
func get_total_atk() -> int:
	var total = 0
	for unit in get_alive_members():
		total += unit.atk * unit._calculate_buff_multiplier()
	return int(total)

## 清除所有成員
func clear_team():
	for pos in members:
		members[pos] = null
	team_changed.emit()
