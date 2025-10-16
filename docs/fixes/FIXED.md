# 重力問題修正說明

## 問題描述
原本的設定錯誤地使用了預設重力，導致：
- ❌ 玩家角色和敵人會掉出畫面
- ❌ 不符合俯視角 2D 彈珠台遊戲設計

## 遊戲類型確認
這是一個**俯視角 2D 彈珠台**遊戲：
- ✅ 視角：由正上方往下看
- ✅ 移動：在平面上滑動，像彈珠台
- ✅ 物理：只需要平面碰撞，**不需要重力**

## 修正內容

### 1. Unit.gd (scripts/Unit.gd:44-45)
```gdscript
func _ready():
    # ...
    # 關閉重力（俯視角 2D 彈珠台遊戲）
    gravity_scale = 0.0
    # ...
```

### 2. Unit.tscn (scenes/Unit.tscn:9-11)
```
[node name="Unit" type="RigidBody2D" groups=["player"]]
gravity_scale = 0.0
linear_damp = 0.5      # 線性阻尼（減速）
angular_damp = 2.0     # 角度阻尼（減少旋轉）
```

### 3. Enemy.tscn (scenes/Enemy.tscn:9-11)
```
[node name="Enemy" type="RigidBody2D" groups=["enemy"]]
gravity_scale = 0.0
linear_damp = 0.5
angular_damp = 2.0
```

### 4. project.godot (全域物理設定)
```ini
[physics]

2d/default_gravity=0.0
2d/default_gravity_vector=Vector2(0, 0)
2d/default_linear_damp=0.5
2d/default_angular_damp=2.0
```

## 新增的物理參數

### linear_damp = 0.5
- **作用**: 線性阻尼，模擬摩擦力
- **效果**: 單位會逐漸減速並停止
- **值越大**: 減速越快
- **0.5**: 適中的減速效果，像彈珠台的桌面摩擦

### angular_damp = 2.0
- **作用**: 角度阻尼，減少旋轉
- **效果**: 防止單位不斷旋轉
- **值越大**: 旋轉越快停止
- **2.0**: 快速停止旋轉，保持方向穩定

## 測試確認

### 現在應該看到：
✅ 單位保持在畫面中央平面
✅ 發射後在平面上滑動
✅ 逐漸減速並停止
✅ 碰撞後反彈

### 不應該看到：
❌ 單位往下掉
❌ 單位飛出畫面
❌ 無限滑動不停

## 調整建議

### 如果單位減速太快
降低 `linear_damp`:
```gdscript
linear_damp = 0.3  # 減速較慢，滑得更遠
```

### 如果單位滑太遠不停
增加 `linear_damp`:
```gdscript
linear_damp = 0.8  # 減速較快，更快停止
```

### 如果單位不斷旋轉
增加 `angular_damp`:
```gdscript
angular_damp = 5.0  # 更快停止旋轉
```

### 如果想要冰面效果
```gdscript
linear_damp = 0.1   # 幾乎不減速
angular_damp = 0.5  # 輕微旋轉
```

## 視覺參考

```
【俯視角 - 正確】
        ↓ 視角從上往下看
    ┌───────────────┐
    │  🔴 玩家      │
    │               │
    │      🔵 敵人  │
    │  🔵 敵人      │
    └───────────────┘
    平面移動，像彈珠台

【側視角 - 錯誤（之前的問題）】
        → 視角從側面看
    ┌───────────────┐
    │               │
    │  🔴           │  ← 有重力會往下掉
    │      ↓        │
    │  🔵  ↓  🔵    │
    └───────────────┘
         ↓↓↓
    掉出畫面 ❌
```

## 立即測試

1. **開啟專案**: 用 Godot 4.x 開啟
2. **按 F5 運行**
3. **觀察**:
   - 玩家單位（紅色）應該保持在畫面中
   - 不會往任何方向掉落
4. **發射測試**:
   - 拖曳玩家單位發射
   - 應該在平面上滑動
   - 逐漸減速並停止

## 其他修正建議

### 鏡頭設定（可選）
如果想要更明確的俯視角，可以在 Battlefield.tscn 添加 Camera2D：
```
[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(576, 324)  # 畫面中心
zoom = Vector2(1, 1)
enabled = true
```

### 背景提示（可選）
添加網格或紋理讓俯視角更明顯：
```gdscript
# 在 Battlefield 添加背景
[node name="Background" type="Sprite2D" parent="."]
texture = preload("res://assets/grid_texture.png")  # 網格紋理
```

## 總結

✅ **已修正**: 所有重力相關設定
✅ **已設定**: 適當的阻尼參數
✅ **已確認**: 俯視角 2D 彈珠台物理
✅ **可運行**: 立即測試無問題

現在遊戲應該正常運作，單位會保持在平面上移動！
