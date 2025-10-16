extends Area2D
class_name AreaTrap

## 陷阱屬性
@export var trap_name: String = "Area Trap"
@export var damage: int = 50
@export var owner_attribute: Attribute.Type = Attribute.Type.RED
@export var duration: float = 10.0  # -1 為永久
@export var tick_interval: float = 1.0  # 每秒觸發一次

## 效果類型
enum EffectType {
	DAMAGE,      # 持續傷害
	SLOW,        # 減速
	STUN,        # 定身
	BUFF         # 增益
}

@export var effect_type: EffectType = EffectType.DAMAGE
@export var effect_value: float = 1.0

## 運行時屬性
var lifetime: float = 0.0
var units_in_trap: Array = []
var tick_timer: float = 0.0

## 視覺效果
var visual: ColorRect

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 設置碰撞層
	collision_layer = 4  # Trap layer
	collision_mask = 3   # Player + Enemy

	# 創建視覺效果
	_create_visual()

	print("[AreaTrap] ", trap_name, " created")

func _process(delta):
	# 更新生命週期
	if duration > 0:
		lifetime += delta
		if lifetime >= duration:
			queue_free()
			return

	# 定期效果
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_apply_effects()

## 創建視覺效果
func _create_visual():
	visual = ColorRect.new()
	visual.size = Vector2(100, 100)
	visual.position = -visual.size / 2
	visual.color = Color(1.0, 0.0, 0.0, 0.3)  # 半透明紅色
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

## 單位進入陷阱
func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("enemy"):
		if not body in units_in_trap:
			units_in_trap.append(body)
			var unit_name = body.unit_name if "unit_name" in body else "Unit"
			print("[AreaTrap] ", unit_name, " entered trap")

## 單位離開陷阱
func _on_body_exited(body):
	if body in units_in_trap:
		units_in_trap.erase(body)
		var unit_name = body.unit_name if "unit_name" in body else "Unit"
		print("[AreaTrap] ", unit_name, " exited trap")

## 應用效果
func _apply_effects():
	for unit in units_in_trap:
		if not is_instance_valid(unit):
			units_in_trap.erase(unit)
			continue

		match effect_type:
			EffectType.DAMAGE:
				_apply_damage(unit)
			EffectType.SLOW:
				_apply_slow(unit)
			EffectType.STUN:
				_apply_stun(unit)
			EffectType.BUFF:
				_apply_buff(unit)

## 造成傷害
func _apply_damage(unit):
	if unit.has_method("take_damage"):
		var attr_multiplier = Attribute.get_multiplier(owner_attribute, unit.attribute)
		var final_damage = int(damage * attr_multiplier)
		unit.take_damage(final_damage, false)
		var unit_name = unit.unit_name if "unit_name" in unit else "Unit"
		print("[AreaTrap] Dealt ", final_damage, " damage to ", unit_name)

## 減速
func _apply_slow(unit):
	if "linear_velocity" in unit:
		unit.linear_velocity *= 0.5

## 定身
func _apply_stun(unit):
	if unit.has_method("stop_movement"):
		unit.stop_movement()

## 增益
func _apply_buff(unit):
	if unit.has_method("add_buff"):
		unit.add_buff("atk", effect_value, tick_interval)
