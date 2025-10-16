extends Control

## 啟動畫面控制器

@onready var start_button: TextureButton = $ButtonContainer/StartButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_transitioning: bool = false

func _ready():
	# 連接點擊信號
	if start_button:
		start_button.pressed.connect(_on_start_pressed)

	# 播放進入動畫
	if animation_player:
		animation_player.play("fade_in")

	print("[TitleScreen] Ready - Click Start to begin!")

## 點擊開始按鈕
func _on_start_pressed():
	if is_transitioning:
		return

	is_transitioning = true
	print("[TitleScreen] Start button clicked! Starting game...")

	# 播放淡出動畫
	if animation_player:
		animation_player.play("fade_out")
		await animation_player.animation_finished

	# 切換到遊戲場景
	get_tree().change_scene_to_file("res://scenes/Battlefield.tscn")

## 處理鍵盤輸入（可選：按任意鍵開始）
func _input(event):
	if event is InputEventKey and event.pressed and not is_transitioning:
		_on_start_pressed()
