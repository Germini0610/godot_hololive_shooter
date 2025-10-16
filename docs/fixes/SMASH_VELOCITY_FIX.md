# Smash 速度凍結修正

## 問題分析

### 之前的問題（禁用碰撞但速度仍存在）

```gdscript
# ❌ 只禁用碰撞，但單位仍有速度
enemy.collision_layer = 0
enemy.collision_mask = 0

# 問題：
# - 敵人的 linear_velocity 仍然存在
# - 恢復碰撞後，立刻因為速度而碰撞其他物體
# - 產生碰撞反應，改變位置
```

### 實際發生的情況

```
時間軸：

T=0: Smash 觸發
     玩家: position=(100, 100), velocity=(500, 0)
     敵人: position=(200, 100), velocity=(300, 100) ← 正在移動！

T=1: 禁用碰撞
     玩家: collision_layer=0, collision_mask=0
     敵人: collision_layer=0, collision_mask=0
     BUT: 敵人仍有 velocity=(300, 100) ❌

T=2: 等待物理處理
     物理引擎：「這些單位沒有碰撞」
     物理引擎：「但它們有速度，繼續移動」
     敵人位置改變：position=(200, 100) → (206, 101)

T=3: 恢復位置和碰撞
     敵人: position=恢復到(200, 100)
          collision_layer=2, collision_mask=1
          velocity=(300, 100) ← 仍然有速度！❌

T=4: 下一幀
     敵人立刻因為速度移動
     碰到其他物體 → 產生碰撞反應
     位置被改變 ❌
```

## 正確解決方案

### 關鍵：在禁用碰撞的同時清除速度

```gdscript
# ✅ 正確：記錄速度，然後立即清除
var enemy_velocity = enemy.linear_velocity
var enemy_angular = enemy.angular_velocity

enemy.linear_velocity = Vector2.ZERO  # 立即停止
enemy.angular_velocity = 0.0
enemy.collision_layer = 0
enemy.collision_mask = 0
```

### 完整流程

#### 玩家 Smash (BattleController.gd)

```gdscript
func _trigger_smash():
	# 1. 記錄所有位置、速度和碰撞設定，並立即停止所有移動
	var player_position = current_active_unit.global_position
	var player_velocity = current_active_unit.linear_velocity  # 記錄
	var player_angular = current_active_unit.angular_velocity
	var player_layer = current_active_unit.collision_layer
	var player_mask = current_active_unit.collision_mask

	var enemy_states = {}
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in all_enemies:
		enemy_states[enemy] = {
			"position": enemy.global_position,
			"velocity": enemy.linear_velocity,      # 記錄速度
			"angular": enemy.angular_velocity,
			"layer": enemy.collision_layer,
			"mask": enemy.collision_mask
		}
		# ✅ 立即停止敵人移動（關鍵！）
		enemy.linear_velocity = Vector2.ZERO
		enemy.angular_velocity = 0.0
		# 完全隔離物理
		enemy.collision_layer = 0
		enemy.collision_mask = 0

	# ✅ 停止玩家移動並完全隔離
	current_active_unit.linear_velocity = Vector2.ZERO
	current_active_unit.angular_velocity = 0.0
	current_active_unit.collision_layer = 0
	current_active_unit.collision_mask = 0

	# 2. 造成 AoE 傷害
	# ...

	# 3. 等待物理引擎處理完畢
	await get_tree().process_frame
	await get_tree().process_frame

	# 4. 恢復玩家狀態（位置不變，速度歸零，恢復碰撞）
	current_active_unit.global_position = player_position
	current_active_unit.linear_velocity = Vector2.ZERO  # 玩家停止
	current_active_unit.angular_velocity = 0.0
	current_active_unit.collision_layer = player_layer
	current_active_unit.collision_mask = player_mask
	current_active_unit.stop_movement()  # 設置 is_moving = false

	# 5. 恢復所有敵人狀態（位置不變，恢復原本的速度和碰撞）
	for enemy in enemy_states:
		if is_instance_valid(enemy):
			var state = enemy_states[enemy]
			enemy.global_position = state.position
			enemy.linear_velocity = state.velocity  # ✅ 恢復原本的速度
			enemy.angular_velocity = state.angular
			enemy.collision_layer = state.layer
			enemy.collision_mask = state.mask
```

#### 敵人 Smash (Enemy.gd)

```gdscript
func _trigger_enemy_smash():
	# 1. 記錄敵人位置、速度和碰撞設定，並立即停止移動
	var enemy_position = global_position
	var enemy_velocity = linear_velocity  # 記錄速度
	var enemy_angular = angular_velocity
	var enemy_layer = collision_layer
	var enemy_mask = collision_mask

	var player_states = {}
	var all_players = get_tree().get_nodes_in_group("player")
	for player in all_players:
		player_states[player] = {
			"position": player.global_position,
			"velocity": player.linear_velocity,  # 記錄速度
			"angular": player.angular_velocity,
			"layer": player.collision_layer,
			"mask": player.collision_mask
		}
		# ✅ 立即停止玩家移動
		player.linear_velocity = Vector2.ZERO
		player.angular_velocity = 0.0
		# 完全隔離物理
		player.collision_layer = 0
		player.collision_mask = 0

	# ✅ 停止敵人移動並完全隔離
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = 0
	collision_mask = 0

	# 2. 造成 AoE 傷害
	# ...

	# 3. 等待物理引擎處理完畢
	await get_tree().process_frame
	await get_tree().process_frame

	# 4. 恢復敵人自己的狀態（位置不變，速度歸零，恢復碰撞）
	global_position = enemy_position
	linear_velocity = Vector2.ZERO  # 敵人停止
	angular_velocity = 0.0
	collision_layer = enemy_layer
	collision_mask = enemy_mask
	stop_movement()  # 設置 is_moving = false

	# 5. 恢復所有玩家狀態（位置不變，恢復原本的速度和碰撞）
	for player in player_states:
		if is_instance_valid(player):
			var state = player_states[player]
			player.global_position = state.position
			player.linear_velocity = state.velocity  # ✅ 恢復原本的速度
			player.angular_velocity = state.angular
			player.collision_layer = state.layer
			player.collision_mask = state.mask
```

## 視覺化對比

### 舊方案（速度未清除）

```
Smash 觸發：
    🔴 ━━→ (velocity=500)
    🔵 ━→ (velocity=300)

禁用碰撞：
    👻 ━━→ (velocity=500) ← 仍在移動 ❌
    👻 ━→ (velocity=300)  ← 仍在移動 ❌

等待兩幀：
    👻 已移動 10px ← 位置改變了
    👻 已移動 6px  ← 位置改變了

恢復：
    🔴 → 原位 (velocity=500) ← 位置恢復，但有速度
    🔵 → 原位 (velocity=300) ← 位置恢復，但有速度

下一幀：
    🔴 立刻移動，碰到牆壁 ❌
    🔵 立刻移動，碰到玩家 ❌
    產生碰撞反應，位置改變 ❌
```

### 新方案（速度立即清除）

```
Smash 觸發：
    🔴 ━━→ (velocity=500)
    🔵 ━→ (velocity=300)

記錄並清除速度：
    記錄：🔴 velocity=500, 🔵 velocity=300
    清除：🔴 velocity=0,   🔵 velocity=0
    👻 ━ (stopped)
    👻 ━ (stopped)

等待兩幀：
    👻 完全靜止 ← 不移動 ✅
    👻 完全靜止 ← 不移動 ✅

恢復：
    🔴 → 原位 (velocity=0)   ← Smash 者停止
    🔵 → 原位 (velocity=300) ← 被擊者恢復移動

結果：
    🔴 完全靜止 ✅
    🔵 繼續移動（原本的軌跡） ✅
    沒有碰撞反應 ✅
```

## 關鍵改進總結

### 1. 記錄速度
```gdscript
"velocity": enemy.linear_velocity,
"angular": enemy.angular_velocity,
```

### 2. 立即清除速度（在禁用碰撞之前或同時）
```gdscript
enemy.linear_velocity = Vector2.ZERO
enemy.angular_velocity = 0.0
```

### 3. Smash 者停止，被擊者恢復
```gdscript
# Smash 者（玩家或敵人）
attacker.linear_velocity = Vector2.ZERO  # 停止

# 被擊者（其他單位）
target.linear_velocity = state.velocity  # 恢復原本速度
```

## 為什麼這樣有效？

### 物理引擎的處理順序

```
每一幀：
1. 讀取所有物體的 velocity
2. 計算新位置 = 當前位置 + velocity * delta
3. 檢查碰撞
4. 應用碰撞反應力

我們的做法：
1. 清除 velocity → 步驟 2 不會移動物體
2. 禁用碰撞 → 步驟 3 跳過
3. 恢復位置 → 強制設定正確位置
4. 恢復碰撞 → 重新啟用碰撞檢測
5. 選擇性恢復 velocity → 只有需要繼續移動的單位才恢復
```

## 測試場景

### 場景 1：玩家 Smash 正在移動的敵人

```
初始：
  🔴 ━━→ (玩家衝向敵人)
  🔵 ━→ (敵人正在移動)

玩家 Smash：
  🔴 停止 ✅
  🔵 位置不變，繼續原本的移動 ✅

結果：
  🔴 static at (100, 100)
  🔵 continues moving → (250, 120)
```

### 場景 2：敵人 Smash 正在移動的玩家

```
初始：
  🔴 ━━→ (玩家正在移動)
  🔵 ━→ (敵人衝向玩家)

敵人 Smash：
  🔵 停止 ✅
  🔴 位置不變，繼續原本的移動 ✅

結果：
  🔵 static at (200, 100)
  🔴 continues moving → (150, 80)
```

### 場景 3：多個移動中的單位

```
初始：
  🔴 ━━→ (玩家)
  🔵 ━→ (敵人 1)
  🔵 ↓ (敵人 2)
  🔵 ← (敵人 3)

玩家 Smash：
  🔴 停止 ✅
  🔵 位置不變，繼續移動 ✅
  🔵 位置不變，繼續移動 ✅
  🔵 位置不變，繼續移動 ✅

結果：所有單位位置準確，移動狀態正確！
```

## 總結

**現在 Smash 真正做到了**：

1. ✅ 只造成傷害
2. ✅ Smash 者停止移動
3. ✅ 其他單位位置完全不變
4. ✅ 其他單位繼續原本的移動（如果在移動中）
5. ✅ 完全沒有意外的物理交互
6. ✅ 完全沒有位置偏移

**核心原理**：
- 記錄速度 → 清除速度 → 處理 Smash → 選擇性恢復速度
- Smash 者速度歸零（停止）
- 其他單位速度恢復（繼續原本的運動）
