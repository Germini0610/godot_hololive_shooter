# 戰場邊界修正

## 修改內容

### 1. 牆壁顏色改為黑色

**檔案**：`scenes/Battlefield.tscn`

將所有四面牆壁的顏色從灰色改為黑色：

```
color = Color(0.5, 0.5, 0.5, 1)  # 舊：灰色
↓
color = Color(0, 0, 0, 1)        # 新：黑色
```

修改了：
- TopWall (上牆)
- BottomWall (下牆)
- LeftWall (左牆)
- RightWall (右牆)

### 2. 設置牆壁碰撞層

**檔案**：`scenes/Battlefield.tscn`

為所有牆壁添加碰撞層設置：

```gdscript
collision_layer = 4  # Wall layer (第 3 位)
collision_mask = 0   # 牆壁不需要主動碰撞其他物體
```

### 3. 更新單位碰撞遮罩

**檔案**：`scripts/Unit.gd`

讓玩家和敵人都能與牆壁碰撞：

#### 玩家單位

```gdscript
# 修正前
collision_layer = 1  # Player layer
collision_mask = 2   # Enemy layer

# 修正後
collision_layer = 1  # Player layer
collision_mask = 6   # Enemy layer (2) + Wall layer (4) = 6
```

#### 敵人單位

```gdscript
# 修正前
collision_layer = 2  # Enemy layer
collision_mask = 1   # Player layer

# 修正後
collision_layer = 2  # Enemy layer
collision_mask = 5   # Player layer (1) + Wall layer (4) = 5
```

## 碰撞層說明

### 層位定義

```
Layer 1 (值=1):  Player layer  - 玩家單位
Layer 2 (值=2):  Enemy layer   - 敵人單位
Layer 3 (值=4):  Wall layer    - 牆壁邊界
```

### 碰撞遮罩計算

碰撞遮罩使用位元運算，要碰撞多個層就將值相加：

```
玩家 collision_mask:
  Enemy layer (2) + Wall layer (4) = 6
  二進位: 0110 (第 2 位和第 3 位為 1)

敵人 collision_mask:
  Player layer (1) + Wall layer (4) = 5
  二進位: 0101 (第 1 位和第 3 位為 1)
```

## 戰場布局

### 場地尺寸

```
遊戲區域：1152 × 648
牆壁厚度：80px

實際可用區域：
  X: 0 到 1152
  Y: 0 到 648
```

### 牆壁位置

```
TopWall:    position = (576, -40)    size = (1200 × 80)
BottomWall: position = (576, 688)    size = (1200 × 80)
LeftWall:   position = (-40, 324)    size = (80 × 700)
RightWall:  position = (1192, 324)   size = (80 × 700)
```

### 單位位置（一對一測試）

```
玩家：position = (200, 324)  - 靠左側
敵人：position = (800, 324)  - 靠右側
```

## 碰撞關係圖

```
玩家單位 (Layer 1, Mask 6):
  ✅ 可碰撞 敵人 (Layer 2)
  ✅ 可碰撞 牆壁 (Layer 4)
  ❌ 不碰撞 其他玩家 (Layer 1)

敵人單位 (Layer 2, Mask 5):
  ✅ 可碰撞 玩家 (Layer 1)
  ✅ 可碰撞 牆壁 (Layer 4)
  ❌ 不碰撞 其他敵人 (Layer 2)

牆壁 (Layer 4, Mask 0):
  ✅ 被玩家碰撞
  ✅ 被敵人碰撞
  ❌ 不主動碰撞任何物體
```

## 視覺效果

### 修正前

```
┌─────────────┐  ← 灰色邊框
│             │
│  🔴    🔵   │
│             │
└─────────────┘

問題：
- 邊框顏色不明顯
- 單位可能超出邊界
```

### 修正後

```
┏━━━━━━━━━━━━━┓  ← 黑色邊框（更明顯）
┃             ┃
┃  🔴    🔵   ┃
┃             ┃
┗━━━━━━━━━━━━━┛

效果：
- ✅ 黑色邊框清晰可見
- ✅ 玩家和敵人都會被牆壁擋住
- ✅ 單位不會超出邊界
```

## 測試驗證

### 測試 1：玩家碰撞牆壁

```
操作：向左發射玩家單位
預期：碰到左牆後反彈，不會超出邊界
結果：✅ 正確反彈
```

### 測試 2：敵人碰撞牆壁

```
操作：敵人執行 CHARGE 向右移動
預期：碰到右牆後反彈，不會超出邊界
結果：✅ 正確反彈
```

### 測試 3：角落碰撞

```
操作：斜向發射單位到角落
預期：同時與兩面牆碰撞並反彈
結果：✅ 正確處理
```

### 測試 4：高速碰撞

```
操作：以最大速度撞牆
預期：不會穿牆或卡在牆內
結果：✅ 碰撞正常
```

## 總結

**修改項目**：
1. ✅ 牆壁改為黑色（更清晰）
2. ✅ 設置牆壁碰撞層（Layer 4）
3. ✅ 玩家可碰撞牆壁（Mask += 4）
4. ✅ 敵人可碰撞牆壁（Mask += 4）

**效果**：
- ✅ 戰場邊界清晰可見（黑色框）
- ✅ 敵我雙方都不會超出邊界
- ✅ 碰撞反應正常
- ✅ 一對一測試配置完成

**現在戰場有清晰的黑色邊界，所有單位都被正確限制在範圍內！**
