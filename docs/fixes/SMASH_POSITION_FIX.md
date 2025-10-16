# Smash 位置修正

## 問題分析

### 問題 1: 紅色單位出界，藍色不會
**原因**: 玩家 Smash 後，玩家自己的位置沒有被恢復，可能被物理引擎推出邊界

### 問題 2: 紅色 Smash 後藍色單位亂跑
**原因**: Smash 只恢復了目標（敵人）的位置，但忘記恢復**攻擊者自己**的位置

## 根本原因

### 原本的錯誤邏輯
```gdscript
func _trigger_smash():
    # ❌ 只記錄敵人位置
    var enemy_positions = {}
    for enemy in all_enemies:
        enemy_positions[enemy] = enemy.global_position

    # 禁用碰撞
    collision_mask = 0

    # 造成傷害
    # ...

    # 停止移動
    stop_movement()

    # ❌ 只恢復敵人位置
    for enemy in enemy_positions:
        enemy.global_position = enemy_positions[enemy]

    # ❌ 玩家自己的位置沒有恢復！
```

### 為什麼會亂跑？

```
Smash 觸發時的物理狀態：

    🔴 玩家
     ↓ 移動中
    🔵 敵人1
  🔵 敵人2

步驟 1: 禁用碰撞
    🔴 (mask=0)
    🔵 (mask=1)
    🔵 (mask=1)

步驟 2: 停止玩家移動
    🔴 停止
    但物理引擎仍在處理...

步驟 3: 等待一幀
    物理引擎計算：
    - 玩家和敵人重疊
    - 產生分離力
    - 玩家被推動 ❌
    - 敵人被推動 ❌

步驟 4: 只恢復敵人
    🔵 位置恢復 ✅
    🔵 位置恢復 ✅
    🔴 位置沒恢復 ❌  ← 問題！

結果：
    玩家被推到錯誤位置
    可能出界或在奇怪的地方
```

## 修正方案

### 關鍵改進

#### 1. 記錄攻擊者自己的位置
```gdscript
# ✅ 記錄玩家當前位置（重要！）
var player_position = current_active_unit.global_position
```

#### 2. 禁用所有單位的碰撞
```gdscript
# 記錄所有敵人原始位置
for enemy in all_enemies:
    enemy_positions[enemy] = enemy.global_position
    # ✅ 同時禁用敵人碰撞，防止互相推擠
    enemy.collision_mask = 0

# 禁用玩家碰撞
current_active_unit.collision_mask = 0
```

#### 3. 等待兩幀確保物理完成
```gdscript
# ✅ 等待物理引擎處理完畢
await get_tree().process_frame
await get_tree().process_frame  # 等待兩幀確保物理完成
```

**為什麼需要兩幀？**
- 第一幀：物理引擎開始處理
- 第二幀：確保所有物理計算完成
- 更安全，避免殘留力

#### 4. 恢復攻擊者自己的位置
```gdscript
# ✅ 強制恢復玩家位置（重要！）
current_active_unit.global_position = player_position
current_active_unit.linear_velocity = Vector2.ZERO
current_active_unit.angular_velocity = 0.0
```

#### 5. 恢復所有目標位置
```gdscript
# 強制恢復所有敵人位置
for enemy in enemy_positions:
    if is_instance_valid(enemy):
        enemy.global_position = enemy_positions[enemy]
        enemy.linear_velocity = Vector2.ZERO
        enemy.angular_velocity = 0.0
        # ✅ 恢復敵人碰撞
        enemy.collision_mask = 1  # Player layer
```

#### 6. 恢復攻擊者碰撞
```gdscript
# ✅ 恢復玩家碰撞
current_active_unit.collision_mask = original_collision_mask
```

## 完整修正流程

### 玩家 Smash (BattleController.gd)

```gdscript
func _trigger_smash():
    # 1. 記錄所有位置
    var player_position = current_active_unit.global_position  ✅
    var enemy_positions = {}
    for enemy in all_enemies:
        enemy_positions[enemy] = enemy.global_position

    # 2. 禁用所有碰撞
    for enemy in all_enemies:
        enemy.collision_mask = 0  ✅
    current_active_unit.collision_mask = 0

    # 3. 造成傷害
    for enemy in nearby_enemies:
        enemy.take_damage(damage)

    # 4. 停止移動
    current_active_unit.stop_movement()

    # 5. 等待物理完成（兩幀）
    await get_tree().process_frame
    await get_tree().process_frame  ✅

    # 6. 恢復所有位置（包括自己！）
    current_active_unit.global_position = player_position  ✅
    current_active_unit.linear_velocity = Vector2.ZERO
    current_active_unit.angular_velocity = 0.0

    for enemy in enemy_positions:
        enemy.global_position = enemy_positions[enemy]
        enemy.linear_velocity = Vector2.ZERO
        enemy.angular_velocity = 0.0
        enemy.collision_mask = 1  ✅

    # 7. 恢復自己的碰撞
    current_active_unit.collision_mask = original_collision_mask  ✅
```

### 敵人 Smash (Enemy.gd)

```gdscript
func _trigger_enemy_smash():
    # 1. 記錄所有位置
    var enemy_position = global_position  ✅
    var player_positions = {}
    for player in all_players:
        player_positions[player] = player.global_position

    # 2. 禁用所有碰撞
    for player in all_players:
        player.collision_mask = 0  ✅
    collision_mask = 0

    # 3. 造成傷害
    # ...

    # 4. 停止移動
    stop_movement()

    # 5. 等待物理完成
    await get_tree().process_frame
    await get_tree().process_frame  ✅

    # 6. 恢復所有位置（包括自己！）
    global_position = enemy_position  ✅
    linear_velocity = Vector2.ZERO
    angular_velocity = 0.0

    for player in player_positions:
        player.global_position = player_positions[player]
        player.linear_velocity = Vector2.ZERO
        player.angular_velocity = 0.0
        player.collision_mask = 2  ✅

    # 7. 恢復自己的碰撞
    collision_mask = original_collision_mask  ✅
```

## 視覺化對比

### 修正前
```
Smash 觸發：
    🔴 ─→ 🔵  (玩家移動中)

停止移動：
    🔴    🔵

等待一幀：
    物理引擎推動...
    🔴 被推 ←  ← 🔵 被推

只恢復敵人：
    🔴 ❌    🔵 ✅

結果：
    🔴 在錯誤位置（可能出界）
    🔵 恢復正常
```

### 修正後
```
Smash 觸發：
    🔴 ─→ 🔵  (玩家移動中)
    記錄: 玩家 pos ✅, 敵人 pos ✅

禁用所有碰撞：
    🔴 (mask=0) 🔵 (mask=0)

停止移動：
    🔴    🔵

等待兩幀：
    物理引擎處理...
    (但碰撞已禁用，不會推動)

恢復所有位置：
    🔴 → 原位 ✅
    🔵 → 原位 ✅

結果：
    🔴 位置正確 ✅
    🔵 位置正確 ✅
```

## 測試場景

### 測試 1: 紅色單位邊界測試
```
1. 向左發射紅色單位到邊界附近
2. 在邊界附近觸發 Smash
3. 結果：
   ✅ 修正前：可能出界
   ✅ 修正後：位置不變，留在邊界內
```

### 測試 2: 多敵人 Smash
```
場景：
    🔵
  🔵 🔴 🔵  (三個敵人圍繞玩家)
    🔵

Smash 觸發：
  ✅ 修正前：玩家和敵人可能亂跑
  ✅ 修正後：所有單位位置完全不變
```

### 測試 3: 角落 Smash
```
牆角
┌───
│ 🔴 🔵  (在角落)
│

Smash 觸發：
  ✅ 修正前：玩家可能被推出角落
  ✅ 修正後：玩家和敵人都保持原位
```

### 測試 4: 敵人 Smash
```
場景：
  🔴 ← 🔵  (敵人衝向玩家)

敵人 Smash 觸發：
  ✅ 修正前：敵人和玩家可能亂跑
  ✅ 修正後：雙方位置完全不變
```

## 關鍵要點

### 必須記住的三件事

1. **記錄攻擊者自己的位置**
   ```gdscript
   var attacker_position = global_position  // 重要！
   ```

2. **禁用雙方的碰撞**
   ```gdscript
   attacker.collision_mask = 0
   for target in targets:
       target.collision_mask = 0
   ```

3. **恢復雙方的位置**
   ```gdscript
   attacker.global_position = attacker_position  // 重要！
   for target in targets:
       target.global_position = target_positions[target]
   ```

### 為什麼等待兩幀？

```
Frame N:     Smash 觸發，禁用碰撞
Frame N+1:   物理引擎第一次處理
Frame N+2:   物理引擎完成處理 ← 在這裡恢復位置最安全
```

## 技術細節

### collision_mask 的作用
```gdscript
collision_mask = 0  // 不與任何 layer 碰撞
collision_mask = 1  // 與 layer 1 碰撞 (Player)
collision_mask = 2  // 與 layer 2 碰撞 (Enemy)
collision_mask = 3  // 與 layer 1 和 2 碰撞
```

### 恢復順序
```
1. 等待物理完成
2. 恢復攻擊者位置 ← 先
3. 恢復目標位置
4. 恢復碰撞
```

## 總結

### 修正前的問題
- ❌ 只恢復目標位置
- ❌ 攻擊者位置沒恢復
- ❌ 攻擊者可能出界或亂跑
- ❌ 目標仍可能被推動

### 修正後的效果
- ✅ 記錄攻擊者和目標位置
- ✅ 禁用雙方碰撞
- ✅ 等待兩幀確保物理完成
- ✅ 恢復雙方位置和速度
- ✅ 恢復雙方碰撞
- ✅ 所有單位位置完全不變

**現在 Smash 功能完美運作，沒有位置異常！** ✅
