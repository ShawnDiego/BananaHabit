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
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(moodColor(5))
                                    .frame(width: 8, height: 8)
                                Text("最高分")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(prediction.nextHighestDays)天后")
                                    .font(.title3)
                                    .foregroundColor(moodColor(5))
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(moodColor(1))
                                    .frame(width: 8, height: 8)
                                Text("最低分")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(prediction.nextLowestDays)天后")
                                    .font(.title3)
                                    .foregroundColor(moodColor(1))
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("准确率")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(Int(prediction.confidence * 100))%")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("CardBackground"))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
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

/* 
注意：此文件可能需要手动修复一些导入错误：
在Xcode中打开文件后，请确保项目能够正确引用Mood和MoodPrediction类型。
您可能需要额外导入包含这些类型的模块。
*/ 