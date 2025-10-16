# 物理系統修正記錄

## 修正 #1: 減少摩擦力 ✅

### 問題
- 單位減速太快，滑動距離不夠遠
- 影響遊戲體驗和彈射感

### 解決方案
降低 `linear_damp` 從 0.5 → 0.2

### 修改檔案
1. **scenes/Unit.tscn:10**
2. **scenes/Enemy.tscn:10**
3. **project.godot:36**

### 效果
```
修正前: linear_damp = 0.5  （減速較快）
修正後: linear_damp = 0.2  （滑得更遠）
```

- ✅ 單位滑動距離增加 2.5 倍
- ✅ 更符合彈珠台的滑順感
- ✅ 保持適度減速，不會無限滑動

---

## 修正 #2: Smash 拉扯問題 ✅

### 問題
❌ **Smash 應該只造成範圍傷害，但卻會把敵人拉向自己**

### 原因分析

#### 錯誤的實作方式：
```gdscript
# ❌ 使用物理查詢 - 會產生物理交互作用
func _get_nearby_enemies(radius: float) -> Array:
    var space_state = get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var shape = CircleShape2D.new()  # 創建實體圓形
    shape.radius = radius
    query.shape = shape
    query.transform = global_transform  # 在單位位置

    var results = space_state.intersect_shape(query)
    # ⚠️ intersect_shape 會創建真實的物理形狀
    # 導致與敵人產生碰撞和推力！
```

**為什麼會拉扯？**
1. `PhysicsShapeQueryParameters2D` 在場景中創建實際的物理形狀
2. 圓形單位 + 圓形查詢範圍 = 兩個圓重疊
3. Godot 物理引擎自動處理重疊 → 產生分離力
4. 因為查詢圓心在玩家位置 → 敵人被推開/拉近

### 正確的解決方案

#### 使用純數學距離檢測：
```gdscript
# ✅ 純距離計算 - 不產生物理交互
func _get_nearby_enemies(radius: float) -> Array:
    var enemies = []
    var target_group = "enemy" if is_player_unit else "player"
    var all_targets = get_tree().get_nodes_in_group(target_group)

    for target in all_targets:
        if target != self and is_instance_valid(target):
            # 純數學計算距離
            var distance = global_position.distance_to(target.global_position)
            if distance <= radius:
                enemies.append(target)

    return enemies
```

**為什麼這樣正確？**
- ✅ 只使用數學計算（distance_to）
- ✅ 不創建物理形狀
- ✅ 不觸發物理引擎
- ✅ 純粹的範圍檢測

### 修改檔案
**scripts/Unit.gd:239-251** - 重寫 `_get_nearby_enemies()` 函數

### 測試
```
場景設定：
┌─────────────────┐
│  🔴 玩家        │
│     ↓ 移動中    │
│     🔵 敵人     │  距離 100 像素
│  🔵 敵人        │  距離 80 像素
└─────────────────┘

點擊觸發 Smash (半徑 150):

❌ 修正前：
- 敵人被拉向玩家
- 物理形狀重疊產生推力
- 敵人位置改變

✅ 修正後：
- 敵人位置不變
- 只受到範圍傷害
- 沒有任何物理作用力
```

---

## 物理查詢對比

### intersect_shape (會產生物理交互)
```gdscript
# ⚠️ 用於：需要物理反饋的場景
# 例如：觸發器、碰撞檢測、力場

var query = PhysicsShapeQueryParameters2D.new()
var shape = CircleShape2D.new()
query.shape = shape
var results = space_state.intersect_shape(query)

問題：
- 創建實際物理形狀
- 與其他物體產生碰撞
- 觸發物理引擎計算
- 可能產生推力/拉力
```

### distance_to (純數學計算)
```gdscript
# ✅ 用於：純邏輯檢測
# 例如：範圍傷害、AI 偵測、技能範圍

var distance = pos1.distance_to(pos2)
if distance <= radius:
    # 在範圍內

優點：
- 純數學計算
- 沒有物理交互
- 效能更好
- 結果可預測
```

---

## 效能對比

| 方法 | CPU 負擔 | 產生物理作用 | 適用場景 |
|------|----------|--------------|----------|
| `intersect_shape` | 高 | ✅ 是 | 物理觸發器、碰撞檢測 |
| `distance_to` | 低 | ❌ 否 | 範圍傷害、距離判定 |

**Smash 使用場景：**
- 目的：範圍傷害檢測
- 需求：找出範圍內敵人
- 不需要：物理推力或碰撞
- ✅ **選擇：distance_to**

---

## 其他受影響的系統

### BattleController._get_nearby_enemies()
```gdscript
# ✅ 已經使用正確方法
func _get_nearby_enemies(pos: Vector2, radius: float) -> Array:
    var enemies = get_tree().get_nodes_in_group("enemy")
    var nearby = []
    for enemy in enemies:
        if enemy.global_position.distance_to(pos) <= radius:
            nearby.append(enemy)
    return nearby
```

### Unit._execute_command_skill()
```gdscript
# ✅ 現在使用修正後的 _get_nearby_enemies()
func _execute_command_skill():
    var nearby_enemies = _get_nearby_enemies(200.0)
    for enemy in nearby_enemies:
        enemy.take_damage(skill_damage, false)
```

---

## 測試確認清單

### Smash 功能
- ✅ 點擊觸發範圍攻擊
- ✅ 造成 1.5 倍傷害
- ✅ 敵人位置不變（無拉扯）
- ✅ 立即停止移動

### Command Skill
- ✅ 消耗技能量表
- ✅ 範圍傷害正常
- ✅ 沒有物理推力

### 物理表現
- ✅ 單位滑動更遠（linear_damp = 0.2）
- ✅ 碰撞正常反彈
- ✅ 無異常拉扯或推動

---

## 技術要點總結

### 何時使用 distance_to
- ✅ 範圍傷害檢測
- ✅ AI 視野範圍
- ✅ 觸發距離判定
- ✅ 任何不需要物理反饋的場景

### 何時使用 intersect_shape
- ✅ 需要實際碰撞的觸發器
- ✅ 需要物理推力的力場
- ✅ 需要檢測重疊的區域
- ⚠️ 明確需要物理交互時

### 最佳實踐
```gdscript
# ✅ 推薦：範圍攻擊用距離
func get_targets_in_range(radius: float) -> Array:
    var targets = []
    for unit in get_tree().get_nodes_in_group("units"):
        if global_position.distance_to(unit.global_position) <= radius:
            targets.append(unit)
    return targets

# ❌ 避免：範圍攻擊用物理查詢
func get_targets_in_range(radius: float) -> Array:
    var query = PhysicsShapeQueryParameters2D.new()
    # 會產生不必要的物理交互
```

---

## 修正總結

| 項目 | 修正前 | 修正後 |
|------|--------|--------|
| 摩擦力 | 0.5 (太快) | 0.2 (滑順) |
| Smash 實作 | 物理查詢 | 距離計算 |
| 敵人拉扯 | ❌ 有 | ✅ 無 |
| 物理交互 | ❌ 產生 | ✅ 不產生 |

所有問題已解決！現在可以正常使用 Smash 功能了！🎯
