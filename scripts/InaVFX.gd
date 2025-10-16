extends Node2D
class_name InaVFX

## Ina 的特效播放系統
## 負責播放 Dark VFX 1-12 的動畫

enum VFXType {
	VFX_1,   #
	VFX_2,   # 古神的咒福：隊長技能效果（作用在隊伍）
	VFX_3,   #
	VFX_4,   # 深淵之握：大招效果（作用在敵人）
	VFX_5,   #
	VFX_6,   # Smash 翻牌：擊中敵人效果（作用在被攻擊的敵人）
	VFX_7,   #
	VFX_8,   #
	VFX_9,   #
	VFX_10,  # 癲狂被動：翻牌吸血效果（作用在自身，僅開場演示）
	VFX_11,  #
	VFX_12   #
}

## VFX 配置資料
const VFX_CONFIGS = {
	VFXType.VFX_2: {
		"sprite_sheet": "res://material/ina/Dark VFX 2/Dark VFX 2 (48x64).png",
		"frame_size": Vector2(48, 64),
		"frame_count": 16,
		"fps": 15,  # 降低播放速度
		"loop": false
	},
	VFXType.VFX_4: {
		"sprite_sheet": "res://material/ina/Dark VFX 4/Dark VFX 4 (48x56).png",
		"frame_size": Vector2(48, 56),
		"frame_count": 31,
		"fps": 18,  # 降低播放速度
		"loop": false
	},
	VFXType.VFX_6: {
		"sprite_sheet": "res://material/ina/Dark VFX 6/Dark VFX 6 Vertical (48x64).png",
		"frame_size": Vector2(48, 64),
		"frame_count": 16,
		"fps": 16,  # 放慢一点，从 20 降到 16
		"loop": false
	},
	VFXType.VFX_7: {
		"sprite_sheet": "res://material/ina/Dark VFX 7/Dark VFX 7 Ending (48x48).png",
		"frame_size": Vector2(48, 48),
		"frame_count": 29,
		"fps": 20,  # 快速爆發效果
		"loop": false
	},
	VFXType.VFX_10: {
		"sprite_sheet": "res://material/ina/Dark VFX 10/Dark VFX10 (48x48).png",
		"frame_size": Vector2(48, 48),
		"frame_count": 26,
		"fps": 16,  # 降低播放速度
		"loop": false
	}
}

var animated_sprite: AnimatedSprite2D
var current_vfx_type: VFXType
var is_cleanup_scheduled: bool = false  # 防止重复删除

func _ready():
	# 設置為 top_level，使 VFX 不受父節點變換影響，固定在世界座標
	top_level = true

	animated_sprite = AnimatedSprite2D.new()
	add_child(animated_sprite)
	# 使用 CONNECT_ONE_SHOT 确保信号只触发一次
	animated_sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

## 播放指定 VFX
func play_vfx(vfx_type: VFXType, target_position: Vector2 = Vector2.ZERO, scale_factor: float = 1.0):
	if not VFX_CONFIGS.has(vfx_type):
		push_error("[InaVFX] VFX type not configured: ", vfx_type)
		print("[InaVFX] ERROR: VFX type ", vfx_type, " not configured")
		return

	current_vfx_type = vfx_type
	var config = VFX_CONFIGS[vfx_type]

	print("[InaVFX] ======== Starting VFX ", vfx_type, " ========")
	print("[InaVFX] Position: ", target_position)
	print("[InaVFX] Scale: ", scale_factor)

	# 設置位置
	global_position = target_position

	# 設置縮放
	animated_sprite.scale = Vector2(scale_factor, scale_factor)

	# 確保 z_index 高於其他物件
	z_index = 100
	animated_sprite.z_index = 100

	# 創建 SpriteFrames 資源
	var sprite_frames = _create_sprite_frames_from_sheet(config)
	animated_sprite.sprite_frames = sprite_frames

	# 播放動畫
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")
		print("[InaVFX] Animation started successfully")
	else:
		print("[InaVFX] ERROR: Cannot play animation - sprite_frames or animation not found")

	print("[InaVFX] ======== VFX ", vfx_type, " setup complete ========")

## 從 Sprite Sheet 創建 SpriteFrames
func _create_sprite_frames_from_sheet(config: Dictionary) -> SpriteFrames:
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("default")

	# 載入 sprite sheet
	var texture: Texture2D = null
	if ResourceLoader.exists(config.sprite_sheet):
		texture = ResourceLoader.load(config.sprite_sheet) as Texture2D

	if not texture:
		push_error("[InaVFX] Failed to load texture: ", config.sprite_sheet)
		print("[InaVFX] ERROR: Cannot load texture from ", config.sprite_sheet)
		return sprite_frames

	print("[InaVFX] Successfully loaded texture: ", config.sprite_sheet)
	var frame_size = config.frame_size
	var frame_count = config.frame_count

	# 計算 sprite sheet 的列數和行數
	var texture_size = texture.get_size()
	var columns = int(texture_size.x / frame_size.x)
	var rows = int(texture_size.y / frame_size.y)

	print("[InaVFX] Texture size: ", texture_size, ", Frame size: ", frame_size, ", Grid: ", columns, "x", rows)

	# 從 sprite sheet 切割幀
	var frame_index = 0
	for row in range(rows):
		for col in range(columns):
			if frame_index >= frame_count:
				break

			# 創建 AtlasTexture
			var atlas = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				col * frame_size.x,
				row * frame_size.y,
				frame_size.x,
				frame_size.y
			)

			sprite_frames.add_frame("default", atlas)
			frame_index += 1

		if frame_index >= frame_count:
			break

	print("[InaVFX] Created ", frame_index, " frames")

	# 設置 FPS
	sprite_frames.set_animation_speed("default", config.fps)

	# 設置循環
	sprite_frames.set_animation_loop("default", config.loop)

	return sprite_frames

## 動畫播放完成回調
func _on_animation_finished():
	# 防止重複刪除
	if is_cleanup_scheduled:
		print("[InaVFX] Cleanup already scheduled, skipping")
		return

	# 检查是否还在场景树中
	if not is_inside_tree():
		print("[InaVFX] Not in tree, VFX already removed")
		return

	# 標記為已清理
	is_cleanup_scheduled = true
	print("[InaVFX] Animation finished, scheduling cleanup")

	# 使用 call_deferred 安全刪除
	call_deferred("_safe_cleanup")

## 安全清理 VFX
func _safe_cleanup():
	# 再次檢查是否在樹中
	if not is_inside_tree():
		print("[InaVFX] Already removed from tree in _safe_cleanup")
		return

	print("[InaVFX] Executing queue_free...")
	queue_free()

## 靜態工具函數：快速播放 VFX
static func spawn_vfx(vfx_type: VFXType, position: Vector2, parent: Node, scale_factor: float = 1.0) -> InaVFX:
	# 檢查父節點是否有效
	if not is_instance_valid(parent):
		push_error("[InaVFX] Invalid parent node for VFX spawn")
		return null

	# 檢查父節點是否在場景樹中
	if not parent.is_inside_tree():
		push_error("[InaVFX] Parent node is not in the scene tree")
		return null

	var vfx = InaVFX.new()
	parent.add_child(vfx)
	vfx.play_vfx(vfx_type, position, scale_factor)
	return vfx

## 快速播放 VFX 2（古神的咒福：隊長技能）
static func spawn_leader_skill_vfx(position: Vector2, parent: Node) -> InaVFX:
	return spawn_vfx(VFXType.VFX_2, position, parent, 4.0)  # 增大縮放

## 快速播放 VFX 4（深淵之握：大招效果在敵人身上）
static func spawn_sacrifice_enemy_vfx(position: Vector2, parent: Node) -> InaVFX:
	return spawn_vfx(VFXType.VFX_4, position, parent, 3.5)  # 增大縮放

## 快速播放 VFX 6（Smash 翻牌：擊中敵人）
static func spawn_smash_hit_vfx(position: Vector2, parent: Node) -> InaVFX:
	return spawn_vfx(VFXType.VFX_6, position, parent, 4.5)  # 从 3.0 放大到 4.5

## 快速播放 VFX 10（癲狂被動：翻牌吸血，僅開場演示）
static func spawn_madness_drain_vfx(position: Vector2, parent: Node) -> InaVFX:
	return spawn_vfx(VFXType.VFX_10, position, parent, 4.5)
