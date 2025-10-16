extends Node2D

var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()

var line_width: float = 20.0
var color: Color = Color.WHITE

func _ready():
	print("[SmashRippleVisual] Ready! Initial radius: ", radius, " line_width: ", line_width)

func _draw():
	print("[SmashRippleVisual] _draw() called - radius: ", radius, " line_width: ", line_width)

	if radius > 0:
		# 单层圆环效果 - 简洁清晰
		# 外层粗环 (白色/金色，明亮清晰)
		var draw_color = Color(1.0, 1.0, 0.8, 1.0)
		print("[SmashRippleVisual] Drawing arc - radius: ", radius, " width: ", line_width, " color: ", draw_color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, draw_color, line_width, true)
	else:
		print("[SmashRippleVisual] Radius is 0 or negative, not drawing")
