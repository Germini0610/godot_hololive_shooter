extends Label
class_name DamageLabel

## 傷害浮字腳本

var lifetime: float = 1.5
var float_speed: float = 50.0
var fade_delay: float = 0.5

func _ready():
	# 設置預設樣式（放大字體）
	add_theme_font_size_override("font_size", 48)  # 從 24 放大到 48

	# 動畫
	_animate()

## 設置傷害文字
func setup(damage: int, is_weakness: bool = false, is_critical: bool = false):
	text = str(damage)

	# 根據類型設置顏色
	if is_critical:
		modulate = Color.ORANGE_RED
		add_theme_font_size_override("font_size", 64)  # 從 32 放大到 64
	elif is_weakness:
		modulate = Color.YELLOW
	else:
		modulate = Color.WHITE

## 動畫效果
func _animate():
	var tween = create_tween()
	tween.set_parallel(true)

	# 向上飄動
	var target_pos = global_position + Vector2(randf_range(-20, 20), -float_speed)
	tween.tween_property(self, "global_position", target_pos, lifetime)

	# 淡出
	tween.tween_property(self, "modulate:a", 0.0, lifetime - fade_delay).set_delay(fade_delay)

	# 縮放效果
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)

	# 結束後刪除
	tween.finished.connect(queue_free)
