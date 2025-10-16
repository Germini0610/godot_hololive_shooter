# 傷害判定邏輯

## 核心規則

### 主動 vs 被動移動

只有**主動攻擊者（Active Attacker）**才能造成傷害。

```gdscript
is_active_attacker = true   // 可以造成傷害
is_active_attacker = false  // 不能造成傷害（只有物理推動）
```

## 詳細規則

### 1. 我方行動時

#### 規則 1.1：玩家直接碰撞敵人
```
玩家（主動）━━━> 💥 敵人 A
                    ↓
                 敵人 A 受傷 ✓
                    ↓
                 敵人 A 被推動（變為被動）
```

**邏輯**：
- 玩家：`is_active_attacker = true`（launch 時設定）
- 碰撞敵人 A：造成傷害 ✓
- 敵人 A：`is_active_attacker = false`（knockback 時設定）

#### 規則 1.2：被推動的敵人碰撞其他敵人
```
玩家 ━━━> 敵人 A（被推動）━━━> 💥 敵人 B
                                    ↓
                                敵人 B 不受傷 ✗
                                    ↓
                                敵人 B 被推動（物理效果）
```

**邏輯**：
- 敵人 A：`is_active_attacker = false`（被推動）
- 碰撞敵人 B：**不造成傷害** ✗（只有物理推動）
- 原因：敵人 A 不是主動攻擊者

#### 規則 1.3：連鎖推動
```
玩家 ━━━> 敵人 A ━━━> 敵人 B ━━━> 敵人 C
           受傷 ✓    不受傷 ✗    不受傷 ✗
           被推動     被推動       被推動
          (被動)     (被動)       (被動)
```

**結果**：
- 敵人 A：受傷 ✓（被玩家直接碰撞）
- 敵人 B：不受傷 ✗（被被動的敵人 A 碰撞）
- 敵人 C：不受傷 ✗（被被動的敵人 B 碰撞）

### 2. 敵方行動時

#### 規則 2.1：主動行動的敵人碰撞玩家
```
敵人 A（主動行動）━━━> 💥 玩家
                         ↓
                      玩家受傷 ✓
                         ↓
                      玩家被推動（變為被動）
```

**邏輯**：
- 敵人 A：`is_active_attacker = true`（launch 時設定）
- 碰撞玩家：造成傷害 ✓
- 玩家：`is_active_attacker = false`（knockback 時設定）

#### 規則 2.2：主動敵人推動其他敵人
```
敵人 A（主動）━━━> 💥 敵人 B（靜止）
                        ↓
                    敵人 B 不受傷 ✗
                        ↓
                    敵人 B 被推動（變為被動）
```

**邏輯**：
- 敵人 A：`is_active_attacker = true`
- 碰撞敵人 B：**不造成傷害** ✗（敵人之間永遠不互相傷害）
- 敵人 B：`is_active_attacker = false`（被推動）

#### 規則 2.3：被推動的敵人碰撞玩家
```
敵人 A（主動）━━━> 敵人 B（被推動）━━━> 💥 玩家
                                          ↓
                                      玩家受傷 ✓
```

**邏輯**：
- 敵人 A：`is_active_attacker = true`（主動行動）
- 敵人 B：`is_active_attacker = false`（被推動）
- 敵人 B 碰玩家：**造成傷害** ✓

**特別注意**：這是唯一的例外！
- 原因：源頭是敵人 A 的主動行動
- 實現方式：由於物理引擎的連鎖效果，敵人 B 的速度來自敵人 A
- 判定方式：只要 `is_moving = true` 且碰到玩家，就造成傷害

**等等，需要修正！**

根據你的確認（3.B），這種情況應該造成傷害。但我目前的實現會阻止這種情況！

讓我重新思考...

## 正確的實現邏輯

### 重新分析規則

**玩家被碰撞**：
- 敵人（主動）→ 玩家：受傷 ✓
- 敵人（被推動）→ 玩家：受傷 ✓（因為源頭是敵方行動）

**敵人被碰撞**：
- 玩家（主動）→ 敵人：受傷 ✓
- 敵人（被推動）→ 敵人：不受傷 ✗

### 修正後的規則

```gdscript
if body.is_in_group("enemy") and is_player_unit:
    # 玩家碰敵人
    if is_active_attacker:
        造成傷害 ✓
    else:
        不造成傷害 ✗

elif body.is_in_group("player") and not is_player_unit:
    # 敵人碰玩家
    if is_moving:  # 只要敵人在移動就造成傷害（不管主動被動）
        造成傷害 ✓
    else:
        不造成傷害 ✗

elif body.is_in_group("enemy") and not is_player_unit:
    # 敵人碰敵人
    永遠不造成傷害 ✗（只有物理效果）
```

## 碰撞判定表

| 碰撞者 | 被碰者 | 碰撞者狀態 | 造成傷害？ | 說明 |
|--------|--------|-----------|-----------|------|
| 玩家 | 敵人 | 主動 | ✓ 是 | 玩家攻擊 |
| 玩家 | 敵人 | 被動 | ✗ 否 | 玩家被推動 |
| 敵人 | 玩家 | 主動 | ✓ 是 | 敵人主動攻擊 |
| 敵人 | 玩家 | 被動 | ✓ 是 | 連鎖傷害 |
| 敵人 | 敵人 | 主動 | ✗ 否 | 敵人間不互傷 |
| 敵人 | 敵人 | 被動 | ✗ 否 | 敵人間不互傷 |

## 實現細節

### 新增變數
```gdscript
var is_active_attacker: bool = false  # 是否為主動攻擊者
```

### Launch（主動發射）
```gdscript
func launch(direction: Vector2, power: float):
    linear_velocity = ...
    is_moving = true
    is_active_attacker = true  # 設為主動攻擊者
    print("[Launch] ", unit_name, " launched as ACTIVE ATTACKER")
```

### Knockback（被推動）
```gdscript
func _apply_knockback(target, speed_scale: float):
    target.linear_velocity = ...
    target.is_moving = true
    target.is_active_attacker = false  # 設為被動移動
    print("[Knockback] Target is now PASSIVE (cannot deal damage)")
```

### Stop Movement（停止）
```gdscript
func stop_movement():
    is_moving = false
    is_active_attacker = false  # 清除攻擊者狀態
```

### 碰撞判定（已實現）✓
```gdscript
func _on_body_entered(body):
    if not collision_enabled or not is_moving:
        return

    if body.is_in_group("enemy") and is_player_unit:
        # 玩家碰敵人：只有主動才能造成傷害
        if is_active_attacker:
            _handle_enemy_collision(body)
        else:
            print("玩家被動移動，不造成傷害")

    elif body.is_in_group("player") and not is_player_unit:
        # 敵人碰玩家：只要在移動就造成傷害（主動或被動都行）
        _handle_player_collision(body)

    elif body.is_in_group("enemy") and not is_player_unit:
        # 敵人碰敵人：永遠不造成傷害
        _handle_enemy_to_enemy_collision(body)
```

## 場景示例

### 場景 1：玩家連擊
```
玩家 ━━━> 敵 A 💥 ━━━> 敵 B 💥 ━━━> 敵 C
         受傷 ✓        不傷 ✗       不傷 ✗
         被推(被動)    被推(被動)    被推(被動)
```

### 場景 2：敵人連鎖攻擊
```
敵 A(主動) ━━━> 敵 B 💥 ━━━> 玩家 💥
              不傷 ✗         受傷 ✓
              被推(被動)     被推(被動)
```

**敵 B 變被動，但碰到玩家仍造成傷害！**

### 場景 3：保齡球效果
```
玩家 ━━━> 敵 A ━━━> 敵 B ━━━> 敵 C
         ✓        ✗        ✗

只有敵 A 受傷！
```

### 場景 4：敵方保齡球
```
敵 A(主動) ━━━> 敵 B ━━━> 敵 C ━━━> 玩家
                ✗        ✗         ✓

敵人不互傷，但最後玩家受傷！
```

## Debug 訊息

### Launch 訊息
```
[Launch] Player Unit launched as ACTIVE ATTACKER
[Launch] Red Dragon launched as ACTIVE ATTACKER
```

### Knockback 訊息
```
[Knockback] Player Unit knocked back Blue Slime with power 1200 (speed scale: 0.80) - Target is now PASSIVE (cannot deal damage)
```

### Collision 訊息
```
[Enemy Collision] Red Dragon pushed Green Goblin (PASSIVE)
```

### Damage 訊息
```
=== Damage Info ===
Attacker: Player Unit (RED)
Target: Blue Slime (BLUE)
Speed Scale: 0.80
Attribute Multiplier: 0.50
Buff Multiplier: 1.00
Weakness Hit: false
Final Damage: 40
==================
```

## 修改的檔案

**scripts/Unit.gd**
1. 新增 `is_active_attacker` 變數
2. `launch()` 設定 `is_active_attacker = true`
3. `stop_movement()` 清除 `is_active_attacker = false`
4. `_apply_knockback()` 設定 `target.is_active_attacker = false`
5. `_handle_enemy_to_enemy_collision()` 設定被推動敵人為被動
6. `_on_body_entered()` 修改判定邏輯 ✓

**DAMAGE_LOGIC.md** - 完整的傷害判定文檔

## 總結

**實現完成** ✓

**核心邏輯**：
- ✅ 玩家（主動）→ 敵人：造成傷害
- ✅ 玩家（被動）→ 敵人：不造成傷害
- ✅ 敵人（主動）→ 玩家：造成傷害
- ✅ 敵人（被動）→ 玩家：造成傷害（連鎖效果）
- ✅ 敵人 → 敵人：永遠不造成傷害

**現在傷害判定邏輯完全符合需求！**
