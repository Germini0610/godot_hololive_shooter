extends Node2D
class_name WeaknessIndicator

## 弱點指示器（顯示敵人背後的弱點區域）

var parent_unit: Unit = null

func _ready():
	parent_unit = get_parent() as Unit
	set_process(true)

func _process(_delta):
	queue_redraw()

func _draw():
	if not parent_unit:
		return

	# 獲取碰撞體半徑
	var unit_radius = 30.0
	var collision_shape = parent_unit.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		unit_radius = collision_shape.shape.radius

	# 計算弱點扇形參數
	var weakness_center_angle = deg_to_rad(parent_unit.weakness_center_angle)
	var half_arc = deg_to_rad(parent_unit.weakness_arc_angle / 2.0)
	var start_angle = weakness_center_angle - half_arc
	var end_angle = weakness_center_angle + half_arc

	# 擴大顯示半徑，讓弱點區域更明顯
	var display_radius = unit_radius + 15.0

	# 繪製扇形弱點區域
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)  # 扇形頂點在單位中心

	var steps = 32
	for i in range(steps + 1):
		var angle = lerp(start_angle, end_angle, float(i) / float(steps))
		points.append(Vector2(cos(angle), sin(angle)) * display_radius)

	# 繪製半透明紅色扇形
	draw_colored_polygon(points, Color(1.0, 0.2, 0.2, 0.35))

	# 繪製扇形邊框
	var border_points = PackedVector2Array()
	for i in range(steps + 1):
		var angle = lerp(start_angle, end_angle, float(i) / float(steps))
		border_points.append(Vector2(cos(angle), sin(angle)) * display_radius)
	draw_polyline(border_points, Color(1.0, 0.0, 0.0, 0.7), 3.0)

	# 繪製扇形的兩條邊線
	draw_line(Vector2.ZERO, Vector2(cos(start_angle), sin(start_angle)) * display_radius, Color(1.0, 0.0, 0.0, 0.7), 2.0)
	draw_line(Vector2.ZERO, Vector2(cos(end_angle), sin(end_angle)) * display_radius, Color(1.0, 0.0, 0.0, 0.7), 2.0)

	# 繪製中心指示線和準星
	var center_pos = Vector2(cos(weakness_center_angle), sin(weakness_center_angle)) * (display_radius * 0.6)
	draw_line(Vector2.ZERO, center_pos, Color(1.0, 0.0, 0.0, 0.5), 2.0)
	_draw_crosshair(center_pos, 8.0, Color(1.0, 0.0, 0.0, 0.9))

## 繪製準星
func _draw_crosshair(pos: Vector2, size: float, color: Color):
	# 繪製十字準星
	draw_line(pos - Vector2(size, 0), pos + Vector2(size, 0), color, 2.0)
	draw_line(pos - Vector2(0, size), pos + Vector2(0, size), color, 2.0)

	# 繪製圓圈
	draw_arc(pos, size * 0.7, 0, TAU, 16, color, 2.0)