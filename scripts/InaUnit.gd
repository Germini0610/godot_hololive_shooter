extends Unit
class_name InaUnit

## Ninomae Ina'nis - 暗屬性角色
## 古神的祭司，擁有強大但伴隨代價的技能

## 狀態追蹤
var sacrifice_turns_remaining: int = 0  # 獻祭狀態剩餘回合
var is_awakened: bool = false  # 是否已覺醒
var madness_active: bool = true  # 癲狂被動是否啟用（預設啟用）

## 技能設定
const LEADER_SKILL_STATS_MULTIPLIER: float = 3.0  # 隊長技：三圍增加3倍
const LEADER_SKILL_HP_DRAIN_PERCENT: float = 0.10  # 隊長技：每回合損失10%血量

const COMMAND_SKILL_SACRIFICE_TURNS: int = 3  # 大招：獻祭持續3回合
const COMMAND_SKILL_SACRIFICE_HP_DRAIN: float = 0.15  # 大招：每回合損失15%血量
const COMMAND_SKILL_DAMAGE_PERCENT: float = 40.0  # 大招：造成4000%傷害

const PASSIVE_SKILL_ATK_MULTIPLIER: float = 10.0  # 被動：攻擊力增加1000%
const PASSIVE_SKILL_HP_DRAIN_PERCENT: float = 0.20  # 被動：吸收敵人20%血量

const AWAKEN_SKILL_STATS_MULTIPLIER: float = 2.0  # 覺醒：三圍變為2倍
const AWAKEN_SKILL_SELF_HEAL_PERCENT: float = 0.15  # 覺醒：每回合恢復自身15%血量
const AWAKEN_SKILL_TEAM_HEAL_PERCENT: float = 0.05  # 覺醒：每回合恢復隊友5%血量

## 觸手綁定系統
var tentacle_traps: Array = []  # 儲存生成的觸手陷阱

func _ready():
	super._ready()

	# 設置 Ina 的基礎屬性
	unit_name = "Ninomae Ina'nis"
	attribute = Attribute.Type.BLACK

	# 技能設定
	command_skill_name = "深淵之握"
	command_skill_description = "進入獻祭狀態3回合，每回合損失15%血量。敵人移動時，觸手綁定並造成4000%傷害"
	command_skill_cost = 5  # 消耗滿技能量表

	leader_skill_name = "古神的咒福"
	leader_skill_description = "所有隊員三圍增加3倍，每回合損失現有血量10%"

	passive_skill_name = "癲狂"
	passive_skill_description = "射出方向反向，攻擊力增加1000%！翻牌時吸收附近敵人20%血量"

	awaken_skill_name = "古神降臨"
	awaken_skill_description = "自身三圍變為2倍，每回合恢復自身15%血量，隊友恢復5%"

	print("[Ina] Initialized with madness passive active")

## ========== 隊長技能：古神的咒福 ==========
func apply_leader_skill(team_members: Array):
	"""應用隊長技能：所有隊員三圍增加3倍"""
	print("[Ina Leader Skill] 古神的咒福 activated!")

	for member in team_members:
		if member and is_instance_valid(member):
			# 增加三圍（ATK, HP, 移動）
			member.add_buff("atk", LEADER_SKILL_STATS_MULTIPLIER, -1.0)
			member.add_buff("hp", LEADER_SKILL_STATS_MULTIPLIER, -1.0)
			member.add_buff("move", LEADER_SKILL_STATS_MULTIPLIER, -1.0)

			print("  [", member.unit_name, "] Stats x", LEADER_SKILL_STATS_MULTIPLIER)

func leader_skill_turn_penalty(team_members: Array):
	"""隊長技能副作用：每回合損失10%血量"""
	print("[Ina Leader Skill] Turn penalty: All members lose 10% HP")

	for member in team_members:
		if member and is_instance_valid(member) and member.current_hp > 0:
			var damage = int(member.current_hp * LEADER_SKILL_HP_DRAIN_PERCENT)
			damage = max(1, damage)  # 至少扣1血
			member.take_damage(damage, false)

			# 播放 Dark VFX 2（隊長技能效果）
			_spawn_leader_skill_vfx(member.global_position)

			_spawn_damage_label(member.global_position, damage, false)
			print("  [", member.unit_name, "] Lost ", damage, " HP (10% of current)")

## ========== 大招：深淵之握 ==========
func _execute_command_skill():
	"""發動大招：進入獻祭狀態"""
	print("[Ina Command Skill] 深淵之握 - Entering Sacrifice State!")

	# 進入獻祭狀態
	sacrifice_turns_remaining = COMMAND_SKILL_SACRIFICE_TURNS

	# 生成觸手陷阱（監控敵人移動）
	_activate_tentacle_binding_system()

	# 視覺效果（TODO: 添加特效）
	print("  Sacrifice duration: ", sacrifice_turns_remaining, " turns")

func _activate_tentacle_binding_system():
	"""啟動觸手綁定系統"""
	# 獲取所有敵人並監控
	var enemies = get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			# 為每個敵人連接移動監控信號
			if not enemy.is_connected("body_entered", _on_enemy_moved_during_sacrifice):
				# 使用物理監控來檢測敵人移動
				pass  # 透過 BattleController 的回合系統檢測

	print("  [Tentacle Binding] System activated - monitoring enemy movements")

func _on_enemy_moved_during_sacrifice(enemy):
	"""當敵人在獻祭狀態中移動時觸發"""
	if sacrifice_turns_remaining <= 0:
		return

	if not enemy or not is_instance_valid(enemy):
		return

	print("[Ina Sacrifice] Tentacle binding triggered on ", enemy.unit_name)

	# 1. 強制停止敵人移動
	if enemy.has_method("stop_movement"):
		enemy.stop_movement()

	# 2. 造成4000%傷害
	var damage = int(atk * COMMAND_SKILL_DAMAGE_PERCENT)
	enemy.take_damage(damage, false)

	# 3. 生成觸手特效（TODO: 添加 Dark VFX）
	_spawn_tentacle_effect(enemy.global_position)

	# 4. 顯示傷害浮字
	_spawn_damage_label(enemy.global_position, damage, false)

	print("  Dealt ", damage, " damage (", COMMAND_SKILL_DAMAGE_PERCENT * 100, "% ATK)")

func sacrifice_turn_penalty():
	"""獻祭狀態每回合懲罰：損失15%血量（但現在不播放自身特效）"""
	if sacrifice_turns_remaining <= 0:
		return

	var damage = int(current_hp * COMMAND_SKILL_SACRIFICE_HP_DRAIN)
	damage = max(1, damage)

	take_damage(damage, false)

	# 注意：深淵之握的特效（VFX 4）現在在敵人移動時播放在敵人身上
	# 自身損血不需要播放特效

	_spawn_damage_label(global_position, damage, false)

	sacrifice_turns_remaining -= 1

	print("[Ina Sacrifice] Turn penalty: Lost ", damage, " HP (15%). Remaining turns: ", sacrifice_turns_remaining)

	if sacrifice_turns_remaining <= 0:
		print("[Ina Sacrifice] Sacrifice state ended")

func _spawn_tentacle_effect(position: Vector2):
	"""生成觸手綁定特效（深淵之握：VFX 4）"""
	print("  [VFX] Spawning tentacle effect (VFX 4) at enemy position: ", position)
	_spawn_sacrifice_enemy_vfx(position)

## ========== 被動技能：癲狂 ==========
func launch(direction: Vector2, power: float):
	"""覆寫發射：方向反轉 + 攻擊力增加"""
	if madness_active:
		# 反轉方向
		direction = -direction
		print("[Ina Passive] 癲狂 - Direction reversed!")

	# 調用父類的發射
	super.launch(direction, power)

func _calculate_buff_multiplier() -> float:
	"""覆寫 Buff 計算：加入癲狂的1000%攻擊力"""
	var base_multiplier = super._calculate_buff_multiplier()

	if madness_active:
		base_multiplier *= PASSIVE_SKILL_ATK_MULTIPLIER
		# print("[Ina Passive] Madness ATK boost: x", PASSIVE_SKILL_ATK_MULTIPLIER)

	return base_multiplier

func on_flip_card(flip_position: Vector2, force_vfx: bool = false):
	"""翻牌時觸發：吸收附近敵人血量"""
	print("[Ina Passive] on_flip_card() called at position: ", flip_position)
	print("[Ina Passive] Madness active: ", madness_active)
	print("[Ina Passive] Flip range: ", flip_range)

	if not madness_active:
		print("[Ina Passive] Madness not active, skipping flip card effect")
		return

	print("[Ina Passive] 翻牌 - Absorbing nearby enemy HP")

	# 翻牌時只在演示模式播放 VFX 10（用於展示被動技能）
	if force_vfx:
		print("[Ina Passive] Demo mode - Spawning VFX 10 at Ina position")
		_spawn_madness_drain_vfx(global_position)

	# 獲取附近敵人（使用翻牌範圍）
	var nearby_enemies = _get_nearby_enemies(flip_range)
	print("[Ina Passive] Found ", nearby_enemies.size(), " nearby enemies within range ", flip_range)

	var total_absorbed: int = 0

	for enemy in nearby_enemies:
		if enemy and is_instance_valid(enemy) and enemy.current_hp > 0:
			print("[Ina Passive] Processing enemy: ", enemy.unit_name, " at ", enemy.global_position)

			# 吸收敵人20%血量
			var drain_amount = int(enemy.current_hp * PASSIVE_SKILL_HP_DRAIN_PERCENT)
			drain_amount = max(1, drain_amount)

			enemy.take_damage(drain_amount, false)
			total_absorbed += drain_amount

			# 在敵人身上顯示傷害浮字
			_spawn_damage_label(enemy.global_position, drain_amount, false)
			print("  Drained ", drain_amount, " HP from ", enemy.unit_name)

	# 恢復自身血量
	if total_absorbed > 0:
		current_hp = min(current_hp + total_absorbed, max_hp)
		hp_changed.emit(current_hp, max_hp)

		# 顯示治療浮字
		var heal_label = preload("res://scripts/DamageLabel.gd").new()
		heal_label.global_position = global_position
		get_tree().root.add_child(heal_label)
		heal_label.setup(total_absorbed, false, true)  # true = healing

		print("  [Ina] Healed ", total_absorbed, " HP (", current_hp, "/", max_hp, ")")

## ========== 覺醒技能：古神降臨 ==========
func activate_awaken_skill():
	"""發動覺醒技能"""
	if is_awakened:
		print("[Ina Awaken] Already awakened!")
		return

	is_awakened = true
	print("[Ina Awaken Skill] 古神降臨 activated!")

	# 自身三圍變為2倍
	add_buff("atk", AWAKEN_SKILL_STATS_MULTIPLIER, -1.0)
	add_buff("hp", AWAKEN_SKILL_STATS_MULTIPLIER, -1.0)
	add_buff("move", AWAKEN_SKILL_STATS_MULTIPLIER, -1.0)

	print("  [Ina] Stats multiplied by ", AWAKEN_SKILL_STATS_MULTIPLIER)

	# TODO: 添加覺醒特效

func awaken_turn_healing(team_members: Array):
	"""覺醒狀態每回合治療"""
	if not is_awakened:
		return

	print("[Ina Awaken] Turn healing")

	# 恢復自身15%血量
	var self_heal = int(max_hp * AWAKEN_SKILL_SELF_HEAL_PERCENT)
	current_hp = min(current_hp + self_heal, max_hp)
	hp_changed.emit(current_hp, max_hp)

	var heal_label = preload("res://scripts/DamageLabel.gd").new()
	heal_label.global_position = global_position
	get_tree().root.add_child(heal_label)
	heal_label.setup(self_heal, false, true)

	print("  [Ina] Self heal: +", self_heal, " HP")

	# 恢復隊友5%血量
	for member in team_members:
		if member and is_instance_valid(member) and member != self and member.current_hp > 0:
			var team_heal = int(member.max_hp * AWAKEN_SKILL_TEAM_HEAL_PERCENT)
			member.current_hp = min(member.current_hp + team_heal, member.max_hp)
			member.hp_changed.emit(member.current_hp, member.max_hp)

			var team_heal_label = preload("res://scripts/DamageLabel.gd").new()
			team_heal_label.global_position = member.global_position
			get_tree().root.add_child(team_heal_label)
			team_heal_label.setup(team_heal, false, true)

			print("  [", member.unit_name, "] Team heal: +", team_heal, " HP")

## ========== 回合結束處理 ==========
func on_turn_end(team_members: Array):
	"""每回合結束時調用"""
	# 處理獻祭狀態懲罰
	if sacrifice_turns_remaining > 0:
		sacrifice_turn_penalty()

	# 處理覺醒狀態治療
	if is_awakened:
		awaken_turn_healing(team_members)

	# 處理隊長技能懲罰（如果是隊長）
	var battle_ui = get_tree().get_nodes_in_group("battle_ui")
	if battle_ui.size() > 0:
		var team = battle_ui[0].get("player_team")
		if team and team.get_leader() == self:
			leader_skill_turn_penalty(team.get_alive_members())

## ========== VFX 特效播放 ==========
func _spawn_leader_skill_vfx(position: Vector2):
	"""播放隊長技能特效（Dark VFX 2）在隊伍身上"""
	InaVFX.spawn_leader_skill_vfx(position, get_tree().root)

func _spawn_sacrifice_enemy_vfx(position: Vector2):
	"""播放深淵之握特效（Dark VFX 4）在敵人身上"""
	InaVFX.spawn_sacrifice_enemy_vfx(position, get_tree().root)

func _spawn_madness_drain_vfx(position: Vector2):
	"""播放癲狂被動吸血特效（Dark VFX 10）在自身"""
	InaVFX.spawn_madness_drain_vfx(position, get_tree().root)

## ========== 調試工具 ==========
func toggle_madness():
	"""切換癲狂被動"""
	madness_active = !madness_active
	print("[Ina] Madness toggled: ", madness_active)

func force_awaken():
	"""強制覺醒（測試用）"""
	activate_awaken_skill()

func get_status_info() -> String:
	"""獲取當前狀態資訊"""
	var info = "[Ina Status]\n"
	info += "  HP: %d/%d\n" % [current_hp, max_hp]
	info += "  Madness: %s\n" % ["Active" if madness_active else "Inactive"]
	info += "  Sacrifice Turns: %d\n" % sacrifice_turns_remaining
	info += "  Awakened: %s\n" % ["Yes" if is_awakened else "No"]
	return info
