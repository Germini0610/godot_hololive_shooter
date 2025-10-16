# HP 顯示系統

## 新增功能

為所有單位（玩家和敵人）添加了 HP 血條和數值顯示。

## 顯示元素

### 1. HP 血條（ProgressBar）
```
位置: 單位下方
大小: 80x10 像素
顏色: 根據 HP 百分比動態變化
  - > 60%: 綠色
  - 30-60%: 黃色
  - < 30%: 紅色
```

### 2. HP 數值標籤（Label）
```
位置: 血條下方
字體大小: 16px
格式: "當前HP/最大HP"
示例: "800/1000"
```

## 血條顏色系統

### 綠色（健康）
```
HP > 60%
顏色: Color.GREEN
狀態: 健康
```

### 黃色（受傷）
```
30% < HP ≤ 60%
顏色: Color.YELLOW
狀態: 受傷，需要注意
```

### 紅色（危險）
```
HP ≤ 30%
顏色: Color.RED
狀態: 危險，即將死亡
```

## 視覺效果示例

### 完整 HP（100%）
```
        敵人名稱
          [3]
         ━━━━
        |    |
         ━━━━
    ████████████  (綠色)
       800/800
```

### 中等 HP（50%）
```
        敵人名稱
          [3]
         ━━━━
        |    |
         ━━━━
    ██████░░░░░░  (黃色)
       400/800
```

### 低 HP（25%）
```
        敵人名稱
          [3]
         ━━━━
        |    |
         ━━━━
    ███░░░░░░░░░  (紅色)
       200/800
```

### 瀕死（5%）
```
        敵人名稱
          [3]
         ━━━━
        |    |
         ━━━━
    █░░░░░░░░░░░  (紅色)
        40/800
```

## 實現細節

### Unit.tscn（玩家單位）
```gdscript
[node name="HPBar" type="ProgressBar"]
offset_left = -40.0
offset_top = 40.0
offset_right = 40.0
offset_bottom = 50.0
max_value = 100.0
value = 100.0

[node name="HPLabel" type="Label"]
offset_left = -40.0
offset_top = 52.0
offset_right = 40.0
offset_bottom = 70.0
font_size = 16
text = "1000/1000"
```

### Enemy.tscn（敵人單位）
```gdscript
[node name="HPBar" type="ProgressBar"]
offset_left = -40.0
offset_top = 40.0
offset_right = 40.0
offset_bottom = 50.0
max_value = 100.0
value = 100.0

[node name="HPLabel" type="Label"]
offset_left = -40.0
offset_top = 52.0
offset_right = 40.0
offset_bottom = 70.0
font_size = 16
text = "800/800"
```

### Unit.gd（基礎邏輯）
```gdscript
## UI 引用
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel

func _ready():
    # 連接 HP 變化信號
    hp_changed.connect(_on_hp_changed)
    _update_hp_display()

## HP 變化回調
func _on_hp_changed(new_hp: int, _max_hp: int):
    _update_hp_display()

## 更新 HP 顯示
func _update_hp_display():
    if hp_bar:
        var hp_percentage = (float(current_hp) / float(max_hp)) * 100.0
        hp_bar.value = hp_percentage

        # 顏色變化
        if hp_percentage > 60:
            hp_bar.modulate = Color.GREEN
        elif hp_percentage > 30:
            hp_bar.modulate = Color.YELLOW
        else:
            hp_bar.modulate = Color.RED

    if hp_label:
        hp_label.text = str(current_hp) + "/" + str(max_hp)
```

### Enemy.gd（敵人特化）
```gdscript
## UI 引用
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel

func _ready():
    super._ready()
    # 連接 HP 變化信號
    hp_changed.connect(_on_hp_changed)
    _update_hp_display()

## HP 變化回調和更新函數
（繼承自 Unit.gd）
```

## 自動更新機制

### 受到傷害時
```gdscript
func take_damage(damage: int, is_weakness: bool = false):
    current_hp -= damage
    hp_changed.emit(current_hp, max_hp)  # 觸發信號
    # ↓
    # _on_hp_changed() 被調用
    # ↓
    # _update_hp_display() 更新顯示
```

### 使用 Soul Chip 復活時
```gdscript
func use_soul_chip() -> bool:
    if soul_chips > 0:
        current_hp = max_hp
        hp_changed.emit(current_hp, max_hp)  # 觸發信號
        # ↓ 自動更新顯示
        return true
```

## 單位 UI 佈局

```
        單位名稱 [24px]
            ↑
         單位圓形
        (半徑 30-35)
            ↓
       行動倒數 [32px]
       （僅敵人）
            ↓
    ████████████████  HP 血條 (80x10)
         800/1000     HP 數值 [16px]
```

## 敵人列表 HP 範圍

### Blue Slime（藍色史萊姆）
```
最大 HP: 800
血條: 800/800 (綠色)
```

### Green Goblin（綠色哥布林）
```
最大 HP: 1000
血條: 1000/1000 (綠色)
```

### Red Dragon（紅色龍）
```
最大 HP: 1200
血條: 1200/1200 (綠色)
```

### Black Shadow（黑影）
```
最大 HP: 900
血條: 900/900 (綠色)
```

### Gold Knight（金色騎士）
```
最大 HP: 1500 (最高!)
血條: 1500/1500 (綠色)
```

### Player Unit（玩家單位）
```
最大 HP: 1000
血條: 1000/1000 (綠色)
```

## 戰鬥中的 HP 變化示例

### 場景 1：玩家攻擊敵人
```
玩家撞擊 Blue Slime (800 HP)
造成 150 傷害

血條變化:
████████████  800/800 (綠色)
        ↓
██████████░░  650/800 (綠色 → 黃色)
```

### 場景 2：連續攻擊
```
初始: ████████████  800/800 (綠色)
-150: ██████████░░  650/800 (黃色)
-200: ███████░░░░░  450/800 (黃色)
-250: ███░░░░░░░░░  200/800 (紅色！)
-200: 死亡
```

### 場景 3：弱點攻擊
```
普通傷害: 100
弱點傷害: 150 (×1.5)

血條:
████████████  800/800 (綠色)
        ↓
█████████░░░  650/800 (黃色)

弱點提示: 黃色傷害浮字 + 額外傷害！
```

## 顏色閾值調整

如果想要調整血條顏色變化的時機：

### 更早變黃（更敏感）
```gdscript
if hp_percentage > 70:  # 從 60 改為 70
    hp_bar.modulate = Color.GREEN
elif hp_percentage > 40:  # 從 30 改為 40
    hp_bar.modulate = Color.YELLOW
else:
    hp_bar.modulate = Color.RED
```

### 更晚變紅（更寬容）
```gdscript
if hp_percentage > 50:
    hp_bar.modulate = Color.GREEN
elif hp_percentage > 20:  # 從 30 改為 20
    hp_bar.modulate = Color.YELLOW
else:
    hp_bar.modulate = Color.RED
```

### 三段變化（當前）
```gdscript
> 60%: 綠色 (健康)
30-60%: 黃色 (受傷)
< 30%: 紅色 (危險)
```

## 與其他系統的配合

### 1. 傷害浮字
```
敵人受傷時:
- HP 血條立即更新
- 同時顯示傷害浮字
- 雙重視覺反饋 ✓
```

### 2. 弱點系統
```
命中弱點時:
- HP 血條更新（更多傷害）
- 黃色傷害浮字
- 行動倒數 -1
```

### 3. 屬性相剋
```
2 倍傷害:
- HP 血條下降更快
- 視覺上更明顯
```

### 4. 死亡
```
HP 歸零時:
- 血條變空（紅色）
- 單位消失
- 觸發 1-More
```

## 修改的檔案

1. **scenes/Unit.tscn**
   - 新增 HPBar（ProgressBar）
   - 新增 HPLabel（Label）

2. **scenes/Enemy.tscn**
   - 新增 HPBar（ProgressBar）
   - 新增 HPLabel（Label）

3. **scripts/Unit.gd**
   - 新增 hp_bar 和 hp_label 引用
   - 新增 _on_hp_changed() 回調
   - 新增 _update_hp_display() 更新函數

4. **scripts/Enemy.gd**
   - 新增 hp_bar 和 hp_label 引用
   - 連接 hp_changed 信號
   - 繼承 Unit.gd 的更新邏輯

5. **HP_DISPLAY.md** - 完整的 HP 顯示文檔

## 使用體驗

### 修改前
```
問題:
- ❌ 看不到敵人 HP
- ❌ 不知道敵人還剩多少血
- ❌ 無法判斷何時能擊殺
- ❌ 缺乏戰鬥反饋
```

### 修改後
```
優點:
- ✅ 清楚看到所有單位 HP
- ✅ 血條顏色提示危險程度
- ✅ 數值顯示精確 HP
- ✅ 戰鬥反饋即時清晰
- ✅ 戰術判斷更準確
```

## 視覺範例

### 5 個敵人的 HP 顯示
```
  Blue Slime        Green Goblin
    ███████░░░          ██████████
     650/800            1000/1000
    (黃色)              (綠色)

  Red Dragon         Black Shadow
   ████████████         ███░░░░░░░
    1200/1200            200/900
    (綠色)               (紅色！)

               Gold Knight
              ███████████░
               1400/1500
                (綠色)
```

## 總結

**新增功能**：
- ✅ HP 血條（80x10 像素）
- ✅ HP 數值標籤（16px）
- ✅ 動態顏色變化（綠/黃/紅）
- ✅ 自動更新機制
- ✅ 玩家和敵人都有顯示

**血條特性**：
```
綠色 (> 60%): 健康
黃色 (30-60%): 受傷
紅色 (< 30%): 危險
```

**顯示格式**：
```
████████████  (血條)
  800/1000    (數值)
```

**現在可以清楚看到所有單位的 HP 狀態！**
