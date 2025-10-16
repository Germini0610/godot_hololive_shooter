# Hololive Shooter - Stardust Shooters Style 2D Battle System

完整實作的 2D 彈射戰鬥核心系統，符合 Stardust Shooters 機制。

## 專案結構

```
hololive-shooter/
├── scripts/
│   ├── Attribute.gd          # 屬性系統與相剋表
│   ├── Unit.gd               # 玩家單位基礎類
│   ├── Enemy.gd              # 敵人單位類
│   ├── Team.gd               # 隊伍管理系統
│   ├── BattleController.gd   # 戰鬥主控制器
│   ├── BattleUI.gd           # 戰鬥 UI 系統
│   ├── AreaTrap.gd           # 陷阱區域系統
│   └── DamageLabel.gd        # 傷害浮字
├── scenes/
│   ├── Battlefield.tscn      # 主戰場場景
│   ├── Unit.tscn             # 玩家單位場景
│   ├── Enemy.tscn            # 敵人場景
│   ├── AreaTrap.tscn         # 陷阱場景
│   └── BattleUI.tscn         # UI 場景
└── project.godot
```

## 核心功能

### 1. 屬性系統
- **7 種屬性**: RED, BLUE, GREEN, BLACK, WHITE, GOLD, SILVER
- **相剋倍率表**: 完整實作屬性相剋計算
- 位置: `scripts/Attribute.gd`

### 2. 彈射戰鬥機制
- **拖曳發射**: 按住滑鼠拖曳方向與力度，鬆開發射
- **碰撞傷害**: 單位與敵人碰撞時觸發接觸傷害計算
- **Smash 系統**: 移動途中點擊一次，在當前位置施放 AoE（1.5 倍傷害）
- 位置: `scripts/BattleController.gd:67-131`

### 3. 傷害計算
完整公式：
```gdscript
damage = atk * speed_scale * attr_multiplier * buff_multiplier * weakness_multiplier
```
- **速度倍率**: 根據移動速度計算
- **屬性相剋**: 使用 `Attribute.get_multiplier()`
- **弱點系統**: 命中後方弱點區域 (135°-225°) 造成 1.5 倍傷害並減少敵人行動倒數
- 位置: `scripts/Unit.gd:83-135`

### 4. 技能系統

#### Command Skill（主動技）
- 每個單位有能量需求 (0-5)
- 移動中點擊觸發技能
- 預設：範圍多段傷害
- 位置: `scripts/Unit.gd:218-232`

#### Leader Skill（被動）
- 對全隊或特定屬性成員提供 Buff
- 自動應用於隊伍成員
- 位置: `scripts/Team.gd:66-84`

#### Link Skill（被動）
- 檢測隊伍屬性組合
- 自動觸發連攜效果
- 位置: `scripts/Team.gd:86-104`

### 5. 技能量表 (Skill Gauge)
- **最大值**: 5 段
- **累積方式**: 命中敵人時根據速度比例獲得能量
- **消耗**: 使用 Command Skill 消耗對應能量
- 位置: `scripts/BattleController.gd:15-16`, `scripts/Unit.gd:107-113`

### 6. 隊伍系統
5 個位置：
- **Leader**: 隊長
- **Frontline 1 & 2**: 前線戰鬥成員
- **Standby**: 替補
- **Friend**: 好友支援

位置: `scripts/Team.gd`

### 7. 敵人行動系統
- **Action Count**: 每個敵人有行動倒數
- **玩家移動**: 每次移動後所有敵人倒數 -1
- **弱點懲罰**: 命中弱點額外 -1 倒數
- **行動類型**:
  - CHARGE: 衝撞玩家
  - SKILL: 釋放技能
  - TRAP: 布置陷阱
  - BUFF: 自我強化
- 位置: `scripts/Enemy.gd:31-102`

### 8. 陷阱系統 (AreaSkills)
- **傷害陷阱**: 持續造成傷害
- **減速陷阱**: 減少移動速度
- **定身陷阱**: 強制停止移動
- **增益陷阱**: 提供 Buff
- **持續時間**: 可配置 (預設 10 秒)
- 位置: `scripts/AreaTrap.gd`

### 9. 1-More 系統
- 單次移動內擊殺敵人觸發
- 立即獲得一次追加移動機會
- 不遞減敵人行動倒數
- 位置: `scripts/BattleController.gd:270-279`

### 10. Soul Chip 系統
- 每個單位有 N 次自救機會（預設 3 次）
- 使用後恢復滿 HP
- 可透過 UI 按鈕觸發
- 位置: `scripts/Unit.gd:182-191`, `scripts/BattleController.gd:297-301`

### 11. Debug 系統
- **傷害浮字**: 自動顯示每次傷害數值
  - 普通: 白色
  - 弱點: 黃色
  - 暴擊: 橘紅色
- **詳細日誌**: 列印命中資訊
  - 速度倍率
  - 屬性相剋
  - Buff 倍率
  - 是否弱點
  - 最終傷害
- **物理可視化**: 可開關碰撞框顯示
- 位置: `scripts/Unit.gd:206-216`, `scripts/DamageLabel.gd`, `scripts/BattleController.gd:303-309`

## 操作說明

### 基本操作
1. **發射單位**: 按住滑鼠左鍵 → 拖曳設定方向與力度 → 鬆開發射
2. **Smash**: 單位移動中點擊一次（無技能時）
3. **Command Skill**: 單位移動中點擊一次（技能量表足夠時）
4. **Soul Chip**: 透過 UI 按鈕使用（需實作 UI 按鈕）

### 輸入映射
- `ui_click`: 滑鼠左鍵 (已配置在 project.godot)

## 場景配置

### Battlefield.tscn
主戰場包含：
- 四周靜態牆壁 (StaticBody2D)
- 玩家單位容器
- 敵人容器
- 陷阱容器
- UI 層

### 物理層配置
- **Layer 1**: Player
- **Layer 2**: Enemy
- **Layer 3**: Trap

## 擴展指南

### 添加新單位
1. 繼承 `Unit` 或 `Enemy` 類
2. 覆寫 `_execute_command_skill()` 實作自訂技能
3. 設定屬性、HP、ATK 等參數

### 添加新技能
```gdscript
extends Unit

func _execute_command_skill():
	# 自訂技能邏輯
	var nearby_enemies = _get_nearby_enemies(300.0)
	for enemy in nearby_enemies:
		enemy.take_damage(atk * 3, false)
```

### 自訂 Leader Skill
```gdscript
var custom_leader = Team.LeaderSkill.new("Fire Boost", "atk", 1.5)
custom_leader.target_attributes = [Attribute.Type.RED]
player_team.set_custom_leader_skill(custom_leader)
```

### 添加陷阱
```gdscript
var trap = preload("res://scenes/AreaTrap.tscn").instantiate()
trap.global_position = position
trap.damage = 100
trap.effect_type = AreaTrap.EffectType.SLOW
get_parent().add_child(trap)
```

## 運行專案

1. 使用 Godot 4.x 開啟專案
2. 主場景自動設定為 `scenes/Battlefield.tscn`
3. 按 F5 運行

## Debug 模式

在 BattleController 中啟用：
```gdscript
# 在 Inspector 中設定
debug_enabled = true
show_physics_debug = true
```

或程式碼控制：
```gdscript
battle_controller.set_debug_mode(true)
battle_controller.toggle_physics_debug()
```

## 技術細節

### 碰撞檢測
- 使用 `RigidBody2D` 作為單位主體
- `CircleShape2D` 碰撞形狀
- `contact_monitor = true` 啟用碰撞監控

### 弱點判定
- 計算碰撞點相對於目標的角度
- 檢查是否在弱點範圍 (預設 135°-225°)
- 位置: `scripts/Unit.gd:137-157`

### 回合系統
- 玩家移動後所有敵人倒數 -1
- 倒數歸零的敵人依序執行行動
- 檢查戰鬥結束條件
- 位置: `scripts/BattleController.gd:223-238`

## 已實作功能清單

✅ 屬性系統與相剋表
✅ 彈射移動與碰撞傷害
✅ Smash 系統
✅ Command/Leader/Link Skill
✅ 技能量表 (0-5 段)
✅ 隊伍系統 (5 位置)
✅ 敵人行動與回合系統
✅ 弱點系統
✅ 1-More 系統
✅ Soul Chip 系統
✅ 陷阱區域系統
✅ 傷害浮字
✅ Debug 日誌
✅ 物理可視化

## 注意事項

1. **屬性相剋**: 確保使用 `Attribute.get_multiplier()` 計算倍率
2. **碰撞層**: Unit 和 Enemy 必須設定正確的 collision_layer 和 collision_mask
3. **信號連接**: BattleController 在 `_ready()` 中自動連接敵人死亡信號
4. **Scene 依賴**: 確保所有 .tscn 檔案的路徑正確
5. **輸入映射**: `ui_click` 必須在 project.godot 中配置

## 效能建議

- 限制同時顯示的傷害浮字數量
- 使用對象池管理陷阱
- 定期清理已死亡的敵人
- 限制物理查詢的範圍和頻率

## 授權

此專案為教學範例，可自由使用與修改。


通过网盘分享的文件：4096_Dark VFX 01 - 12.rar
链接: https://pan.baidu.com/s/1NdngDQWzkrHFc3q8JSyZ5g?pwd=4096 提取码: 4096 
--来自百度网盘超级会员v6的分享