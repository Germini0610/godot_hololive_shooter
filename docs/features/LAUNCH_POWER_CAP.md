# 射擊力道上限修改

## 修改目標

讓射擊操作更簡單直觀：
- **拉動到一定距離後，自動使用最大 power**
- **提供清晰的視覺反饋**，讓玩家知道何時達到最大 power

## 主要修改

### 1. 添加力道閾值

新增常數 `MAX_POWER_THRESHOLD`，當拖曳距離超過此值時，自動使用最大 power。

```gdscript
const MAX_POWER_THRESHOLD: float = 200.0  # 拖曳超過此距離就使用最大 power
```

**效果**：
- 拖曳距離 < 200px：power 根據距離計算（300 ~ 2500）
- 拖曳距離 ≥ 200px：power = 2500（最大值）

### 2. 修改力道計算邏輯

#### 原邏輯
```gdscript
var power = direction.length() * POWER_SCALE
power = clamp(power, MIN_LAUNCH_POWER, MAX_LAUNCH_POWER)
```

#### 新邏輯
```gdscript
var drag_distance = direction.length()

if drag_distance >= MAX_POWER_THRESHOLD:
    power = MAX_LAUNCH_POWER  # 直接使用最大值
else:
    power = drag_distance * POWER_SCALE
    power = clamp(power, MIN_LAUNCH_POWER, MAX_LAUNCH_POWER)
```

**優點**：
- ✅ 玩家不需要拉很遠就能達到最大 power
- ✅ 操作更簡單，只需拉到閾值即可
- ✅ 避免手滑拉過頭

### 3. 視覺反饋增強

當拖曳距離達到閾值時，提供明顯的視覺反饋：

#### 普通狀態（< 200px）
- 線條顏色：**黃色**
- 圓圈顏色：**紅色**
- 線條寬度：**3.0**

#### 最大 Power 狀態（≥ 200px）
- 線條顏色：**橙紅色**（ORANGE_RED）
- 圓圈顏色：**橙紅色**
- 線條寬度：**5.0**（更粗）
- **脈衝效果**：圓圈周圍有呼吸動畫

```gdscript
if drag_distance >= MAX_POWER_THRESHOLD:
    line_color = Color.ORANGE_RED
    circle_color = Color.ORANGE_RED
    line_width = 5.0

    # 脈衝效果
    var pulse = abs(sin(Time.get_ticks_msec() * 0.01))
    draw_circle(arrow_end, 10.0 + pulse * 5.0, Color(1.0, 0.3, 0.0, 0.3 + pulse * 0.3))
```

### 4. Debug 訊息優化

發射時會顯示不同的訊息：

#### 最大 Power 時
```
[BattleController] MAX POWER! Launching unit with power: 2500
```

#### 普通 Power 時
```
[BattleController] Launching unit with power: 1500 (60%)
```

## 參數說明

### 拖曳距離與 Power 的關係

```
拖曳距離 (px)  →  Power 值  →  說明
─────────────────────────────────────────
0              →  不發射      →  太短
10             →  300         →  最小值（MIN_LAUNCH_POWER）
80             →  300         →  尚未達到 MIN_LAUNCH_POWER
120            →  300         →  MIN_LAUNCH_POWER
160            →  400         →  distance * 2.5
200            →  2500        →  達到閾值，最大 power！
250            →  2500        →  最大 power
300            →  2500        →  最大 power
任意大於 200   →  2500        →  最大 power
```

### 力道計算公式

#### 距離 < 200px
```
power = clamp(distance * 2.5, 300, 2500)
```

#### 距離 ≥ 200px
```
power = 2500（固定最大值）
```

## 視覺效果對比

### 拖曳 100px（普通狀態）
```
單位 ━━━━━━━━━━━> ⚫
     黃色線條      紅色圓圈
     (3.0 寬度)
```

### 拖曳 200px+（最大 Power）
```
單位 ━━━━━━━━━━━> ⚪
     橙紅色線條    ⚫  橙紅色圓圈
     (5.0 寬度)    ⚪ 脈衝效果
                   ⚪
```

**脈衝效果**：
- 圓圈由內向外呼吸
- 半徑：10px ~ 15px
- 透明度：0.3 ~ 0.6
- 頻率：約每秒 1 次

## 修改的檔案

**scripts/BattleController.gd**
1. 新增 `MAX_POWER_THRESHOLD` 常數
2. 修改 `_handle_input()` 中的力道計算邏輯
3. 修改 `_launch_unit()` 中的發射邏輯
4. 增強 `_draw()` 中的視覺反饋

## 使用體驗

### 修改前
```
玩家需要拉動很遠（約 1000px）才能達到最大 power
- 難以精確控制
- 容易拉過頭
- 操作不直觀
```

### 修改後
```
玩家只需拉動 200px 就能達到最大 power
- ✅ 操作簡單
- ✅ 有明確的視覺反饋（橙紅色 + 脈衝）
- ✅ 容易達到最大 power
- ✅ 不會拉過頭
```

## 測試建議

### 測試 1：閾值測試
1. 拖曳 < 200px
   - 預期：黃色線條，紅色圓圈
   - 預期：Power < 2500
2. 拖曳 = 200px
   - 預期：線條變為橙紅色
   - 預期：出現脈衝效果
   - 預期：Power = 2500
3. 拖曳 > 200px
   - 預期：保持橙紅色和脈衝效果
   - 預期：Power = 2500

### 測試 2：視覺反饋測試
1. 慢慢拖曳到 200px
   - 預期：在達到 200px 時，瞬間變色
   - 預期：脈衝效果開始
2. 觀察脈衝效果
   - 預期：圓圈持續呼吸
   - 預期：動畫流暢

### 測試 3：發射測試
1. 以不同距離發射
   - 預期：< 200px 時顯示百分比
   - 預期：≥ 200px 時顯示 "MAX POWER!"
2. 觀察單位移動
   - 預期：≥ 200px 時速度始終最快

## 微調參數

如果覺得閾值不合適，可以調整：

### 更容易達到最大 Power
```gdscript
const MAX_POWER_THRESHOLD: float = 150.0  # 只需拉 150px
```

### 更難達到最大 Power
```gdscript
const MAX_POWER_THRESHOLD: float = 300.0  # 需要拉 300px
```

### 建議值
```
150px  - 非常容易達到（適合休閒玩家）
200px  - 容易達到（當前設定，推薦）
250px  - 中等難度
300px  - 較難達到（適合進階玩家）
```

## 與其他系統的配合

### 速度感增強
- 最大 power (2500) 配合低阻尼 (0.3)
- 單位會飛得非常遠
- 軌跡效果明顯

### 傷害計算
- 最大 power 時，速度倍率最高
- 傷害 = atk × (velocity / MAX_SPEED) × 屬性倍率
- 達到最大 power 時傷害最高

## 總結

**修改效果**：
- ✅ 拖曳超過 200px 自動使用最大 power
- ✅ 橙紅色線條 + 脈衝效果提供清晰反饋
- ✅ 操作更簡單直觀
- ✅ 玩家不需要拉很遠
- ✅ Debug 訊息顯示 power 狀態

**現在只需拉動 200px，就能輕鬆達到最大 power！**
