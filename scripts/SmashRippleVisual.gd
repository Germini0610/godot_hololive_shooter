extends Node2D

var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()

var line_width: float = 20.0

func _draw():
	if radius > 0:
		# Draw a filled circle first for visibility
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 0.0, 0.2))
		# Draw an expanding ring using an anti-aliased arc
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color.WHITE, line_width, true)
