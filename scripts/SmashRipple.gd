extends Area2D
class_name SmashRipple

var base_damage: float = 0.0
var attacker_attribute: Attribute.Type

func setup(p_base_damage: float, p_attacker_attribute: Attribute.Type):
	base_damage = p_base_damage
	attacker_attribute = p_attacker_attribute
var smash_radius = 150.0
var duration = 0.4

var damaged_enemies = []

@onready var collision_shape = $CollisionShape2D
@onready var visual_node = $Visual

func _ready():
	print("[SmashRipple] Initialized.")
	body_entered.connect(_on_body_entered)
	
	# The shape's radius will be animated directly
	collision_shape.shape.radius = 0.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# Animate collision shape radius
	tween.tween_property(collision_shape.shape, "radius", smash_radius, duration)
	
	# Animate visual radius
	tween.tween_property(visual_node, "radius", smash_radius, duration)
	
	# Animate visual fade out
	visual_node.modulate = Color(1.0, 0.8, 0.0, 0.8)
	tween.tween_property(visual_node, "modulate:a", 0.0, duration)

	# Animate visual line width shrinking
	tween.tween_property(visual_node, "line_width", 0.0, duration)

	tween.finished.connect(queue_free)

func _on_body_entered(body):
	if body.is_in_group("enemy") and not damaged_enemies.has(body):
		if body.has_method("take_damage"):
			damaged_enemies.append(body)
			
			var attr_multiplier = Attribute.get_multiplier(attacker_attribute, body.attribute)
			var final_damage = int(base_damage * attr_multiplier)
			body.take_damage(final_damage, false)
			
			# Find the unit to spawn the damage label
			var main_node = get_tree().root.get_node("Battlefield/BattleController")
			if main_node and main_node.current_active_unit:
				main_node.current_active_unit._spawn_damage_label(body.global_position, final_damage, false)

			print("Smash ripple hit ", body.unit_name, " for ", final_damage, " damage")
