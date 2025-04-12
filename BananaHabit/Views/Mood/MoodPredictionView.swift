import SwiftUI
import SwiftData

// 注意：此文件需要手动修复导入错误
// 可能需要额外导入Mood和MoodPrediction类型

struct MoodPredictionView: View {
    let moods: [Mood]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("心情预测")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let prediction = MoodPrediction.predict(from: moods)
            
            if prediction.confidence == 0 {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.secondary)
                    Text("数据不足，无法预测")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 20) {
                    // 置信度指示器
                    HStack {
                        Text("预测准确率")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 显示置信度等级文本
                        Text(confidenceLevelText(prediction.confidence))
                            .font(.headline)
                            .foregroundColor(confidenceLevelColor(prediction.confidence))
                    }
                    
                    Divider()
                    
                    // 未来三天预测
                    HStack(spacing: 16) {
                        // 明天
                        futureDayView(
                            dayName: "明天",
                            score: prediction.day1Score,
                            dayIndex: 1
                        )
                        
                        // 后天
                        futureDayView(
                            dayName: "后天",
                            score: prediction.day2Score,
                            dayIndex: 2
                        )
                        
                        // 大后天
                        futureDayView(
                            dayName: "大后天",
                            score: prediction.day3Score,
                            dayIndex: 3
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // 将置信度转换为文字描述
    private func confidenceLevelText(_ confidence: Double) -> String {
        switch confidence {
        case 0.0..<0.2: return "很低"
        case 0.2..<0.4: return "低"
        case 0.4..<0.6: return "中等"
        case 0.6..<0.8: return "高"
        default: return "很高"
        }
    }
    
    // 根据置信度返回对应颜色
    private func confidenceLevelColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.0..<0.2: return .red
        case 0.2..<0.4: return .orange
        case 0.4..<0.6: return .yellow
        case 0.6..<0.8: return .mint
        default: return .blue
        }
    }
    
    private func futureDayView(dayName: String, score: Int, dayIndex: Int) -> some View {
        VStack(spacing: 8) {
            Text(dayName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Image(systemName: moodIcon(score))
                .font(.system(size: 28))
                .foregroundColor(moodColor(score))
            
            Text(moodText(score))
                .font(.caption)
                .foregroundColor(moodColor(score))
                .fontWeight(.medium)
            
            // 显示具体日期
            Text(formatDate(dayIndex))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(moodColor(score).opacity(0.1))
        )
    }
    
    private func formatDate(_ daysFromNow: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    private func moodText(_ value: Int) -> String {
        switch value {
        case 1: return "很差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "不错"
        case 5: return "很好"
        default: return ""
        }
    }
    
    private func moodIcon(_ value: Int) -> String {
        switch value {
        case 1: return "cloud.rain.fill"
        case 2: return "cloud.fill"
        case 3: return "cloud.sun.fill" 
        case 4: return "sun.min.fill"
        case 5: return "sun.max.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red.opacity(0.8)
        case 2: return .orange.opacity(0.8)
        case 3: return .yellow.opacity(0.8)
        case 4: return .mint.opacity(0.8)
        case 5: return .blue.opacity(0.8)
        default: return .gray.opacity(0.8)
        }
    }
}