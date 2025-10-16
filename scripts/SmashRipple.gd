extends Area2D
class_name SmashRipple

var base_damage: float = 0.0
var attacker_attribute: Attribute.Type

var smash_radius = 200.0  # 增加范围，与 flip_range 一致
var duration = 1.0  # 延长到1秒，让波纹更明显
var damaged_enemies = []
var collision_shape: CollisionShape2D
var visual_node: Node2D
var is_cleanup_scheduled: bool = false  # 防止重复删除

func setup(p_base_damage: float, p_attacker_attribute: Attribute.Type):
	base_damage = p_base_damage
	attacker_attribute = p_attacker_attribute

func _ready():
	print("[SmashRipple] ========== _ready() called ==========")

	# Get child nodes
	if not has_node("CollisionShape2D"):
		print("[SmashRipple] ERROR: CollisionShape2D not found in scene!")
		return

	if not has_node("Visual"):
		print("[SmashRipple] ERROR: Visual node not found in scene!")
		return

	collision_shape = get_node("CollisionShape2D")
	visual_node = get_node("Visual")

	print("[SmashRipple] ========== Initializing ==========")
	print("[SmashRipple] Position: ", global_position)
	print("[SmashRipple] Z-index: ", z_index)
	print("[SmashRipple] Radius: ", smash_radius)
	print("[SmashRipple] Duration: ", duration)
	print("[SmashRipple] Collision shape: ", collision_shape)
	print("[SmashRipple] Visual node: ", visual_node)

	body_entered.connect(_on_body_entered)

	# Check if visual node exists
	if not visual_node:
		print("[SmashRipple] ERROR: Visual node is null!")
		return

	print("[SmashRipple] Visual node found: ", visual_node.name)

	# The shape's radius will be animated directly
	collision_shape.shape.radius = 0.0

	# Set initial visual properties
	visual_node.modulate = Color(1.0, 1.0, 1.0, 1.0)  # 从完全不透明开始
	visual_node.line_width = 40.0  # 更粗的初始线条
	visual_node.z_index = 100  # 确保在最上层

	print("[SmashRipple] Starting animation...")
	print("[SmashRipple] Initial line_width: ", visual_node.line_width)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Animate collision shape radius
	tween.tween_property(collision_shape.shape, "radius", smash_radius, duration)

	# Animate visual radius (扩散效果)
	tween.tween_property(visual_node, "radius", smash_radius, duration)

	# Animate visual fade out (淡出更慢，在后半段才开始明显淡化)
	tween.tween_property(visual_node, "modulate:a", 0.0, duration * 0.8).set_delay(duration * 0.2)

	# Animate visual line width shrinking (线条宽度保持更久)
	tween.tween_property(visual_node, "line_width", 5.0, duration * 0.7)  # 只缩小到5，不要完全消失

	# 使用 CONNECT_ONE_SHOT 确保信号只触发一次
	tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)

	print("[SmashRipple] Animation started successfully")

func _on_tween_finished():
	# 防止重复删除
	if is_cleanup_scheduled:
		print("[SmashRipple] Cleanup already scheduled, skipping")
		return

	if not is_inside_tree():
		print("[SmashRipple] Not in tree, skipping cleanup")
		return

	is_cleanup_scheduled = true
	print("[SmashRipple] Animation finished, scheduling cleanup...")

	# 使用 call_deferred 延迟删除，避免在信号处理中删除
	call_deferred("_safe_cleanup")

func _safe_cleanup():
	# 二次检查，确保安全
	if not is_inside_tree():
		print("[SmashRipple] Already removed from tree in _safe_cleanup")
		return

	print("[SmashRipple] Executing queue_free...")
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemy") and not damaged_enemies.has(body):
		if body.has_method("take_damage"):
			damaged_enemies.append(body)

			# 先保存敌人位置，因为敌人可能会被击杀并删除
			var enemy_position = body.global_position

			var attr_multiplier = Attribute.get_multiplier(attacker_attribute, body.attribute)
			var final_damage = int(base_damage * attr_multiplier)
			body.take_damage(final_damage, false)

			# 使用保存的位置来生成伤害标签和 VFX
			var main_node = get_tree().root.get_node("Battlefield/BattleController")
			if main_node and main_node.current_active_unit:
				main_node.current_active_unit._spawn_damage_label(enemy_position, final_damage, false)

			# Spawn VFX at enemy position (使用保存的位置)
			# 获取 Battlefield 节点，如果不存在则使用根节点
			var battlefield_node = get_tree().root.get_node_or_null("Battlefield")
			if battlefield_node:
				InaVFX.spawn_smash_hit_vfx(enemy_position, battlefield_node)
			else:
				print("[SmashRipple] WARNING: Battlefield node not found, VFX not spawned")

			print("Smash ripple hit ", body.unit_name, " for ", final_damage, " damage")
