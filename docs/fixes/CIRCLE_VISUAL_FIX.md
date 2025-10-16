# 視覺與 Smash 修正

## 修正 1: 圓形視覺 ✅

### 問題
原本使用 ColorRect（矩形）顯示圓形單位 ❌

### 解決方案
建立 CircleSprite.gd 使用 draw_circle() 繪製真正的圓形

### 新增檔案

**scripts/CircleSprite.gd**
```gdscript
extends Node2D
class_name CircleSprite

@export var radius: float = 30.0
@export var color: Color = Color.RED

func _draw():
    draw_circle(Vector2.ZERO, radius, color)
```

### 修改檔案

**scenes/Unit.tscn**
```
修正前:
[node name="Sprite" type="ColorRect" parent="."]
offset_left = -30.0
offset_top = -30.0
offset_right = 30.0
offset_bottom = 30.0
color = Color(1, 0, 0, 1)

修正後:
[node name="Sprite" type="Node2D" parent="."]
script = ExtResource("CircleSprite.gd")
radius = 30.0
color = Color(1, 0, 0, 1)
```

**scenes/Enemy.tscn**
```
修正前:
[node name="Sprite" type="ColorRect" parent="."]
offset_left = -35.0
offset_top = -35.0
offset_right = 35.0
offset_bottom = 35.0
color = Color(0, 0, 1, 1)

修正後:
[node name="Sprite" type="Node2D" parent="."]
script = ExtResource("CircleSprite.gd")
radius = 35.0
color = Color(0, 0, 1, 1)
```

### 效果對比

**修正前（方形）**
```
┌──────┐
│ 碰撞 │  ← 方形視覺
│ 圓形 │  ← 圓形碰撞體
└──────┘
視覺與碰撞不一致 ❌
```

**修正後（圓形）**
```
   ●
  ╱ ╲    ← 圓形視覺
 │   │   ← 圓形碰撞體
  ╲ ╱
   ●
視覺與碰撞完全一致 ✅
```

---

## 修正 2: 敵人 Smash 問題排查

### 可能原因分析

#### 原因 1: 敵人沒有執行 CHARGE 行動
```gdscript
# 檢查點 1: action_type 是否設為 CHARGE
@export var action_type: ActionType = ActionType.CHARGE  ✓

# 檢查點 2: action_count 是否會歸零
func decrease_action_count(amount: int = 1):
    current_action_count -= amount
    if current_action_count <= 0:
        execute_action()  ✓
```

**測試方法**：
```
查看控制台是否有：
"[Enemy] Executing CHARGE action"

如果沒有 → 敵人沒有執行行動
如果有 → 繼續下一步檢查
```

#### 原因 2: 隨機判定沒通過
```gdscript
if randf() > 0.5:  # 50% 機率
    _trigger_enemy_smash()
```

**機率太低**：平均每 2 次衝撞才觸發 1 次

**測試調整**：
```gdscript
# 改為必定觸發（測試用）
if true:  # 100% 觸發
    await get_tree().create_timer(0.5).timeout
    if is_moving:
        _trigger_enemy_smash()
```

#### 原因 3: 延遲期間敵人已停止
```gdscript
await get_tree().create_timer(randf_range(0.3, 0.8)).timeout
if is_moving:  # 可能已經 false
    _trigger_enemy_smash()
```

**可能情況**：
- 延遲 0.3-0.8 秒太長
- 敵人已經碰到牆壁或玩家而停止
- `is_moving` 變成 false

**測試調整**：
```gdscript
# 縮短延遲（測試用）
await get_tree().create_timer(0.1).timeout
```

#### 原因 4: BattleController 沒有減少 action_count
```gdscript
# BattleController._end_player_move()
func _decrease_all_enemy_action_counts():
    var enemies = get_tree().get_nodes_in_group("enemy")
    for enemy in enemies:
        if enemy.has_method("decrease_action_count"):
            enemy.decrease_action_count(1)
```

**檢查點**：
- 玩家是否完成移動？
- 是否調用了 _end_player_move()？
- 敵人是否在 "enemy" 群組？

### 調試步驟

#### 步驟 1: 確認敵人會執行行動
```gdscript
# 在 Enemy.gd:57 添加
func _execute_charge():
    print("=== CHARGE DEBUG ===")
    print("Target found: ", _find_nearest_player() != null)
    print("===================")
    # ... 原有程式碼
```

#### 步驟 2: 確認隨機判定
```gdscript
# 在 Enemy.gd:68 添加
# 移動中途隨機觸發 Smash（50% 機率）
var rand_value = randf()
print("Smash random check: ", rand_value, " > 0.5? ", rand_value > 0.5)
if rand_value > 0.5:
    # ... 原有程式碼
```

#### 步驟 3: 確認延遲與移動狀態
```gdscript
# 在 Enemy.gd:69-71 添加
var delay = randf_range(0.3, 0.8)
print("Smash delay: ", delay, " seconds")
await get_tree().create_timer(delay).timeout
print("After delay - is_moving: ", is_moving)
if is_moving:
    _trigger_enemy_smash()
```

#### 步驟 4: 確認 Smash 執行
```gdscript
# 在 Enemy.gd:135 已有
func _trigger_enemy_smash():
    print("[", unit_name, "] Enemy SMASH triggered!")
    # ... 如果看到這個訊息，表示 Smash 有執行
```

### 快速測試方案

#### 方案 A: 提高觸發率（測試用）
```gdscript
# 在 Enemy.gd:68 改為
if true:  # 必定觸發
    await get_tree().create_timer(0.2).timeout  # 縮短延遲
    if is_moving:
        _trigger_enemy_smash()
```

#### 方案 B: 添加詳細日誌
```gdscript
func _execute_charge():
    print("[", unit_name, "] === CHARGE START ===")
    var target = _find_nearest_player()
    print("  Target: ", target.unit_name if target else "NONE")

    if target:
        var direction = (target.global_position - global_position).normalized()
        var charge_power = 800.0
        print("  Direction: ", direction)
        print("  Power: ", charge_power)
        launch(direction, charge_power)
        print("  Launched! is_moving=", is_moving)

        var rand = randf()
        print("  Smash random: ", rand, " (need > 0.5)")
        if rand > 0.5:
            var delay = randf_range(0.3, 0.8)
            print("  Smash will trigger in ", delay, "s")
            await get_tree().create_timer(delay).timeout
            print("  After delay: is_moving=", is_moving)
            if is_moving:
                _trigger_enemy_smash()
            else:
                print("  SMASH CANCELLED - not moving")
        else:
            print("  Smash not triggered (random check failed)")
    print("[", unit_name, "] === CHARGE END ===")
```

### 預期控制台輸出

#### 正常觸發 Smash
```
[Enemy] === CHARGE START ===
  Target: Player Unit
  Direction: Vector2(0.707, 0.707)
  Power: 800
  Launched! is_moving=true
  Smash random: 0.73 (need > 0.5)
  Smash will trigger in 0.52s
  After delay: is_moving=true
[Enemy] Enemy SMASH triggered!
Enemy Smash hit Player Unit for 120 damage
[Enemy] === CHARGE END ===
```

#### 未觸發（隨機失敗）
```
[Enemy] === CHARGE START ===
  Target: Player Unit
  Launched! is_moving=true
  Smash random: 0.32 (need > 0.5)
  Smash not triggered (random check failed)
[Enemy] === CHARGE END ===
```

#### 未觸發（已停止）
```
[Enemy] === CHARGE START ===
  Target: Player Unit
  Launched! is_moving=true
  Smash random: 0.68 (need > 0.5)
  Smash will trigger in 0.45s
  After delay: is_moving=false
  SMASH CANCELLED - not moving
[Enemy] === CHARGE END ===
```

### 建議修正（如果需要）

如果延遲太長導致觸發率低，可以調整：

```gdscript
# 選項 1: 縮短延遲
await get_tree().create_timer(randf_range(0.1, 0.4)).timeout

# 選項 2: 提高機率
if randf() > 0.3:  # 70% 機率

# 選項 3: 檢查更寬鬆
if is_moving or velocity_magnitude > 100:
    _trigger_enemy_smash()
```

---

## 總結

### 已完成
- ✅ 視覺改為圓形（CircleSprite.gd）
- ✅ Unit.tscn 使用圓形視覺
- ✅ Enemy.tscn 使用圓形視覺
- ✅ 敵人 Smash 程式碼已實作

### 需要測試
- ⚠️ 敵人是否執行 CHARGE 行動
- ⚠️ 隨機判定是否通過（50%）
- ⚠️ 延遲期間敵人是否仍在移動

### 調試建議
1. 添加詳細日誌
2. 暫時改為 100% 觸發
3. 縮短延遲時間
4. 檢查控制台輸出

執行遊戲並查看控制台輸出即可知道問題所在！
