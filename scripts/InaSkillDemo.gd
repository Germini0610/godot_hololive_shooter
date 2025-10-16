extends Node
class_name InaSkillDemo

## Ina 技能演示控制器
## 用於測試和展示 Ina 的技能動畫序列

signal demo_started()
signal leader_skill_demo_finished()
signal passive_skill_demo_finished()
signal all_demos_finished()

enum DemoState {
	IDLE,
	LEADER_SKILL_DEMO,
	PASSIVE_SKILL_DEMO,
	PLAYER_CONTROL
}

var current_state: DemoState = DemoState.IDLE
var ina_unit: InaUnit = null
var demo_enemies: Array = []
var battle_controller = null

## 演示配置
const DEMO_DELAY_BEFORE_START: float = 1.0  # 進入戰鬥後延遲
const DEMO_DELAY_BETWEEN_SKILLS: float = 2.0  # 技能之間延遲
const LEADER_SKILL_DEMO_DURATION: float = 3.0  # 隊長技能演示時長
const PASSIVE_SKILL_DEMO_DURATION: float = 3.0  # 被動技能演示時長

func _ready():
	print("[InaSkillDemo] Demo controller ready")

## 開始技能演示序列
func start_demo_sequence(ina: InaUnit, enemies: Array, controller):
	if current_state != DemoState.IDLE:
		print("[InaSkillDemo] Demo already running!")
		return

	ina_unit = ina
	demo_enemies = enemies
	battle_controller = controller

	print("[InaSkillDemo] Starting demo sequence...")
	demo_started.emit()

	# 延遲後開始第一個演示
	await get_tree().create_timer(DEMO_DELAY_BEFORE_START).timeout
	_start_leader_skill_demo()

## 演示隊長技能
func _start_leader_skill_demo():
	print("[InaSkillDemo] === Leader Skill Demo ===")
	current_state = DemoState.LEADER_SKILL_DEMO

	if not ina_unit:
		print("[InaSkillDemo] ERROR: Ina unit not found!")
		_finish_all_demos()
		return

	# 獲取所有隊員（模擬）
	var team_members = [ina_unit]  # 測試時只有 Ina

	# 1. 應用隊長技能 Buff（只在開場應用一次）
	print("[InaSkillDemo] Applying leader skill buffs (only once at start)")
	ina_unit.apply_leader_skill(team_members)

	# 2. 演示效果（播放 VFX 2）
	await get_tree().create_timer(1.0).timeout
	print("[InaSkillDemo] Demonstrating leader skill VFX (VFX 2)...")
	ina_unit.leader_skill_turn_penalty(team_members)

	# 3. 等待演示完成
	await get_tree().create_timer(LEADER_SKILL_DEMO_DURATION).timeout

	print("[InaSkillDemo] Leader Skill Demo finished")
	print("[InaSkillDemo] Note: Leader skill buffs remain active, no repeated application")
	leader_skill_demo_finished.emit()

	# 延遲後開始下一個演示
	await get_tree().create_timer(DEMO_DELAY_BETWEEN_SKILLS).timeout
	_start_passive_skill_demo()

## 演示被動技能（癲狂）
func _start_passive_skill_demo():
	print("[InaSkillDemo] === Passive Skill Demo ===")
	current_state = DemoState.PASSIVE_SKILL_DEMO

	if not ina_unit:
		print("[InaSkillDemo] ERROR: Ina unit not found!")
		_finish_all_demos()
		return

	# 1. 說明癲狂被動效果
	print("[InaSkillDemo] Madness passive is always active:")
	print("[InaSkillDemo]   - Direction reversed when launching")
	print("[InaSkillDemo]   - ATK x10 (", ina_unit.atk, " -> ", ina_unit.atk * 10, ")")
	print("[InaSkillDemo]   - Flip card (Smash) drains enemy HP")

	await get_tree().create_timer(1.5).timeout

	# 2. 演示翻牌吸血效果（播放 VFX 10）
	print("[InaSkillDemo] *** Demonstrating Flip Card VFX (VFX 10) ***")
	print("[InaSkillDemo] Ina position: ", ina_unit.global_position)
	print("[InaSkillDemo] VFX will display on Ina herself")

	# 強制播放特效用於演示
	var flip_pos = ina_unit.global_position
	ina_unit.on_flip_card(flip_pos, true)  # force_vfx = true

	print("[InaSkillDemo] VFX 10 displayed at Ina's position")
	print("[InaSkillDemo] Note: Madness passive remains active during gameplay")

	# 等待動畫播放
	await get_tree().create_timer(2.0).timeout

	# 3. 等待演示完成
	await get_tree().create_timer(PASSIVE_SKILL_DEMO_DURATION).timeout

	_finish_passive_demo()

func _finish_passive_demo():
	print("[InaSkillDemo] Passive Skill Demo finished")
	passive_skill_demo_finished.emit()

	# 延遲後進入玩家控制
	await get_tree().create_timer(1.0).timeout
	_finish_all_demos()

## 完成所有演示，進入玩家控制
func _finish_all_demos():
	print("[InaSkillDemo] === All Demos Finished ===")
	print("[InaSkillDemo] Entering player control mode...")

	current_state = DemoState.PLAYER_CONTROL
	all_demos_finished.emit()

	# 啟用玩家控制
	if battle_controller and battle_controller.has_method("enable_player_control"):
		battle_controller.enable_player_control()
	else:
		print("[InaSkillDemo] Battle controller ready for player input")

## 跳過演示
func skip_demo():
	print("[InaSkillDemo] Skipping demo...")
	_finish_all_demos()

## 獲取當前狀態
func get_demo_state() -> DemoState:
	return current_state

func is_demo_active() -> bool:
	return current_state != DemoState.IDLE and current_state != DemoState.PLAYER_CONTROL
