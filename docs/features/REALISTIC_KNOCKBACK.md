# 真實擊退物理系統

## 修改目標

讓敵人被撞擊時會真實地移動，移動距離和速度會根據碰撞源的速度來模擬，更加擬真。

## 問題分析

### 修改前的狀況
```gdscript
# 記錄敵人碰撞前的位置和速度
var enemy_position = enemy.global_position
var enemy_velocity = enemy.linear_velocity

# ... 造成傷害 ...

# 恢復敵人位置和速度（防止被碰撞回彈）
await get_tree().process_frame
enemy.global_position = enemy_position
enemy.linear_velocity = enemy_velocity
```

**問題**：
- 敵人被撞後立即恢復原位
- 沒有真實的物理反應
- 缺乏動態感和衝擊感
- 不符合真實世界的碰撞物理

## 主要修改

### 1. 移除位置/速度恢復邏輯

**修改前**：
```gdscript
# 恢復敵人位置和速度（防止被碰撞回彈）
await get_tree().process_frame
if is_instance_valid(enemy) and not enemy.skip_collision_restore:
    enemy.global_position = enemy_position
    enemy.linear_velocity = enemy_velocity
    enemy.angular_velocity = enemy_angular
```

**修改後**：
```gdscript
# 應用擊退效果（讓敵人被推動）
_apply_knockback(enemy, speed_scale)
```

**效果**：
- ✅ 敵人不再恢復原位
- ✅ 允許真實的物理反應
- ✅ 敵人會被推動並滑行

### 2. 添加擊退物理系統

新增 `_apply_knockback()` 函數，根據攻擊者速度計算擊退效果：

```gdscript
func _apply_knockback(target, speed_scale: float):
    if not is_instance_valid(target):
        return

    # 計算擊退方向（從攻擊者指向目標）
    var knockback_direction = (target.global_position - global_position).normalized()

    # 計算擊退力度（基於攻擊者的速度）
    # 擊退力度與攻擊者速度成正比，範圍：300 ~ 1500
    var knockback_power = lerp(300.0, 1500.0, speed_scale)

    # 應用擊退速度
    var knockback_velocity = knockback_direction * knockback_power
    target.linear_velocity = knockback_velocity

    # 設置目標為移動狀態（讓它可以繼續滑行）
    target.is_moving = true
    target.collision_enabled = true
```

**特性**：
- **方向計算**：從攻擊者指向被擊者
- **力度計算**：基於攻擊者速度（speed_scale: 0.0 ~ 1.0）
- **力度範圍**：300 ~ 1500（擬真的推動效果）
- **狀態設定**：被擊者進入移動狀態，可以繼續滑行

### 3. 擊退力度計算公式

```gdscript
knockback_power = lerp(300.0, 1500.0, speed_scale)
```

**示例**：
```
攻擊者速度   速度倍率    擊退力度
────────────────────────────────
500          0.20       360
1000         0.40       660
1500         0.60       960
2000         0.80       1260
2500 (max)   1.00       1500
```

**特點**：
- 低速碰撞：小幅推動（300）
- 中速碰撞：中等推動（~900）
- 高速碰撞：大幅推動（1500）

### 4. 敵人之間碰撞

**新增功能**：敵人之間也可以互相碰撞和推動

#### 碰撞層設定修改

**修改前**：
```gdscript
collision_layer = 2  # Enemy layer
collision_mask = 5   # Player (1) + Wall (4) = 5
# 敵人不會和其他敵人碰撞
```

**修改後**：
```gdscript
collision_layer = 2  # Enemy layer
collision_mask = 7   # Player (1) + Enemy (2) + Wall (4) = 7
# 敵人現在會和其他敵人碰撞
```

#### 敵人間碰撞處理

```gdscript
func _handle_enemy_to_enemy_collision(other_enemy):
    # 敵人之間碰撞只產生物理推動效果，不造成傷害
    if is_instance_valid(other_enemy):
        # 確保被撞的敵人也處於移動狀態
        if other_enemy.linear_velocity.length() < 100.0:
            # 如果對方速度很低，給予一個小的推動
            var push_direction = (other_enemy.global_position - global_position).normalized()
            var push_power = velocity_magnitude * 0.3  # 傳遞 30% 的速度
            other_enemy.linear_velocity = push_direction * push_power
            other_enemy.is_moving = true
            other_enemy.collision_enabled = true
```

**特性**：
- 敵人之間不造成傷害
- 只產生物理推動效果
- 傳遞 30% 的速度
- 讓敵人可以互相推擠

## 物理行為對比

### 修改前（靜態）
```
玩家 ━━━━━> 💥 敵人
             ↓
          敵人恢復原位（靜止不動）

問題：
- 敵人像固定在地上
- 沒有衝擊感
- 不真實
```

### 修改後（動態）
```
玩家 ━━━━━> 💥 敵人 ━━━━━>
                        ↓
                   敵人被推動並滑行

優點：
- 真實的物理反應
- 有衝擊感
- 敵人會移動和滑行
- 可以撞到其他敵人（連鎖反應）
```

## 連鎖反應示例

### 保齡球效果
```
玩家高速撞擊敵人 1：

玩家 ━━━> 敵1 💥 ━━━> 敵2 💥 ━━━> 敵3
           ↓            ↓            ↓
         被推動       被推動       被推動

結果：
- 敵1 受到傷害並被推動（力度：1500）
- 敵1 撞到敵2，敵2 被推動（力度：~450）
- 敵2 撞到敵3，敵3 被推動（力度：~135）
- 形成連鎖推動效果！
```

### 群體控制
```
玩家撞擊敵群中央：

      敵2
       ↑
敵1 ← 玩家 → 敵3
       ↓
      敵4

結果：
- 中心敵人被推開
- 所有周圍敵人都被推散
- 創造空間和戰術機會
```

## 擊退距離計算

### 基本公式
```
擊退距離 = 初始速度 × 時間 × 阻尼因子

其中：
- 初始速度 = knockback_power (300 ~ 1500)
- 阻尼 = linear_damp (0.5)
- 停止閾值 = 200
```

### 預估距離

**低速擊退（300）**：
```
初始速度: 300
時間: ~1.0 秒
預估距離: ~150 px
```

**中速擊退（900）**：
```
初始速度: 900
時間: ~1.5 秒
預估距離: ~500 px
```

**高速擊退（1500）**：
```
初始速度: 1500
時間: ~1.8 秒
預估距離: ~900 px
```

## 視覺效果

### 軌跡顯示
被擊退的敵人如果速度 > 500，也會顯示軌跡：
```
玩家 ━━━> 💥 敵人 ━━━━━>
     紅色軌跡    藍色軌跡

效果：
- 可以清楚看到敵人被推動
- 軌跡顏色對應敵人屬性
- 速度感更強
```

## 戰術影響

### 1. 位置控制
```
策略：將敵人推向牆角
效果：限制敵人移動空間
```

### 2. 群體分散
```
策略：撞擊敵群中心
效果：分散敵人，各個擊破
```

### 3. 連鎖打擊
```
策略：高速撞擊排成一列的敵人
效果：保齡球式連鎖推動
```

### 4. 地形利用
```
策略：將敵人推向牆壁反彈
效果：創造額外碰撞機會
```

## Debug 訊息

### 擊退訊息
```
[Knockback] Player Unit knocked back Blue Slime with power 1200 (speed scale: 0.80)
```

### 敵人間碰撞訊息
```
[Enemy Collision] Red Dragon pushed Green Goblin
```

## 修改的檔案

**scripts/Unit.gd**
1. 移除 `_handle_enemy_collision()` 中的位置恢復邏輯
2. 移除 `_handle_player_collision()` 中的位置恢復邏輯
3. 新增 `_apply_knockback()` 函數
4. 新增 `_handle_enemy_to_enemy_collision()` 函數
5. 修改 `collision_mask` 設定（敵人可以碰撞敵人）
6. 修改 `_on_body_entered()` 添加敵人間碰撞處理

## 與其他系統的配合

### 1. 快速停止系統
```
STOP_VELOCITY_THRESHOLD = 200.0

效果：
- 被擊退的敵人速度降到 200 時停止
- 不會無限滑行
- 保持遊戲節奏
```

### 2. 軌跡效果
```
被擊退速度 > 500 時顯示軌跡

效果：
- 視覺化擊退效果
- 增加動態感
```

### 3. 傷害計算
```
傷害和擊退同時發生

效果：
- 造成傷害的同時推動敵人
- 高速 = 高傷害 + 高擊退
- 低速 = 低傷害 + 低擊退
```

### 4. 屬性相剋
```
擊退力度不受屬性影響

說明：
- 物理推動效果一致
- 只有傷害受屬性影響
- 保持物理系統的一致性
```

## 測試建議

### 測試 1：基本擊退
1. 以不同速度撞擊敵人
2. 預期：
   - 低速：小幅推動（~150px）
   - 中速：中等推動（~500px）
   - 高速：大幅推動（~900px）

### 測試 2：敵人之間碰撞
1. 推動敵人撞向其他敵人
2. 預期：
   - 兩個敵人都會移動
   - 形成連鎖推動效果
   - 不造成傷害

### 測試 3：牆壁反彈
1. 將敵人推向牆壁
2. 預期：
   - 敵人撞牆後反彈
   - 反彈方向正確
   - bounce = 1.0 完美反彈

### 測試 4：軌跡顯示
1. 高速撞擊敵人
2. 預期：
   - 敵人顯示對應顏色的軌跡
   - 軌跡隨速度降低而消失

### 測試 5：保齡球效果
1. 撞擊排成一列的敵人
2. 預期：
   - 第一個敵人被推動
   - 撞到第二個敵人
   - 形成連鎖反應

## 物理參數總覽

```gdscript
# 擊退系統
MIN_KNOCKBACK: 300.0     # 最小擊退力度
MAX_KNOCKBACK: 1500.0    # 最大擊退力度

# 物理參數
linear_damp: 0.5         # 阻尼（減速）
bounce: 1.0              # 反彈係數（完美反彈）
friction: 0.0            # 摩擦力（無摩擦）

# 停止參數
STOP_VELOCITY_THRESHOLD: 200.0  # 停止閾值

# 敵人間碰撞
ENEMY_PUSH_RATIO: 0.3    # 速度傳遞比例（30%）
```

## 調整建議

### 如果擊退太遠
```gdscript
# 降低最大擊退力度
var knockback_power = lerp(300.0, 1000.0, speed_scale)  # 原本 1500
```

### 如果擊退太近
```gdscript
# 提高最大擊退力度
var knockback_power = lerp(500.0, 2000.0, speed_scale)  # 原本 1500
```

### 如果滑行太久
```gdscript
# 增加阻尼
linear_damp = 0.7  # 原本 0.5
```

### 如果敵人間推動太弱
```gdscript
# 提高速度傳遞比例
var push_power = velocity_magnitude * 0.5  # 原本 0.3 (30% → 50%)
```

## 總結

**修改效果**：
- ✅ 移除位置恢復邏輯
- ✅ 敵人被撞時會真實移動
- ✅ 擊退力度基於攻擊者速度（300 ~ 1500）
- ✅ 敵人之間可以互相碰撞和推動
- ✅ 形成連鎖反應（保齡球效果）
- ✅ 增加戰術深度（位置控制）
- ✅ 視覺效果更動態（軌跡顯示）
- ✅ 物理反應更真實

**物理特性**：
```
高速撞擊 → 大力推動 → 長距離滑行
中速撞擊 → 中等推動 → 中等距離
低速碰撞 → 小幅推動 → 短距離

敵人 A → 敵人 B → 敵人 C
    ↓        ↓        ↓
  推動    連鎖    連鎖
```

**現在敵人被撞擊時會像真實的物體一樣被推動和滑行！**
