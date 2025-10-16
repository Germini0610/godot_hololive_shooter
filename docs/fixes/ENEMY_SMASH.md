# 敵人 Smash 系統

## 功能說明

敵人現在也可以在移動中觸發 Smash 攻擊，與玩家相同的機制。

## 實作細節

### 觸發時機

```gdscript
## 衝撞行動中隨機觸發
func _execute_charge():
    # 發射敵人
    launch(direction, charge_power)

    # 50% 機率觸發 Smash
    if randf() > 0.5:
        # 延遲 0.3-0.8 秒後觸發
        await get_tree().create_timer(randf_range(0.3, 0.8)).timeout
        if is_moving:
            _trigger_enemy_smash()
```

**設計考量**：
- **隨機性**：50% 機率，增加不可預測性
- **延遲觸發**：0.3-0.8 秒後，模擬移動中途觸發
- **狀態檢查**：確保敵人仍在移動中才觸發

### Smash 實作

```gdscript
func _trigger_enemy_smash():
    # 1. 記錄玩家位置（防止被推動）
    var player_positions = {}
    for player in all_players:
        player_positions[player] = player.global_position

    # 2. 禁用敵人碰撞
    collision_mask = 0

    # 3. 範圍檢測（半徑 150px）
    var nearby_players = _get_nearby_players(150.0)

    # 4. 對每個玩家造成傷害
    for player in nearby_players:
        damage = atk × 1.5 × attr_multiplier
        player.take_damage(damage)
        顯示傷害浮字 ✅

    # 5. 停止敵人移動
    stop_movement()

    # 6. 恢復碰撞
    collision_mask = original_value

    # 7. 強制恢復玩家位置
    await process_frame
    for player in player_positions:
        player.global_position = original_pos
        player.linear_velocity = Vector2.ZERO
```

### 距離檢測修正

同時修正了 `_get_nearby_players()` 使用純距離計算：

```gdscript
# ❌ 修正前：使用物理查詢
func _get_nearby_players(radius: float) -> Array:
    var query = PhysicsShapeQueryParameters2D.new()
    var shape = CircleShape2D.new()
    # ... 會產生物理交互

# ✅ 修正後：純距離計算
func _get_nearby_players(radius: float) -> Array:
    var players = []
    for player in get_tree().get_nodes_in_group("player"):
        if global_position.distance_to(player.global_position) <= radius:
            players.append(player)
    return players
```

## 行為流程

### 正常衝撞（無 Smash）
```
敵人行動倒數歸零
    ↓
執行 CHARGE 行動
    ↓
發射敵人朝向玩家
    ↓
隨機判定：不觸發 Smash (50%)
    ↓
正常碰撞玩家
    ↓
停止移動
```

### 衝撞 + Smash
```
敵人行動倒數歸零
    ↓
執行 CHARGE 行動
    ↓
發射敵人朝向玩家
    ↓
隨機判定：觸發 Smash (50%)
    ↓
延遲 0.3-0.8 秒
    ↓
檢查：敵人仍在移動？
    ├─ 是 → 觸發 Smash
    │    ↓
    │  範圍 AoE 傷害（半徑 150px）
    │    ↓
    │  對範圍內玩家：
    │    - 造成 1.5 倍傷害
    │    - 顯示傷害浮字 ✅
    │    - 玩家位置不變
    │    ↓
    │  立即停止移動
    │
    └─ 否 → 不觸發（已停止）
```

## 與玩家 Smash 的對比

| 項目 | 玩家 Smash | 敵人 Smash |
|------|-----------|-----------|
| 觸發方式 | 手動點擊 | 隨機自動 (50%) |
| 觸發時機 | 移動中點擊 | 延遲 0.3-0.8 秒 |
| 範圍 | 150 像素 | 150 像素 |
| 傷害倍率 | 1.5× | 1.5× |
| 目標 | 敵人 | 玩家 |
| 位置保護 | 敵人不移動 | 玩家不移動 |
| 傷害浮字 | ✅ 有 | ✅ 有 |

## AI 策略

### 何時觸發？
```
敵人執行 CHARGE：
├─ 50% 機率：觸發 Smash
│   ├─ 優勢：範圍傷害更高
│   └─ 劣勢：提前停止移動
│
└─ 50% 機率：不觸發
    ├─ 優勢：移動更遠，接近目標
    └─ 劣勢：只有碰撞傷害
```

### 戰術意義
- **壓制**：突然的 AoE 打亂玩家佈局
- **不可預測**：50% 隨機性增加變化
- **風險平衡**：提前停止 vs 範圍傷害

## 測試場景

### 場景 1: 敵人衝撞但不 Smash
```
敵人倒數歸零
    ↓
向玩家衝撞
    ↓
隨機判定：不觸發 (50%)
    ↓
正常碰撞玩家
    ↓
結果：
✅ 碰撞傷害
✅ 移動距離最遠
```

### 場景 2: 敵人衝撞並觸發 Smash
```
敵人倒數歸零
    ↓
向玩家衝撞
    ↓
隨機判定：觸發 (50%)
    ↓
延遲約 0.5 秒
    ↓
觸發 Smash
    ↓
結果：
✅ 範圍內玩家受到 1.5× 傷害
✅ 顯示黃色傷害浮字
✅ 玩家位置不變
✅ 敵人立即停止
```

### 場景 3: Smash 範圍攻擊多個玩家
```
    🔴 玩家1
  🔵 敵人衝撞
    🔴 玩家2
       ↓
    Smash 觸發
       ↓
結果：
✅ 兩個玩家都受傷
✅ 兩個傷害浮字
✅ 兩個玩家位置不變
```

### 場景 4: 延遲期間敵人被停止
```
敵人衝撞
    ↓
隨機判定：觸發 Smash
    ↓
延遲 0.3-0.8 秒期間...
玩家攻擊敵人 → 敵人停止移動
    ↓
延遲結束，檢查 is_moving
    ↓
is_moving = false
    ↓
不觸發 Smash ✅ (正確)
```

## 調整參數

### 修改觸發機率
```gdscript
# 當前：50%
if randf() > 0.5:

# 更高機率（75%）
if randf() > 0.25:

# 更低機率（25%）
if randf() > 0.75:

# 必定觸發（100%）
if true:
```

### 修改延遲時間
```gdscript
# 當前：0.3-0.8 秒
await get_tree().create_timer(randf_range(0.3, 0.8)).timeout

# 更早觸發（0.1-0.4 秒）
await get_tree().create_timer(randf_range(0.1, 0.4)).timeout

# 更晚觸發（0.5-1.2 秒）
await get_tree().create_timer(randf_range(0.5, 1.2)).timeout
```

### 修改範圍和傷害
```gdscript
# 當前
var smash_radius = 150.0
var smash_multiplier = 1.5

# 更大範圍，更高傷害
var smash_radius = 200.0
var smash_multiplier = 2.0

# 更小範圍，更低傷害
var smash_radius = 100.0
var smash_multiplier = 1.2
```

## 控制台輸出

### Smash 觸發
```
[Enemy] Executing CHARGE action
[Enemy] Enemy SMASH triggered!
Enemy Smash hit Player Unit for 120 damage
```

### Smash 未觸發
```
[Enemy] Executing CHARGE action
(無 Smash 訊息)
```

## 效能考量

### 每次 CHARGE 的成本
```
基礎移動：
- launch() 一次物理計算
- 碰撞檢測

額外 Smash 成本（50% 機率）：
- 1 個計時器 (await timer)
- 1 次距離檢測循環 (O(n))
- n 次傷害計算
- n 個傷害浮字生成
- 1 次位置恢復

n = 玩家數量（通常 1-5）
總成本：可忽略 ✓
```

## 平衡建議

### 如果敵人太強
- 降低觸發機率（50% → 30%）
- 減少傷害倍率（1.5× → 1.2×）
- 縮小範圍（150 → 100）

### 如果敵人太弱
- 提高觸發機率（50% → 70%）
- 增加傷害倍率（1.5× → 2.0×）
- 擴大範圍（150 → 200）

## 總結

### 新增功能
- ✅ 敵人可在衝撞中觸發 Smash
- ✅ 50% 隨機機率，延遲觸發
- ✅ 與玩家 Smash 相同機制
- ✅ 完整的位置保護
- ✅ 顯示傷害浮字
- ✅ 修正距離檢測（無物理交互）

### 遊戲體驗
- ✅ 增加敵人威脅性
- ✅ 提高戰鬥變化性
- ✅ 不可預測的戰術
- ✅ 雙方機制對等

**敵人現在也能使用 Smash 了！** ⚔️
