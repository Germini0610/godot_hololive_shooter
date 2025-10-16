extends Node2D
class_name CircleSprite

## 圓形精靈（用於視覺顯示）

@export var radius: float = 30.0
@export var color: Color = Color.RED
@export var segments: int = 32  # 圓形精細度

func _ready():
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, radius, color)

## 更新顏色
func set_color(new_color: Color):
	color = new_color
	queue_redraw()

## 更新半徑
func set_radius(new_radius: float):
	radius = new_radius
	queue_redraw()
