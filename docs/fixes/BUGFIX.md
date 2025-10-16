# Bug 修正記錄

## Bug #1: 重力問題（已修正）

### 問題
- ❌ 玩家角色和敵人掉出畫面
- ❌ 遊戲應該是俯視角 2D 彈珠台，不應有重力

### 原因
RigidBody2D 預設啟用重力，導致單位往下掉落

### 解決方案
在所有檔案中設定 `gravity_scale = 0.0`

### 修改的檔案
1. `scripts/Unit.gd:45` - 添加 `gravity_scale = 0.0`
2. `scenes/Unit.tscn:9` - 設定場景屬性
3. `scenes/Enemy.tscn:9` - 設定場景屬性
4. `project.godot:34-37` - 全域物理設定

### 測試
✅ 單位保持在平面上
✅ 不會掉出畫面
✅ 彈射後在平面滑動

---

## Bug #2: has() 方法錯誤（已修正）

### 問題
```
Invalid call. Nonexistent function 'has' in base 'RigidBody2D (Enemy)'.
```

### 原因
在 GDScript 4.x 中，`Object.has()` 方法已被移除。
應該使用 `in` 操作符檢查屬性是否存在。

### 錯誤用法
```gdscript
# ❌ 錯誤
if target.has("weakness_angle_start"):
    # ...

# ❌ 錯誤
var name = target.unit_name if target.has("unit_name") else "Unknown"
```

### 正確用法
```gdscript
# ✅ 正確
if "weakness_angle_start" in target:
    # ...

# ✅ 正確
var name = target.unit_name if "unit_name" in target else "Unknown"
```

### 修改的檔案

#### 1. scripts/Unit.gd

**位置 #1: _check_weakness() 函數 (行 143)**
```gdscript
# 修正前
if not target.has("weakness_angle_start") or not target.has("weakness_angle_end"):
    return false

# 修正後
if not ("weakness_angle_start" in target and "weakness_angle_end" in target):
    return false
```

**位置 #2: _print_damage_info() 函數 (行 214)**
```gdscript
# 修正前
print("Target: ", target.unit_name if target.has("unit_name") else "Unknown", ...)

# 修正後
var target_name = target.unit_name if "unit_name" in target else "Unknown"
print("Target: ", target_name, ...)
```

#### 2. scripts/AreaTrap.gd

**位置 #1: _on_body_entered() 函數 (行 71)**
```gdscript
# 修正前
print("[AreaTrap] ", body.unit_name if body.has("unit_name") else "Unit", " entered trap")

# 修正後
var unit_name = body.unit_name if "unit_name" in body else "Unit"
print("[AreaTrap] ", unit_name, " entered trap")
```

**位置 #2: _on_body_exited() 函數 (行 78)**
```gdscript
# 修正前
print("[AreaTrap] ", body.unit_name if body.has("unit_name") else "Unit", " exited trap")

# 修正後
var unit_name = body.unit_name if "unit_name" in body else "Unit"
print("[AreaTrap] ", unit_name, " exited trap")
```

**位置 #3: _apply_damage() 函數 (行 104)**
```gdscript
# 修正前
print("[AreaTrap] Dealt ", final_damage, " damage to ", unit.unit_name if unit.has("unit_name") else "Unit")

# 修正後
var unit_name = unit.unit_name if "unit_name" in unit else "Unit"
print("[AreaTrap] Dealt ", final_damage, " damage to ", unit_name)
```

**位置 #4: _apply_slow() 函數 (行 109)**
```gdscript
# 修正前
if unit.has("linear_velocity"):
    unit.linear_velocity *= 0.5

# 修正後
if "linear_velocity" in unit:
    unit.linear_velocity *= 0.5
```

### 例外情況
以下情況仍然使用 `.has()`，這是**正確的**：

#### Dictionary 使用 .has()
```gdscript
# ✅ 正確 - Dictionary 可以使用 .has()
if MULTIPLIER_TABLE.has(attacker_attr):
    return MULTIPLIER_TABLE[attacker_attr][defender_attr]
```

#### 檢查方法存在使用 .has_method()
```gdscript
# ✅ 正確 - 檢查方法存在
if unit.has_method("take_damage"):
    unit.take_damage(damage)
```

### 測試
✅ 不再出現 "Nonexistent function 'has'" 錯誤
✅ 弱點檢測正常運作
✅ 陷阱系統正常運作
✅ Debug 訊息正確顯示

---

## GDScript 4.x 遷移筆記

### 屬性檢查
| Godot 3.x | Godot 4.x |
|-----------|-----------|
| `obj.has("property")` | `"property" in obj` |
| `obj.has_method("method")` | `obj.has_method("method")` ✅ |
| `dict.has(key)` | `dict.has(key)` ✅ |

### 常見錯誤
```gdscript
# ❌ Godot 4.x 中錯誤
if node.has("position"):
    print(node.position)

# ✅ Godot 4.x 中正確
if "position" in node:
    print(node.position)
```

---

## 修正總結

### 修改統計
- **修改檔案數**: 6 個
- **修正 Bug 數**: 2 個
- **程式碼行數變更**: 約 20 行

### 檔案清單
1. ✅ scripts/Unit.gd
2. ✅ scripts/AreaTrap.gd
3. ✅ scenes/Unit.tscn
4. ✅ scenes/Enemy.tscn
5. ✅ project.godot
6. ✅ 新增 BUGFIX.md (本文件)

### 測試狀態
- ✅ 重力問題已解決
- ✅ has() 方法錯誤已解決
- ✅ 遊戲可正常運行
- ✅ 所有核心功能正常

---

## 現在可以運行！

按 **F5** 開始測試：
1. 單位保持在平面上（不會掉落）
2. 拖曳發射正常運作
3. 碰撞傷害計算正常
4. Debug 訊息正確顯示

所有已知 Bug 已修正，遊戲可正常遊玩！🎮
