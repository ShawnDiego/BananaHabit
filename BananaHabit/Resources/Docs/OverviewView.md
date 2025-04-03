# OverviewView 组件文档

## 概述

`OverviewView` 是 BananaHabit 应用的主要概览页面，展示用户心情记录、统计数据和专注状态的综合信息。页面通过卡片式布局呈现多种不同类型的信息，使用户能够一目了然地了解自己的使用情况和心情变化。

## 功能组件

### 1. 用户信息头部 (`userProfileHeader`)

显示用户的基本信息，包括:
- 根据时间的问候语
- 用户名称
- 用户头像
- 点击头像可进入用户配置页面

### 2. 番茄钟状态 (`currentPomodoroStatus`)

当用户有正在进行中的番茄钟时显示，包含:
- 倒计时/正计时时间显示
- 当前状态（正计时/倒计时）
- 点击可直接跳转到专注页面

### 3. 事项选择器 (`itemSelector`)

横向滚动视图，显示所有用户创建的事项:
- 每个事项显示图标和名称
- 当前选中的事项有高亮效果
- 包含"添加事项"按钮

### 4. 今日心情卡片 (`TodayMoodView`)

展示当前选中事项的今日心情记录:
- 如果今天尚未记录，显示添加按钮
- 已记录则显示心情值和备注

### 5. 心情趋势图表 (`WeekMoodChart`)

使用 SwiftUI Charts 展示过去一周的心情变化趋势:
- 折线图展示心情变化
- 使用渐变色区域增强视觉效果
- 不同心情值对应不同颜色

### 6. 统计概览卡片 (`StatsOverviewCard`)

综合展示用户的各项统计数据:
- 心情统计:
  - 本周平均心情
  - 连续记录天数
- 专注统计:
  - 本周专注总时长
  - 完成番茄钟次数
- 日记统计:
  - 本周日记数量
  - 总日记数量
- 心情极值:
  - 最高心情记录
  - 最低心情记录

### 7. 空状态视图 (`emptyStateView`)

当用户尚未创建任何事项时显示:
- 引导用户创建第一个事项
- 展示应用功能预览，帮助用户了解应用功能

## 数据模型

`OverviewView` 使用 SwiftData 加载以下数据:
- `Item`: 事项数据，包含名称、图标和心情记录
- `Diary`: 日记数据
- `PomodoroRecord`: 番茄钟记录，包含时长和完成状态

## 抽象组件

为提高代码可维护性，以下组件被抽离为独立模块:

1. **MoodVisualization.swift**
   - `WeekMoodChart`: 周心情图表组件
   - `TodayMoodView`: 今日心情视图
   - `MoodExtremeView`: 心情极值显示组件
   - `QuickMoodRow`: 快速心情输入行
   - `TodayMoodSummaryView`: 今日心情汇总视图

2. **MoodUtils.swift**
   - 提供心情相关的工具函数
   - 统一心情颜色处理
   - 心情文本映射
   - 日期格式化函数

3. **StatComponents.swift**
   - `StatItemView`: 统计项显示组件
   - `StatsOverviewCard`: 统计概览卡片

## 使用示例

```swift
OverviewView()
    .modelContainer(for: Item.self, inMemory: true)
```

## 注意事项

1. 首次进入页面时自动选择第一个事项
2. 心情记录仅展示当天已记录的内容
3. 统计数据以自然周为单位计算
4. 连续记录天数从当天开始向前计算 