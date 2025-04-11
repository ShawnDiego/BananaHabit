import SwiftUI
import SwiftData

/* 
 * MoodUtils - 统一的心情相关工具函数
 * 
 * 用法说明：
 * 1. 将此文件导入到需要使用的地方，例如 import BananaHabit (或其他模块名)
 * 2. 将原来在各个视图中的重复方法替换为MoodUtils.xxx静态方法
 * 3. 如果遇到导入错误，可能需要调整项目结构或导入语句
 *
 * 主要功能：
 * - 心情颜色获取 (moodColor)
 * - 心情文本描述 (moodText)
 * - 心情图标获取 (moodIcon)
 * - 根据日期获取心情 (getMood)
 * - 日期格式化 (formatDate/formatDateFull)
 *
 * 在使用此工具类时可能需要进行以下调整：
 *
 * 1. 确保您的文件中已导入SwiftUI和SwiftData
 * 2. 如果遇到Item和Mood类型无法识别的问题，请在该文件顶部添加导入语句
 * 3. 从其他文件中移除重复的方法，改为调用MoodUtils中的方法
 * 
 * 示例使用方法：
 * - 获取心情颜色: MoodUtils.moodColor(5)
 * - 格式化日期: MoodUtils.formatDateFull(date)
 * - 获取心情: let mood = MoodUtils.getMood(for: item, on: date)
 */

// 心情相关工具函数
public struct MoodUtils {
    // 心情颜色
    public static func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red.opacity(0.8)
        case 2: return .orange.opacity(0.8)
        case 3: return .yellow.opacity(0.8)
        case 4: return .mint.opacity(0.8)
        case 5: return .blue.opacity(0.8)
        default: return .gray.opacity(0.8)
        }
    }
    
    public static func moodColor(_ value: Double) -> Color {
        moodColor(Int(round(value)))
    }
    
    // 心情文本描述
    public static func moodText(_ value: Int) -> String {
        switch value {
        case 1: return "很差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "不错"
        case 5: return "很好"
        default: return ""
        }
    }
    
    // 心情图标
    public static func moodIcon(_ value: Int) -> String {
        switch value {
        case 1: return "cloud.rain.fill" // 很差
        case 2: return "cloud.fill"       // 较差
        case 3: return "cloud.sun.fill"   // 一般
        case 4: return "sun.max.fill"     // 不错
        case 5: return "sun.max.fill"     // 很好
        default: return "circle.fill"
        }
    }
    
    // 根据日期查找心情记录 - 使用internal访问级别以匹配Mood类型
    static func getMood(for date: Date, in moods: [Mood]) -> Mood? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return moods.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }
    }
    
    // 根据日期查找某个项目的心情记录 - 使用internal访问级别以匹配Item和Mood类型
    static func getMood(for item: Item, on date: Date) -> Mood? {
        let calendar = Calendar.current
        return item.moods.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    // 日期相关工具函数
    public static func formatDate(_ date: Date, format: String = "M月d日") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    // 使用SwiftUI的格式化方式
    public static func formatDateFull(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().weekday())
    }
}

// 时间相关工具函数
public func timeString(from timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

/*
 * 在使用此工具类时可能需要进行以下调整：
 *
 * 1. 确保您的文件中已导入SwiftUI和SwiftData
 * 2. 如果遇到Item和Mood类型无法识别的问题，请在该文件顶部添加导入语句
 * 3. 从其他文件中移除重复的方法，改为调用MoodUtils中的方法
 * 
 * 示例使用方法：
 * - 获取心情颜色: MoodUtils.moodColor(5)
 * - 格式化日期: MoodUtils.formatDateFull(date)
 * - 获取心情: let mood = MoodUtils.getMood(for: item, on: date)
 */

/*
注意：由于Swift的模块导入规则，您需要在使用此工具类的文件中添加以下代码：

1. 确保您的文件中已导入SwiftUI和SwiftData
2. 如果遇到Item和Mood类型无法识别的问题，请确保这些类型在该文件中可访问
*/ 
