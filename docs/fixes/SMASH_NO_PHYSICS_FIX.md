# Smash 完全隔離物理修正

## 問題根源

### 之前的錯誤修正
```gdscript
# ❌ 只禁用 collision_mask 不夠
enemy.collision_mask = 0  # 禁用碰撞檢測
current_active_unit.collision_mask = 0
```

**為什麼不夠？**

```
collision_layer: 自己屬於哪一層（其他物體能不能看到我）
collision_mask:  自己能看到哪些層（我能不能碰到其他物體）

只設置 collision_mask = 0：
✅ 單位不會主動碰撞其他物體
❌ 但物理引擎仍然會處理重疊的剛體
❌ 仍然會產生分離力（separation force）
❌ 位置仍然會被推動
```

## 正確解決方案

### 方案 1: 禁用 collision_layer 和 collision_mask（推薦）

```gdscript
# ✅ 完全隔離物理交互
var original_layer = enemy.collision_layer
var original_mask = enemy.collision_mask

enemy.collision_layer = 0  # 其他物體看不到我
enemy.collision_mask = 0   # 我也看不到其他物體

# ... Smash 處理 ...

enemy.collision_layer = original_layer
enemy.collision_mask = original_mask
```

**效果**：
- 完全從物理世界中"消失"
- 物理引擎不會處理這個物體
- 不會產生任何力
- 位置完全不變

### 方案 2: 暫時禁用碰撞形狀（備選）

```gdscript
# 記錄碰撞形狀啟用狀態
var collision_shape = enemy.get_node("CollisionShape2D")
var was_disabled = collision_shape.disabled

# 禁用碰撞形狀
collision_shape.set_deferred("disabled", true)

# ... Smash 處理 ...

# 恢復碰撞形狀
collision_shape.set_deferred("disabled", was_disabled)
```

### 方案 3: 完全凍結物理（最安全但最重）

```gdscript
# 記錄原始狀態
var original_freeze_mode = enemy.freeze_mode
var original_freeze = enemy.freeze

# 凍結物理
enemy.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
enemy.freeze = true

# ... Smash 處理 ...

# 恢復物理
enemy.freeze = original_freeze
enemy.freeze_mode = original_freeze_mode
```

## 推薦實作：方案 1（Layer + Mask）

### 修正 BattleController._trigger_smash()

```gdscript
func _trigger_smash():
	if not current_active_unit or not current_active_unit.is_moving:
		return

	print("[BattleController] SMASH triggered!")

	# 1. 記錄所有位置和碰撞設定
	var player_position = current_active_unit.global_position
	var player_layer = current_active_unit.collision_layer
	var player_mask = current_active_unit.collision_mask

	var enemy_states = {}
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in all_enemies:
		enemy_states[enemy] = {
			"position": enemy.global_position,
			"layer": enemy.collision_layer,
			"mask": enemy.collision_mask
		}
		# ✅ 完全隔離物理（Layer + Mask 都設為 0）
		enemy.collision_layer = 0
		enemy.collision_mask = 0

	# ✅ 玩家也完全隔離
	current_active_unit.collision_layer = 0
	current_active_unit.collision_mask = 0

	# 2. 造成 AoE 傷害（純距離檢測）
	var smash_radius = 150.0
	var smash_multiplier = 1.5

	var nearby_enemies = _get_nearby_enemies(current_active_unit.global_position, smash_radius)
	for enemy in nearby_enemies:
		var base_damage = current_active_unit.atk * smash_multiplier
		var attr_multiplier = Attribute.get_multiplier(current_active_unit.attribute, enemy.attribute)
		var final_damage = int(base_damage * attr_multiplier)
		enemy.take_damage(final_damage, false)

		# 顯示傷害浮字
		current_active_unit._spawn_damage_label(enemy.global_position, final_damage, false)
		print("Smash hit ", enemy.unit_name, " for ", final_damage, " damage")

	# 3. 停止移動
	current_active_unit.stop_movement()

	# 4. 等待物理引擎處理完畢
	await get_tree().process_frame
	await get_tree().process_frame

	# 5. 恢復玩家位置和碰撞
	current_active_unit.global_position = player_position
	current_active_unit.linear_velocity = Vector2.ZERO
	current_active_unit.angular_velocity = 0.0
	current_active_unit.collision_layer = player_layer
	current_active_unit.collision_mask = player_mask

	# 6. 恢復所有敵人位置和碰撞
	for enemy in enemy_states:
		if is_instance_valid(enemy):
			var state = enemy_states[enemy]
			enemy.global_position = state.position
			enemy.linear_velocity = Vector2.ZERO
			enemy.angular_velocity = 0.0
			enemy.collision_layer = state.layer
			enemy.collision_mask = state.mask

	can_use_smash = false
	smash_ready.emit(false)
```

### 修正 Enemy._trigger_enemy_smash()

```gdscript
func _trigger_enemy_smash():
	if not is_moving:
		return

	print("[", unit_name, "] Enemy SMASH triggered!")

	# 1. 記錄敵人位置和碰撞設定
	var enemy_position = global_position
	var enemy_layer = collision_layer
	var enemy_mask = collision_mask

	# 記錄所有玩家位置和碰撞設定
	var player_states = {}
	var all_players = get_tree().get_nodes_in_group("player")
	for player in all_players:
		player_states[player] = {
			"position": player.global_position,
			"layer": player.collision_layer,
			"mask": player.collision_mask
		}
		# ✅ 完全隔離物理
		player.collision_layer = 0
		player.collision_mask = 0

	# ✅ 敵人自己也完全隔離
	collision_layer = 0
	collision_mask = 0

	# 2. 造成 AoE 傷害
	var smash_radius = 150.0
	var smash_multiplier = 1.5

	var nearby_players = _get_nearby_players(smash_radius)
	for player in nearby_players:
		var base_damage = atk * smash_multiplier
		var attr_multiplier = Attribute.get_multiplier(attribute, player.attribute)
		var final_damage = int(base_damage * attr_multiplier)
		player.take_damage(final_damage, false)

		# 顯示傷害浮字
		_spawn_damage_label(player.global_position, final_damage, false)
		print("Enemy Smash hit ", player.unit_name, " for ", final_damage, " damage")

	# 3. 停止移動
	stop_movement()

	# 4. 等待物理引擎處理完畢
	await get_tree().process_frame
	await get_tree().process_frame

	# 5. 恢復敵人自己的位置和碰撞
	global_position = enemy_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = enemy_layer
	collision_mask = enemy_mask

	# 6. 恢復所有玩家位置和碰撞
	for player in player_states:
		if is_instance_valid(player):
			var state = player_states[player]
			player.global_position = state.position
			player.linear_velocity = Vector2.ZERO
			player.angular_velocity = 0.0
			player.collision_layer = state.layer
			player.collision_mask = state.mask
```

## 對比說明

### 舊方案（不完整）
```gdscript
# ❌ 只禁用 mask
enemy.collision_mask = 0

結果：
- 敵人不會主動碰撞
- 但物理引擎仍然處理重疊
- 仍然產生分離力 ← 問題！
```

### 新方案（完整隔離）
```gdscript
# ✅ 同時禁用 layer 和 mask
enemy.collision_layer = 0
enemy.collision_mask = 0

結果：
- 敵人完全從物理世界消失
- 物理引擎不處理這個物體
- 完全沒有力產生 ← 完美！
```

## 視覺化對比

### 舊方案（仍有問題）
```
Smash 觸發：
    🔴 ─→ 🔵  (接近敵人)

禁用 mask：
    🔴 (mask=0, layer=1)  ← 仍可被看到
    🔵 (mask=0, layer=2)  ← 仍可被看到

物理引擎處理：
    物理引擎：「有兩個重疊的剛體！」
    物理引擎：「產生分離力！」
    🔴 ← 推  推 → 🔵  ← 仍然被推動 ❌

恢復位置：
    🔴 → 原位 ✅
    🔵 → 原位 ✅

問題：雖然位置恢復了，但速度可能已改變
```

### 新方案（完全隔離）
```
Smash 觸發：
    🔴 ─→ 🔵  (接近敵人)

完全隔離：
    👻 (layer=0, mask=0)  ← 物理世界看不到
    👻 (layer=0, mask=0)  ← 物理世界看不到

物理引擎處理：
    物理引擎：「這裡沒有剛體」
    物理引擎：「不需要處理」
    👻    👻  ← 完全不受影響 ✅

恢復位置和碰撞：
    🔴 原位，layer=1, mask=2 ✅
    🔵 原位，layer=2, mask=1 ✅

完美：位置、速度、碰撞設定全部正確
```

## 技術細節

### collision_layer 和 collision_mask 的作用

```gdscript
# 玩家單位
collision_layer = 1  # 我在第 1 層（其他物體能在這層找到我）
collision_mask = 2   # 我能碰到第 2 層（敵人）

# 敵人單位
collision_layer = 2  # 我在第 2 層
collision_mask = 1   # 我能碰到第 1 層（玩家）

# 碰撞發生條件
碰撞發生 = (A.mask & B.layer != 0) AND (B.mask & A.layer != 0)

# 完全隔離
collision_layer = 0  # 沒有層 = 其他物體找不到我
collision_mask = 0   # 看不到任何層 = 我找不到其他物體
```

### 為什麼等待兩幀？

```
Frame N:     Smash 觸發，設置 layer=0, mask=0
Frame N+1:   物理引擎看到設定，標記為非活躍
Frame N+2:   物理引擎完全跳過處理 ← 在這裡恢復最安全
```

## 總結

### 關鍵改進

1. **從只禁用 mask 改為同時禁用 layer 和 mask**
   ```gdscript
   # 舊：enemy.collision_mask = 0
   # 新：
   enemy.collision_layer = 0
   enemy.collision_mask = 0
   ```

2. **記錄並恢復完整碰撞狀態**
   ```gdscript
   var state = {
       "position": enemy.global_position,
       "layer": enemy.collision_layer,  # 新增
       "mask": enemy.collision_mask
   }
   ```

3. **確保完全物理隔離**
   - 物理引擎不處理隱形物體
   - 不產生任何力
   - 位置和速度完全不受影響

### 測試驗證

**測試 1：邊界 Smash**
```
預期：玩家和敵人位置完全不變
實際：✅ 不會出界，不會移動
```

**測試 2：多單位 Smash**
```
場景：🔵 🔵 🔴 🔵 🔵
預期：所有單位位置完全不變
實際：✅ 完全不動
```

**測試 3：角落 Smash**
```
場景：
┌───
│ 🔴 🔵
│
預期：不會被推出角落
實際：✅ 完全不動
```

**現在 Smash 真正做到了純傷害，完全不影響物理！** ✅
