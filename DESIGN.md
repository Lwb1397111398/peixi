# DESIGN.md — 陪析设计系统

> 视觉规格的唯一来源。代码中的落地位置：`lib/core/theme/tokens.dart` 与 `lib/core/theme/app_theme.dart`。

## 1. 色彩

策略：**Restrained**——带绿相倾向的中性色承载全部表面，鼠尾草绿主色只用于
关键操作、选中态、进度；语义色仅表达状态。

### 主色（鼠尾草绿）

| 角色 | 浅色 | 深色 |
|---|---|---|
| seed | `#5E7F63` | `#5E7F63` |
| primary | `#426B4B` | `#A5CFA4` |
| onPrimary | `#FFFFFF`(近白) | `#11290F` |
| primaryContainer | `#CDE9C9` | `#2C4A2D` |
| onPrimaryContainer | `#072112` | `#CDE9C9` |

具体值以 `ColorScheme.fromSeed` 生成后 copyWith 覆盖 surface 系为准。

### 表面（暖白纸感，浅色主题）

| 角色 | 值 | 用途 |
|---|---|---|
| surface | `#F9F8F2` | 页面底色（暖纸白） |
| surfaceContainerLowest | `#FEFDFA` | 卡片、对话框底 |
| surfaceContainerLow | `#F3F2EA` | 输入框填充 |
| surfaceContainer | `#EDECE3` | 徽章、chip 底 |
| surfaceContainerHigh | `#E7E6DC` | hover 态 |
| onSurface | `#1B1C18` | 主文本（墨绿黑，非纯黑） |
| onSurfaceVariant | `#43483E` | 次要文本 |
| outline | `#74796C` | 图标次级 |
| outlineVariant | `#D5D6CA` | 分隔线、卡片描边 |

深色主题对应：surface `#131510`，容器 `#1C1F19`→`#2B2F27` 递进，
onSurface `#E2E3DA`。全部由 fromSeed(dark) + copyWith 覆盖。

### 语义色（token，全局唯一）

| 语义 | 浅色 | 深色 | 用途 |
|---|---|---|---|
| success | `#3E7D46` | `#93D095` | 可观看/可阅读、完成阶段、答对 |
| warning | `#9A6A00` | `#E9C368` | 待校准、不确定、预算提醒 |
| error | `#BA3A2B` | `#F2A79B` | 失败、删除 |
| info | `#3A6D93` | `#96CCEA` | 处理中、提示 |

## 2. 字体

系统字体栈，零内嵌：`Microsoft YaHei UI` → `Microsoft YaHei` → `PingFang SC` → `Segoe UI`。
不使用 display 字体；层次靠字号+字重（600/500/400）。

| 样式 | 字号/行高 | 字重 | 用途 |
|---|---|---|---|
| headlineSmall | 22/1.25 | 600 | 页头大标题 |
| titleLarge | 17/1.4 | 600 | 区块标题、对话框标题 |
| titleMedium | 14.5/1.4 | 600 | 卡片标题、列表主文本 |
| titleSmall | 12.5/1.4 | 600 | 列表次要标题、标签 |
| bodyLarge | 14.5/1.6 | 400 | 正文、解说内容 |
| bodyMedium | 13/1.55 | 400 | 次要正文 |
| bodySmall | 11.5/1.45 | 400 | 辅助说明、时间戳 |
| labelLarge | 13/1.2 | 600 | 按钮 |
| labelMedium | 11/1.25 | 600 | 徽章、chip |

## 3. 几何

- **间距节奏**：4 / 8 / 12 / 16 / 24 / 32（xs/s/m/l/xl/xxl），页面留白 xl~xxl，卡片内 l~xl。
- **圆角**：小 8（chip、徽章、输入内件），中 12（按钮、卡片、输入框），大 16（对话框、底部面板）。
- **卡片**：elevation 恒为 0，`surfaceContainerLowest` 底 + 1px `outlineVariant` 描边（浅色）；
  深色主题去描边，靠容器色阶分层。禁止嵌套卡片。
- **断点**：`kTwoPaneBreakpoint = 900`（播放器双栏、rail 收缩判定共用）。

## 4. 组件规范

- **AppBadge**：语义色胶囊（container 底 + on 色 11/600 字），圆角 full。
- **EmptyState**：轮廓图标（40px，outline 色）+ 标题（titleMedium）+ 一句引导（bodySmall）+ 可选主操作按钮；居中，留白 xl。
- **LoadingView**：居中进度圈；长列表用骨架占位。
- **SheetScaffold**：拖拽柄 + 标题行 + 关闭按钮，圆角 16，背景 surfaceContainerLowest。
- **页面头**（rail 内 4 页通用）：headlineSmall 标题 + bodySmall 副标题 + 右侧动作行，不做传统 AppBar。
- **SnackBar**：floating，圆角 12，inverseSurface 底。
- **按钮**：Filled=主操作（绿），Outlined=次操作，TextButton=行内；禁用态统一 38% 透明。

## 5. 动效

- 时长：150ms（hover/微反馈）、200ms（展开/切换）、250ms（页面级）。
- 曲线：easeOutCubic 系；无弹跳、无弹性、无装饰动画。
- 播放器场景进度条等自绘组件维持自身语境（恒深色面）。

## 6. 绝对禁止

- 纯 `#000` / `#FFF`；左边条彩条；渐变文字；玻璃拟态；
- hero-metric 模板（大数字+小标签+渐变）；同尺寸卡片矩阵复读；
- 语义色裸用 `Colors.green/orange/red/blue`（必须走 token）；
- 嵌套卡片；装饰性动画。

## 7. 特殊语境

- **播放器**：视频区/进度条/弹题遮罩恒定深色面，不随主题切换。
- **阅读器**：paper/sepia/night 三种用户可选书页主题保留，色值向本系统色相靠拢；
  阅读器是"暗壳里的纸页"，页面底色用书页主题而非全局 surface。
- **角色色板**：校准页 8 色调色板的 hex 值已持久化进数据库，值不可改，只允许外观升级。
