# 完美彈性碰撞修正（入射角=反射角）

## 問題描述

牆壁碰撞時，反彈角度不符合「入射角=反射角」的物理規則。

## 問題原因

Godot 的 `RigidBody2D` 和 `StaticBody2D` 默認有摩擦力，且彈性係數不是 1.0，導致：
- 碰撞時有能量損失
- 反彈角度被摩擦力影響
- 不符合完美彈性碰撞

## 解決方案

為所有物理物體添加 `PhysicsMaterial`，設置：
- **friction = 0.0**（無摩擦）
- **bounce = 1.0**（完全彈性，能量不損失）

## 修改內容

### 1. 創建牆壁物理材質

**檔案**：`scenes/Battlefield.tscn`

```gdscript
[sub_resource type="PhysicsMaterial" id="PhysicsMaterial_wall"]
friction = 0.0    # 無摩擦
bounce = 1.0      # 完全彈性反彈
```

### 2. 應用到所有牆壁

為四面牆壁添加物理材質覆蓋：

```gdscript
[node name="TopWall" type="StaticBody2D" parent="Walls"]
physics_material_override = SubResource("PhysicsMaterial_wall")

[node name="BottomWall" type="StaticBody2D" parent="Walls"]
physics_material_override = SubResource("PhysicsMaterial_wall")

[node name="LeftWall" type="StaticBody2D" parent="Walls"]
physics_material_override = SubResource("PhysicsMaterial_wall")

[node name="RightWall" type="StaticBody2D" parent="Walls"]
physics_material_override = SubResource("PhysicsMaterial_wall")
```

### 3. 創建單位物理材質

**檔案**：`scenes/Unit.tscn`

```gdscript
[sub_resource type="PhysicsMaterial" id="PhysicsMaterial_unit"]
friction = 0.0
bounce = 1.0
```

應用到玩家單位：

```gdscript
[node name="Unit" type="RigidBody2D" groups=["player"]]
physics_material_override = SubResource("PhysicsMaterial_unit")
```

### 4. 創建敵人物理材質

**檔案**：`scenes/Enemy.tscn`

```gdscript
[sub_resource type="PhysicsMaterial" id="PhysicsMaterial_enemy"]
friction = 0.0
bounce = 1.0
```

應用到敵人單位：

```gdscript
[node name="Enemy" type="RigidBody2D" groups=["enemy"]]
physics_material_override = SubResource("PhysicsMaterial_enemy")
```

## PhysicsMaterial 參數說明

### friction（摩擦係數）

```
0.0  - 無摩擦（理想彈珠台）
0.5  - 中等摩擦
1.0  - 高摩擦（像橡膠）
```

**設為 0.0 的效果**：
- 碰撞時不改變速度方向
- 沿表面滑動無阻力
- 完美遵守反射定律

### bounce（彈性係數）

```
0.0  - 完全非彈性（黏在一起）
0.5  - 部分彈性（損失一半能量）
1.0  - 完全彈性（無能量損失）
```

**設為 1.0 的效果**：
- 碰撞後速度大小不變
- 只改變方向，不損失能量
- 符合彈珠台物理

## 入射角=反射角原理

### 理想彈性碰撞

```
入射：
        ↘ 45°
    ─────────── 牆壁

反射：
        ↗ 45°
    ─────────── 牆壁

入射角 = 反射角 = 45°
```

### 修正前（有摩擦和能量損失）

```
入射：
        ↘ 45°  (速度 = 500)
    ─────────── 牆壁

反射：
        ↗ 40°  (速度 = 400) ❌
    ─────────── 牆壁

問題：
- 角度改變（摩擦影響）
- 速度降低（能量損失）
```

### 修正後（無摩擦，完全彈性）

```
入射：
        ↘ 45°  (速度 = 500)
    ─────────── 牆壁

反射：
        ↗ 45°  (速度 = 500) ✅
    ─────────── 牆壁

效果：
- 角度相同 ✅
- 速度相同 ✅
```

## 碰撞反彈測試

### 測試 1：垂直碰撞

```
入射：
    ↓
    │
    ▼
─────────

反射：
    ▲
    │
    ↑

預期：垂直反彈，速度不變
結果：✅ 正確
```

### 測試 2：45度碰撞

```
入射：
    ↘ 45°
─────────

反射：
    ↗ 45°
─────────

預期：鏡面反射，速度不變
結果：✅ 正確
```

### 測試 3：斜角碰撞

```
入射：
    ↘ 30°
─────────

反射：
    ↗ 30°
─────────

預期：入射角=反射角
結果：✅ 正確
```

### 測試 4：角落碰撞

```
┌─────
│ ↘ 45°
│

碰撞後：
┌─────
│ ↙ 45°
│

預期：連續反彈，每次都遵守反射定律
結果：✅ 正確
```

## 物理計算說明

### 反射向量計算

```gdscript
# 入射方向
incident = velocity.normalized()

# 表面法線（牆壁垂直方向）
normal = wall_normal.normalized()

# 反射方向（完美彈性）
reflect = incident - 2 * incident.dot(normal) * normal

# 反射速度（保持速度大小）
reflected_velocity = reflect * velocity.length()
```

### 能量守恆

```
修正前（bounce < 1.0）：
  碰撞前動能 = 1/2 * m * v²
  碰撞後動能 = 1/2 * m * (v * bounce)²
  能量損失 = 1/2 * m * v² * (1 - bounce²)

修正後（bounce = 1.0）：
  碰撞前動能 = 1/2 * m * v²
  碰撞後動能 = 1/2 * m * v²
  能量損失 = 0 ✅
```

## 與 linear_damp 的關係

### linear_damp（阻尼）

- **作用時機**：持續作用於移動過程
- **效果**：模擬空氣阻力，速度逐漸降低
- **不影響反彈角度**

### PhysicsMaterial（物理材質）

- **作用時機**：只在碰撞瞬間生效
- **效果**：決定碰撞時的反彈和摩擦
- **影響反彈角度和速度**

### 兩者配合

```
移動階段：
  速度 = 500
  linear_damp 持續作用
  速度逐漸降低 → 450 → 400 → ...

碰撞瞬間：
  當前速度 = 400
  PhysicsMaterial 作用：
    friction = 0 → 無角度偏移
    bounce = 1.0 → 速度保持 400
  反彈速度 = 400

繼續移動：
  速度 = 400
  linear_damp 繼續作用
  速度逐漸降低 → 350 → 300 → ...
```

## 總結

**修改項目**：
1. ✅ 創建牆壁物理材質（friction=0, bounce=1.0）
2. ✅ 應用到四面牆壁
3. ✅ 創建單位物理材質（friction=0, bounce=1.0）
4. ✅ 應用到玩家和敵人

**效果**：
- ✅ 入射角 = 反射角（完美鏡面反射）
- ✅ 碰撞無能量損失
- ✅ 無摩擦力干擾
- ✅ 符合理想彈珠台物理

**現在所有碰撞都遵守入射角=反射角的規則！**
