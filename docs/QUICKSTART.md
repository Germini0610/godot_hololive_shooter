# 快速入門指南

## 立即運行

1. 用 Godot 4.x 開啟專案
2. 直接按 **F5** 運行
3. 主場景會自動載入 `Battlefield.tscn`

## 基本操作測試

### 1. 發射單位
- **按住滑鼠左鍵** 在玩家單位（紅色方塊）上
- **拖曳** 來設定發射方向和力度（拖越長力度越大）
- **鬆開** 發射單位

### 2. Smash 技能
- 在單位移動途中 **點擊一次**
- 會在當前位置造成範圍傷害（1.5 倍）
- 立即停止移動

### 3. Command Skill
- 先透過攻擊累積技能量表（螢幕左上方）
- 當量表足夠時（預設需要 3 段），移動中點擊觸發
- 會造成範圍多段傷害並消耗能量

## 觀察要點

### 控制台輸出
運行後查看控制台，會看到：
```
[BattleController] Initialized
[BattleController] Initial active unit: Unit
```

發射單位後：
```
[BattleController] Launching unit with power: 1234.56
=== Damage Info ===
Attacker: Unit (RED)
Target: Enemy (BLUE)
Speed Scale: 0.85
Attribute Multiplier: 2.00  # RED 對 BLUE 有優勢
Buff Multiplier: 1.00
Weakness Hit: false
Final Damage: 170
==================
```

### 傷害浮字
- **白色數字**: 普通傷害
- **黃色數字**: 弱點傷害
- 數字會向上飄動並淡出

### 敵人行動倒數
- 每個敵人中央顯示數字（Action Count）
- 玩家每次移動後 -1
- 歸零時敵人會執行行動

### 技能量表
- 螢幕左上角 5 個方塊
- 灰色 = 未填充
- 金色 = 已填充

## 測試場景

### 場景 1: 基本攻擊
1. 發射單位撞擊藍色敵人
2. 觀察 RED vs BLUE 的 2.0 倍相剋傷害
3. 查看控制台的詳細傷害計算

### 場景 2: 弱點攻擊
1. 繞到敵人後方（135°-225° 範圍）
2. 從後方攻擊
3. 觀察黃色弱點傷害數字（1.5 倍）
4. 敵人 Action Count 會額外 -1

### 場景 3: Smash
1. 發射單位
2. 在移動途中點擊一次
3. 觀察範圍傷害效果
4. 單位立即停止

### 場景 4: 1-More
1. 攻擊敵人至 HP 歸零
2. 控制台顯示 `[BattleController] 1-More! Extra move granted.`
3. 立即獲得一次額外移動
4. 敵人行動倒數不會減少

### 場景 5: 技能量表
1. 持續攻擊敵人累積能量
2. 觀察左上角量表填充
3. 達到 3 段後，移動中點擊觸發技能
4. 量表消耗，造成範圍傷害

## 修改與實驗

### 調整單位屬性
在 `scenes/Unit.tscn` 或 `scenes/Enemy.tscn` 的 Inspector：
- `Max HP`: 最大生命值
- `Atk`: 攻擊力
- `Attribute`: 屬性（0=RED, 1=BLUE, 2=GREEN...）
- `Command Skill Cost`: 技能消耗

### 調整物理參數
在 `scripts/Unit.gd`:
```gdscript
const STOP_VELOCITY_THRESHOLD: float = 50.0  # 停止移動閾值
const MAX_SPEED: float = 2000.0              # 最大速度
```

在 `scripts/BattleController.gd`:
```gdscript
const MIN_LAUNCH_POWER: float = 100.0   # 最小發射力度
const MAX_LAUNCH_POWER: float = 2000.0  # 最大發射力度
const POWER_SCALE: float = 2.0          # 力度縮放
```

### 添加更多敵人
1. 在 Godot 編輯器中開啟 `scenes/Battlefield.tscn`
2. 從 FileSystem 拖曳 `scenes/Enemy.tscn` 到場景
3. 調整位置和屬性
4. 運行測試

### 測試不同屬性相剋
修改 `scenes/Unit.tscn` 和 `scenes/Enemy.tscn` 的 `Attribute`:
- RED (0) vs GREEN (2) = 2.0x
- BLUE (1) vs RED (0) = 2.0x
- GREEN (2) vs BLUE (1) = 2.0x
- GOLD (5) vs BLACK (3) = 2.0x
- SILVER (6) vs WHITE (4) = 2.0x

### 啟用物理 Debug
在 `scenes/Battlefield.tscn` 的 BattleController：
- 勾選 `Show Physics Debug`
- 可視化碰撞框和物理狀態

## 常見問題

### Q: 點擊沒有反應？
A: 確保：
- 點擊的是紅色玩家單位
- 單位沒有正在移動中
- `ui_click` 輸入映射已配置

### Q: 傷害沒有顯示？
A: 檢查：
- 單位是否真的碰撞到敵人
- 控制台是否有 "=== Damage Info ===" 輸出
- DamageLabel.gd 是否正確載入

### Q: 敵人不會行動？
A: 確認：
- 敵人的 Action Count 是否歸零
- 敵人是否在 "enemy" 群組中
- Enemy.gd 的 action_type 是否設定

### Q: 1-More 不觸發？
A: 檢查：
- 敵人是否真的死亡（HP <= 0）
- BattleController 是否連接了敵人的 died 信號
- 控制台是否有 "Enemy died" 訊息

### Q: 技能量表不累積？
A: 確認：
- Unit 是否在 "player" 群組
- 是否有碰撞到敵人
- BattleController 是否在 "battle_controller" 群組

## 下一步

1. **自訂單位技能**: 繼承 Unit 類並覆寫 `_execute_command_skill()`
2. **設計 Leader Skill**: 使用 `Team.LeaderSkill` 類
3. **創建陷阱**: 實例化 AreaTrap 場景
4. **完善 UI**: 擴展 BattleUI 添加更多資訊顯示
5. **添加動畫**: 為單位和技能添加視覺效果

## Debug 技巧

### 實時修改屬性
在 Godot 編輯器運行時：
- 選擇場景中的單位
- 在 Remote 標籤下實時修改 Inspector 屬性
- 立即看到效果

### 控制台過濾
搜尋特定訊息：
- `Damage Info` - 查看傷害計算
- `BattleController` - 追蹤戰鬥流程
- `Enemy` - 監控敵人狀態
- `1-More` - 確認追加移動觸發

### 效能監控
- 按 **F9** 開啟效能監控面板
- 查看 FPS、物理運算、記憶體使用
- 關注傷害浮字數量

## 進階測試

### 壓力測試
1. 添加 10+ 個敵人
2. 快速連續攻擊
3. 觀察效能和記憶體

### 邊界測試
1. 測試單位撞擊牆壁
2. 測試極端發射角度
3. 測試同時命中多個敵人

### 技能組合
1. 累積滿技能量表
2. 配合 Smash 使用
3. 測試 1-More 連鎖

祝開發順利！
