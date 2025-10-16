extends Node2D

## 测试 Ina VFX 系统
## 按 1/2/3 键测试不同的特效

func _ready():
	print("[TestInaVFX] Press 1, 2, or 3 to test VFX effects")
	print("  1 = VFX 2 (Sacrifice Self Drain)")
	print("  2 = VFX 4 (Leader Skill Drain)")
	print("  3 = VFX 10 (Madness Drain)")

func _input(event):
	if event is InputEventKey and event.pressed:
		var test_position = get_viewport().get_mouse_position()

		match event.keycode:
			KEY_1:
				print("\n[TestInaVFX] Testing VFX 2 at ", test_position)
				InaVFX.spawn_sacrifice_self_drain_vfx(test_position, get_tree().root)
			KEY_2:
				print("\n[TestInaVFX] Testing VFX 4 at ", test_position)
				InaVFX.spawn_leader_skill_drain_vfx(test_position, get_tree().root)
			KEY_3:
				print("\n[TestInaVFX] Testing VFX 10 at ", test_position)
				InaVFX.spawn_madness_drain_vfx(test_position, get_tree().root)
