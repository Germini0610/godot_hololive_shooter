# 系統架構文件

## 核心類別關係圖

```
BattleController (Node2D)
    ├── Team (Node)
    │   ├── LeaderSkill (內部類)
    │   └── LinkSkill (內部類)
    ├── Unit (RigidBody2D) [多個實例]
    │   └── 繼承 → Enemy (RigidBody2D)
    └── AreaTrap (Area2D) [多個實例]

BattleUI (CanvasLayer)
    ├── SkillGaugeContainer
    ├── TeamDisplay
    ├── TurnLabel
    └── DebugPanel

Attribute (靜態工具類)
    └── 提供屬性相剋計算

DamageLabel (Label) [動態生成]
```

## 資料流向

### 1. 輸入流程
```
玩家輸入 (滑鼠)
    ↓
BattleController._handle_input()
    ↓
根據狀態分支：
    ├─ 按下: 開始拖曳
    ├─ 拖曳中: 更新軌跡
    ├─ 鬆開: _launch_unit()
    └─ 移動中點擊: _trigger_smash() 或 _trigger_skill()
```

### 2. 碰撞與傷害流程
```
Unit.launch() → 賦予線速度
    ↓
物理引擎偵測碰撞
    ↓
Unit._on_body_entered()
    ↓
Unit._handle_enemy_collision()
    ├─ 計算速度倍率
    ├─ 檢查弱點: _check_weakness()
    ├─ 計算屬性相剋: Attribute.get_multiplier()
    ├─ 計算 Buff: _calculate_buff_multiplier()
    └─ 計算最終傷害
    ↓
Enemy.take_damage()
    ├─ 扣除 HP
    ├─ 發射 hp_changed 信號
    └─ HP <= 0 → die()
    ↓
Enemy.die() → 發射 died 信號
    ↓
BattleController._on_enemy_died()
    ├─ 設置 one_more_available = true
    ├─ 延遲刪除敵人
    └─ _check_battle_end()
```

### 3. 技能量表流程
```
Unit._handle_enemy_collision()
    ↓
計算 skill_gain = speed_scale * 20
    ↓
call_group("battle_controller", "add_skill_gauge", skill_gain)
    ↓
BattleController.add_skill_gauge()
    ├─ current_skill_gauge += amount
    ├─ clamp(0, MAX_SKILL_GAUGE)
    └─ emit skill_gauge_changed 信號
    ↓
BattleController._on_skill_gauge_changed()
    ↓
BattleUI.update_skill_gauge()
    └─ 更新 UI 方塊顏色
```

### 4. 回合系統流程
```
BattleController._on_movement_ended()
    ↓
檢查 one_more_available
    ├─ true: 重置 flag，不結束回合
    └─ false: _end_player_move()
        ↓
        _decrease_all_enemy_action_counts()
            ├─ 遍歷所有敵人
            └─ enemy.decrease_action_count(1)
                ↓
                enemy.current_action_count -= 1
                ↓
                如果 <= 0:
                    ├─ emit action_ready 信號
                    ├─ execute_action()
                    └─ reset_action_count()
        ↓
        _select_next_unit()
            └─ 從 team.get_frontline_members() 選擇
```

### 5. 敵人行動流程
```
Enemy.execute_action()
    ↓
根據 action_type 分支:
    ├─ CHARGE: _execute_charge()
    │   ├─ _find_nearest_player()
    │   └─ launch(direction, power)
    │
    ├─ SKILL: _execute_skill()
    │   ├─ _get_nearby_players(radius)
    │   └─ 對每個玩家造成傷害
    │
    ├─ TRAP: _execute_trap()
    │   ├─ 實例化 AreaTrap 場景
    │   └─ 添加到場景樹
    │
    └─ BUFF: _execute_buff()
        └─ add_buff("atk", multiplier, duration)
```

## 信號系統

### Unit 信號
```gdscript
signal hp_changed(new_hp: int, max_hp: int)
signal died()
signal damaged(damage: int, is_weakness: bool)
```

**連接者**:
- BattleController: 監聽 died 信號處理 1-More
- UI 元件: 監聽 hp_changed 更新血條

### Enemy 信號（繼承 Unit）
```gdscript
signal action_ready()
signal action_count_changed(new_count: int)
```

**連接者**:
- UI: 顯示行動倒數

### BattleController 信號
```gdscript
signal skill_gauge_changed(current: int, max: int)
signal turn_changed(turn: int)
signal battle_ended(victory: bool)
signal smash_ready(ready: bool)
signal skill_ready(ready: bool)
```

**連接者**:
- BattleUI: 更新所有 UI 元素
- 遊戲主控制器: 處理戰鬥結束

### Team 信號
```gdscript
signal team_changed()
signal leader_skill_activated(skill_name: String)
signal link_skill_activated(skill_name: String)
```

**連接者**:
- UI: 顯示技能觸發特效

## 關鍵演算法

### 1. 弱點判定演算法
```gdscript
# scripts/Unit.gd:137-157
func _check_weakness(target, collision_point: Vector2) -> bool:
    # 計算碰撞點相對於目標的向量
    var to_collision = collision_point - target.global_position

    # 轉換為角度（弧度 → 度）
    var angle = rad_to_deg(to_collision.angle())

    # 正規化到 0-360 度
    if angle < 0:
        angle += 360

    # 檢查是否在弱點範圍內
    # 預設：135° - 225°（後方 90 度扇形）
    var start = target.weakness_angle_start
    var end = target.weakness_angle_end

    if start <= end:
        return angle >= start and angle <= end
    else:  # 跨越 0° 的情況
        return angle >= start or angle <= end
```

**複雜度**: O(1)
**精確度**: 1 度

### 2. 附近敵人查詢
```gdscript
# scripts/Unit.gd:235-250
func _get_nearby_enemies(radius: float) -> Array:
    var space_state = get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var shape = CircleShape2D.new()
    shape.radius = radius
    query.shape = shape
    query.transform = global_transform
    query.collision_mask = collision_mask

    var results = space_state.intersect_shape(query)
    var enemies = []
    for result in results:
        if result.collider != self and result.collider.is_in_group("enemy"):
            enemies.append(result.collider)

    return enemies
```

**複雜度**: O(n) 其中 n 是範圍內的物體數量
**使用 Godot 物理引擎**: 空間分割加速

### 3. 屬性相剋查表
```gdscript
# scripts/Attribute.gd:12-68
const MULTIPLIER_TABLE = {
    Type.RED: {
        Type.BLUE: 0.5,   # 劣勢
        Type.GREEN: 2.0,  # 優勢
        # ...
    },
    # ...
}

static func get_multiplier(attacker: Type, defender: Type) -> float:
    if MULTIPLIER_TABLE.has(attacker) and MULTIPLIER_TABLE[attacker].has(defender):
        return MULTIPLIER_TABLE[attacker][defender]
    return 1.0
```

**複雜度**: O(1) 雜湊表查詢
**記憶體**: 7x7 = 49 個 float 值

### 4. 傷害計算公式
```gdscript
# scripts/Unit.gd:92-98
var base_damage = atk * speed_scale
var attr_multiplier = Attribute.get_multiplier(attribute, enemy.attribute)
var buff_multiplier = _calculate_buff_multiplier()
var weakness_multiplier = 1.5 if is_weakness else 1.0

var final_damage = int(base_damage * attr_multiplier * buff_multiplier * weakness_multiplier)
```

**數學表達式**:
```
damage = ⌊atk × (v/v_max) × m_attr × m_buff × m_weak⌋
```

其中：
- `atk`: 單位攻擊力
- `v/v_max`: 速度比例（0.0 - 1.0）
- `m_attr`: 屬性相剋倍率
- `m_buff`: Buff 累乘倍率
- `m_weak`: 弱點倍率（1.0 或 1.5）
- `⌊⌋`: 向下取整

## 效能考量

### 1. 碰撞檢測
- **方法**: RigidBody2D 內建碰撞系統
- **最佳化**:
  - 使用 CircleShape2D（最快）
  - 限制 max_contacts_reported = 10
  - collision_enabled 旗標避免重複計算
- **複雜度**: O(log n) 透過空間分割

### 2. 物理查詢
- **頻率**: 每次技能施放時
- **範圍**: 通常 150-300 單位
- **最佳化**:
  - 使用正確的 collision_mask 過濾
  - 限制查詢範圍
  - 快取結果（當前未實作）

### 3. 傷害浮字
- **生命週期**: 1.5 秒
- **管理**: 自動刪除（Tween.finished 信號）
- **潛在問題**: 大量同時顯示時效能下降
- **建議**: 實作對象池（當前未實作）

### 4. 信號系統
- **開銷**: 每次 emit 需要遍歷連接者
- **最佳化**:
  - 避免過度連接
  - 使用 call_deferred 延遲處理
  - 及時斷開不需要的連接

## 記憶體管理

### 物件生命週期
```
Unit/Enemy:
    建立: 場景載入時或動態實例化
    銷毀: die() → visible=false → queue_free() (延遲 0.5 秒)

DamageLabel:
    建立: _spawn_damage_label()
    銷毀: Tween 完成後 queue_free() (1.5 秒)

AreaTrap:
    建立: 敵人行動或技能
    銷毀: duration 到期後 queue_free()

Team:
    建立: BattleController._ready()
    銷毀: 隨 BattleController
```

### 群組管理
```
"player": 所有玩家單位
"enemy": 所有敵人單位
"battle_controller": BattleController 實例（單例）
```

## 擴展點

### 1. 新單位類型
繼承 `Unit` 或 `Enemy`，覆寫：
- `_execute_command_skill()`: 自訂技能邏輯
- `_ready()`: 初始化特殊屬性
- `take_damage()`: 特殊傷害反應

### 2. 新技能系統
擴展 `Team.LeaderSkill` 或 `Team.LinkSkill`：
```gdscript
class CustomSkill extends Team.LeaderSkill:
    var special_effect: String
    func apply_effect(unit: Unit):
        # 自訂邏輯
```

### 3. 新陷阱效果
擴展 `AreaTrap.EffectType` 枚舉：
```gdscript
enum EffectType {
    # ... 現有效果
    POISON,     # 持續毒傷
    FREEZE,     # 凍結
    TELEPORT    # 傳送
}
```

### 4. AI 系統
為 Enemy 添加決策樹：
```gdscript
func _choose_action() -> ActionType:
    var hp_ratio = float(current_hp) / max_hp
    if hp_ratio < 0.3:
        return ActionType.BUFF
    elif _is_player_nearby(300):
        return ActionType.SKILL
    else:
        return ActionType.CHARGE
```

## 已知限制與改進方向

### 當前限制
1. **單一活躍單位**: 只有一個單位可發射
2. **簡化隊伍系統**: Team 成員未完全整合
3. **無視覺特效**: 缺少粒子、動畫
4. **無音效**: 沒有音頻系統
5. **固定關卡**: 沒有關卡載入系統

### 建議改進
1. **對象池系統**: 管理 DamageLabel、AreaTrap
2. **動畫系統**: AnimationPlayer 整合
3. **存檔系統**: 保存隊伍配置
4. **技能編輯器**: 視覺化技能設計工具
5. **網路多人**: 透過 Godot 網路系統

## 測試策略

### 單元測試目標
1. `Attribute.get_multiplier()`: 所有組合
2. `Unit._check_weakness()`: 各種角度
3. `Team`: 成員管理、技能觸發
4. 傷害計算: 極端值、邊界條件

### 整合測試場景
1. **基本戰鬥流程**: 發射 → 碰撞 → 傷害 → 死亡
2. **1-More 連鎖**: 連續擊殺測試
3. **技能組合**: Smash + Command Skill
4. **敵人行動**: 各種 ActionType
5. **壓力測試**: 大量單位、高頻攻擊

## 參考資料

- Godot 物理系統: https://docs.godotengine.org/en/stable/tutorials/physics/
- RigidBody2D API: https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html
- 信號系統: https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
