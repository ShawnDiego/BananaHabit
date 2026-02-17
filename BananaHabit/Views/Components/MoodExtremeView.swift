import SwiftUI

struct MoodExtremeView: View {
    let title: String
    let date: Date
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= value ? color : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(formatDate(date))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 添加私有的格式化日期函数，避免依赖MoodUtils
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
} 