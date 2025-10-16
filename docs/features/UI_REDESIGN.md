# UI 介面美化

## 設計目標

- ✅ 隊伍欄位放在左上角
- ✅ 使用面板容器增加層次感
- ✅ 添加圖示美化顯示
- ✅ 優化間距和佈局
- ✅ 改善視覺層次

## 新佈局設計

```
┌─────────────────────────────────────────────────┐
│  ┌─────────┐      ┌──────────┐      ┌────────┐ │
│  │ 💠 TEAM │      │ Turn: 1  │      │📊 INFO │ │
│  │─────────│      └──────────┘      │────────│ │
│  │👑 Leader│                         │Enemy1  │ │
│  │⚔️ Front1│                         │  3     │ │
│  │⚔️ Front2│                         │Enemy2  │ │
│  │💤Standby│                         │  4     │ │
│  │🤝 Friend│                         │...     │ │
│  │─────────│                         └────────┘ │
│  │⚡ SKILL │                                     │
│  │ ■ ■ ■ □ □│                                    │
│  └─────────┘                                     │
│                                                   │
│                 戰場區域                          │
│                                                   │
└─────────────────────────────────────────────────┘
```

## UI 元件佈局

### 左上角：隊伍面板（TopLeftPanel）
```
位置: (10, 10)
大小: 250 x 340
內容:
  - 💠 TEAM 標題 [28px]
  - 5 個隊伍成員位置
  - ⚡ SKILL GAUGE 標題 [24px]
  - 5 個技能量表方塊
```

### 上方中央：回合面板（TopCenterPanel）
```
位置: (450, 10)
大小: 250 x 90
內容:
  - Turn: X [48px]
```

### 右上角：敵人資訊面板（TopRightPanel）
```
位置: (890, 10)
大小: 250 x 440
內容:
  - 📊 ENEMIES 標題 [24px]
  - 敵人列表（動態生成）
```

## 美化元素

### 1. PanelContainer（面板容器）
```
作用: 為 UI 元件添加背景和邊框
效果:
  - 半透明深色背景
  - 自動邊距
  - 層次感提升
```

### 2. MarginContainer（邊距容器）
```
作用: 內部元件的邊距
數值:
  - 左右: 15px
  - 上下: 15px
效果: 內容不會貼邊，更美觀
```

### 3. HSeparator（分隔線）
```
作用: 分隔隊伍和技能量表
效果: 視覺分組更清晰
```

### 4. 圖示（Emoji）
```
隊伍成員:
  👑 Leader   - 領導者
  ⚔️ Front-1  - 前鋒 1
  ⚔️ Front-2  - 前鋒 2
  💤 Standby  - 待機
  🤝 Friend   - 好友

面板標題:
  💠 TEAM     - 隊伍面板
  ⚡ SKILL GAUGE - 技能量表
  📊 ENEMIES  - 敵人資訊
```

## 技能量表設計

### 修改前
```
■ ■ ■ ■ ■  (60x60 的方塊，直接排列)
```

### 修改後
```
┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
│■│ │■│ │■│ │□│ │□│  (35x35 的方塊，有面板包裹)
└─┘ └─┘ └─┘ └─┘ └─┘

顏色:
  已充能: 金色 (1.0, 0.84, 0.0)
  未充能: 深灰 (0.2, 0.2, 0.2, 0.8)
```

## 隊伍成員顯示

### 修改前
```
Leader
Front-1
Front-2
Standby
Friend
```

### 修改後
```
┌──────────────┐
│ 👑 Leader    │
└──────────────┘
┌──────────────┐
│ ⚔️ Front-1   │
└──────────────┘
┌──────────────┐
│ ⚔️ Front-2   │
└──────────────┘
┌──────────────┐
│ 💤 Standby   │
└──────────────┘
┌──────────────┐
│ 🤝 Friend    │
└──────────────┘

每個成員都有獨立的面板
字體大小: 18px
內邊距: 8px (左右), 5px (上下)
```

## 顏色方案

### 背景色
```
面板背景: 半透明深色（自動）
分隔線: 預設灰色
```

### 技能量表
```
已充能: Color(1.0, 0.84, 0.0, 1.0)  # 金色
未充能: Color(0.2, 0.2, 0.2, 0.8)  # 深灰色半透明
```

### 文字顏色
```
標題: 預設白色
成員名稱: 預設白色
Turn 標籤: 預設白色
```

## 節點層次結構

```
BattleUI (CanvasLayer)
├── TopLeftPanel (PanelContainer)
│   └── MarginContainer
│       └── VBoxContainer
│           ├── TeamTitle (Label) "💠 TEAM"
│           ├── TeamDisplay (VBoxContainer)
│           │   ├── Member1 (PanelContainer → Label) "👑 Leader"
│           │   ├── Member2 (PanelContainer → Label) "⚔️ Front-1"
│           │   ├── Member3 (PanelContainer → Label) "⚔️ Front-2"
│           │   ├── Member4 (PanelContainer → Label) "💤 Standby"
│           │   └── Member5 (PanelContainer → Label) "🤝 Friend"
│           ├── Separator (HSeparator)
│           ├── SkillTitle (Label) "⚡ SKILL GAUGE"
│           └── SkillGaugeContainer (HBoxContainer)
│               ├── Segment1 (PanelContainer → ColorRect)
│               ├── Segment2 (PanelContainer → ColorRect)
│               ├── Segment3 (PanelContainer → ColorRect)
│               ├── Segment4 (PanelContainer → ColorRect)
│               └── Segment5 (PanelContainer → ColorRect)
│
├── TopCenterPanel (PanelContainer)
│   └── MarginContainer
│       └── TurnLabel (Label) "Turn: 1"
│
└── TopRightPanel (PanelContainer)
    └── MarginContainer
        └── DebugPanel (VBoxContainer)
            ├── DebugLabel (Label) "📊 ENEMIES"
            └── [動態生成的敵人資訊]
```

## 間距設定

### VBoxContainer 間距
```
隊伍面板主容器: 15px
隊伍成員顯示: 8px
技能量表: 8px
敵人資訊: 5px
```

### MarginContainer 邊距
```
所有面板:
  左: 15px
  右: 15px
  上: 15px (或 10px)
  下: 15px (或 10px)

隊伍成員內部:
  左: 8px
  右: 8px
  上: 5px
  下: 5px
```

## 尺寸規格

### 面板大小
```
左上面板 (TopLeftPanel):
  寬度: 250px
  高度: 340px (自適應內容)

上中面板 (TopCenterPanel):
  寬度: 250px
  高度: 90px

右上面板 (TopRightPanel):
  寬度: 250px
  高度: 440px
```

### 元件大小
```
技能量表方塊: 35x35px
隊伍成員面板: 自動寬度 x 自動高度
```

## 字體大小

```
💠 TEAM 標題: 28px
⚡ SKILL GAUGE 標題: 24px
📊 ENEMIES 標題: 24px
Turn 標籤: 48px
隊伍成員: 18px
敵人資訊: 20px
```

## 對比效果

### 修改前
```
簡陋佈局:
- 元件直接放置，沒有背景
- 沒有分組和層次
- 位置分散，不美觀
- 純文字，單調
```

### 修改後
```
美化佈局:
- ✅ PanelContainer 提供背景
- ✅ 清晰的視覺分組
- ✅ 統一的左上角位置
- ✅ 圖示增加趣味性
- ✅ 面板有層次感
```

## 修改的檔案

1. **scenes/BattleUI.tscn**
   - 重新設計節點結構
   - 添加 PanelContainer
   - 添加 MarginContainer
   - 調整所有位置和大小

2. **scripts/BattleUI.gd**
   - 更新節點引用路徑
   - 美化技能量表創建邏輯
   - 美化隊伍成員顯示
   - 添加圖示

3. **UI_REDESIGN.md** - 完整的 UI 設計文檔

## 視覺改善

### 層次感
```
修改前: 平面 (1 層)
修改後: 立體 (3 層)
  - 背景層（戰場）
  - 面板層（PanelContainer）
  - 內容層（文字、圖示）
```

### 可讀性
```
修改前: 元件太小，間距不足
修改後:
  - 適當間距 (8-15px)
  - 分組清晰
  - 圖示輔助識別
```

### 專業度
```
修改前: 簡陋的測試 UI
修改後:
  - 統一的設計語言
  - 專業的面板佈局
  - 精心設計的間距
```

## 響應式設計

雖然目前是固定尺寸，但設計已經考慮到：
- 面板可以獨立調整
- 內容自適應面板大小
- 容易擴展新元件

## 未來改進空間

### 可選的美化方向
```
1. 添加陰影效果
2. 漸變背景色
3. 動畫過渡效果
4. 更多圖示和裝飾
5. 主題顏色系統
6. HP 條整合到隊伍顯示
```

## 總結

**美化效果**：
- ✅ 隊伍面板移至左上角
- ✅ 所有 UI 元件使用面板容器
- ✅ 添加圖示提升視覺效果
- ✅ 統一的間距和佈局
- ✅ 清晰的資訊分組
- ✅ 專業的視覺層次

**介面佈局**：
```
左上: 💠 隊伍 + ⚡ 技能量表
上中: 🔄 回合數
右上: 📊 敵人資訊
中央: 戰場
```

**現在介面更美觀、更專業、更易讀！**
