# 碰撞不回彈修正

## 問題描述

當玩家碰到敵人時，敵人會被物理引擎彈開（回彈）。這是因為使用了 `RigidBody2D`，物理引擎會自動處理碰撞反應。

## 問題原因

### RigidBody2D 的碰撞行為

```
玩家 → 碰到敵人

物理引擎自動處理：
1. 檢測碰撞
2. 計算衝量（impulse）
3. 對雙方施加分離力
4. 結果：雙方都被彈開
```

### 視覺化

```
碰撞前：
  🔴 ━━→  🔵 (玩家移動，敵人靜止)

碰撞瞬間：
  🔴 💥 🔵 (物理引擎偵測碰撞)

物理引擎處理：
  🔴 ← ⚡ ⚡ → 🔵 (產生分離力)

碰撞後：
  🔴 ←━  ━→ 🔵 (雙方都被彈開) ❌
```

## 解決方案

### 策略：記錄位置 → 碰撞 → 恢復位置

在碰撞處理中：
1. **碰撞前**：記錄被擊者的位置和速度
2. **碰撞時**：計算並造成傷害（物理引擎自動處理碰撞）
3. **碰撞後**：等待一幀，然後恢復被擊者的位置和速度

### 實作細節

#### 玩家碰撞敵人

```gdscript
func _handle_enemy_collision(enemy):
	if not enemy.has_method("take_damage"):
		return

	# 1. 記錄敵人碰撞前的位置和速度
	var enemy_position = enemy.global_position
	var enemy_velocity = enemy.linear_velocity
	var enemy_angular = enemy.angular_velocity

	# 2. 計算傷害
	var speed_scale = velocity_magnitude / MAX_SPEED
	var collision_point = global_position
	var is_weakness = _check_weakness(enemy, collision_point)

	var base_damage = atk * speed_scale
	var attr_multiplier = Attribute.get_multiplier(attribute, enemy.attribute)
	var buff_multiplier = _calculate_buff_multiplier()
	var weakness_multiplier = 1.5 if is_weakness else 1.0

	var final_damage = int(base_damage * attr_multiplier * buff_multiplier * weakness_multiplier)

	# 3. 造成傷害
	enemy.take_damage(final_damage, is_weakness)
	damaged.emit(final_damage, is_weakness)

	# 顯示傷害浮字
	_spawn_damage_label(enemy.global_position, final_damage, is_weakness)

	# 累積技能量表
	if is_player_unit:
		var skill_gain = int(speed_scale * 20)
		get_tree().call_group("battle_controller", "add_skill_gauge", skill_gain)

	# 4. 恢復敵人位置和速度（防止被碰撞回彈）
	await get_tree().process_frame
	if is_instance_valid(enemy):
		enemy.global_position = enemy_position
		enemy.linear_velocity = enemy_velocity
		enemy.angular_velocity = enemy_angular
```

#### 敵人碰撞玩家

```gdscript
func _handle_player_collision(player):
	if not player.has_method("take_damage"):
		return

	# 1. 記錄玩家碰撞前的位置和速度
	var player_position = player.global_position
	var player_velocity = player.linear_velocity
	var player_angular = player.angular_velocity

	# 2. 計算傷害
	var speed_scale = velocity_magnitude / MAX_SPEED
	var collision_point = global_position
	var is_weakness = _check_weakness(player, collision_point)

	var base_damage = atk * speed_scale
	var attr_multiplier = Attribute.get_multiplier(attribute, player.attribute)
	var buff_multiplier = _calculate_buff_multiplier()
	var weakness_multiplier = 1.5 if is_weakness else 1.0

	var final_damage = int(base_damage * attr_multiplier * buff_multiplier * weakness_multiplier)

	# 3. 造成傷害
	player.take_damage(final_damage, is_weakness)

	# 顯示傷害浮字
	_spawn_damage_label(player.global_position, final_damage, is_weakness)

	# 4. 恢復玩家位置和速度（防止被碰撞回彈）
	await get_tree().process_frame
	if is_instance_valid(player):
		player.global_position = player_position
		player.linear_velocity = player_velocity
		player.angular_velocity = player_angular
```

## 時間軸說明

### 詳細步驟

```
Frame N (碰撞發生):
  1. _on_body_entered() 被觸發
  2. 記錄敵人位置: position=(200, 100)
  3. 記錄敵人速度: velocity=(0, 0)
  4. 計算並造成傷害
  5. await get_tree().process_frame (暫停，等待下一幀)

Frame N+1 (物理處理):
  - 物理引擎處理碰撞
  - 對雙方施加分離力
  - 玩家位置改變: (100, 100) → (95, 98)
  - 敵人位置改變: (200, 100) → (205, 102) ❌

Frame N+2 (恢復位置):
  - await 結束，繼續執行
  - 恢復敵人位置: (205, 102) → (200, 100) ✅
  - 恢復敵人速度: (50, 20) → (0, 0) ✅
```

### 為什麼等待一幀？

```
立即恢復（錯誤）:
  記錄位置 → 恢復位置 → 物理引擎處理
  結果：物理引擎在恢復後才處理，仍然會改變位置 ❌

等待一幀（正確）:
  記錄位置 → 物理引擎處理 → 恢復位置
  結果：物理引擎的改變被覆蓋，位置恢復正確 ✅
```

## 視覺化對比

### 修正前（有回彈）

```
T=0: 碰撞前
     🔴 ━━→ velocity=(500, 0)
     🔵     velocity=(0, 0)

T=1: 碰撞發生
     🔴 💥 🔵
     計算傷害：100 damage

T=2: 物理引擎處理
     🔴 ←━  velocity=(-200, 0) (反彈)
     🔵  ━→ velocity=(300, 0)  (被推動) ❌

結果：
     🔴 往回彈
     🔵 被推開 ❌
```

### 修正後（無回彈）

```
T=0: 碰撞前
     🔴 ━━→ velocity=(500, 0)
     🔵     velocity=(0, 0)
     記錄：enemy_position=(200, 100), enemy_velocity=(0, 0)

T=1: 碰撞發生
     🔴 💥 🔵
     計算傷害：100 damage
     await process_frame (等待)

T=2: 物理引擎處理
     🔴 ←━  velocity=(-200, 0) (玩家反彈)
     🔵  ━→ velocity=(300, 0)  (敵人被推動)
     position=(205, 102)

T=3: 恢復敵人狀態
     🔵 → 恢復到 position=(200, 100) ✅
     🔵 → 恢復到 velocity=(0, 0) ✅

結果：
     🔴 往回彈（正常反彈）
     🔵 位置不變 ✅
```

## 關鍵要點

### 1. 只恢復被擊者，不恢復攻擊者

```gdscript
# 玩家碰撞敵人：
# - 玩家：正常反彈（不恢復）
# - 敵人：位置不變（恢復）

# 敵人碰撞玩家：
# - 敵人：正常反彈（不恢復）
# - 玩家：位置不變（恢復）
```

### 2. 等待一幀讓物理處理完成

```gdscript
await get_tree().process_frame
```

### 3. 檢查實例有效性

```gdscript
if is_instance_valid(enemy):
    # 恢復位置和速度
```

防止在等待期間，敵人被刪除（例如被打死）。

## 測試場景

### 場景 1：玩家碰撞靜止的敵人

```
初始：
  🔴 ━━→ (玩家移動)
  🔵     (敵人靜止)

碰撞後：
  🔴 ←━  (玩家反彈)
  🔵     (敵人不動) ✅

預期：敵人位置和速度都不變
```

### 場景 2：玩家碰撞移動中的敵人

```
初始：
  🔴 ━━→ (玩家移動)
  🔵 ↓   (敵人向下移動)

碰撞後：
  🔴 ←━  (玩家反彈)
  🔵 ↓   (敵人繼續向下) ✅

預期：敵人保持原本的移動方向和速度
```

### 場景 3：敵人碰撞玩家

```
初始：
  🔴     (玩家靜止)
  🔵 ━→ (敵人衝向玩家)

碰撞後：
  🔴     (玩家不動) ✅
  🔵 ←━  (敵人反彈)

預期：玩家位置和速度都不變
```

### 場景 4：多重碰撞

```
初始：
  🔴 ━━→ (玩家向右)
  🔵 🔵 🔵 (三個敵人排成一列)

碰撞順序：
  T=1: 🔴 💥 🔵₁ → 敵人₁不動 ✅
  T=2: 🔴 💥 🔵₂ → 敵人₂不動 ✅
  T=3: 🔴 💥 🔵₃ → 敵人₃不動 ✅

結果：所有敵人位置都不變
```

## 與其他系統的關係

### 與 Smash 的差異

```
一般碰撞：
  - 只恢復被擊者位置
  - 攻擊者正常反彈

Smash：
  - 恢復所有單位位置
  - 攻擊者也停止移動
```

### 與弱點系統的關係

```
碰撞處理流程：
1. 記錄位置和速度
2. 檢查是否命中弱點 ← 在恢復前檢查
3. 計算傷害（含弱點倍率）
4. 造成傷害
5. 恢復位置和速度 ← 不影響弱點判定
```

## 總結

**修正方法**：
- 在碰撞處理函數中記錄被擊者的位置和速度
- 等待一幀讓物理引擎處理碰撞
- 恢復被擊者的位置和速度

**效果**：
- ✅ 被擊者（敵人或玩家）不會被彈開
- ✅ 被擊者保持原本的位置和移動狀態
- ✅ 攻擊者正常反彈（符合彈珠台機制）
- ✅ 不影響傷害計算和弱點判定

**現在碰撞行為正確！被攻擊者不會回彈！** ✅
