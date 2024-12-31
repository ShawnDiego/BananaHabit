import SwiftUI
import SwiftData

struct MoodInputView: View {
    @Bindable var item: Item
    let date: Date  // 添加日期参数
    @State private var selectedValue = 3
    @State private var note = ""
    @State private var showAlert = false
    @Environment(\.modelContext) private var modelContext
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 心情选择器
            HStack(spacing: 15) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        selectedValue = value
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: selectedValue == value ? "circle.fill" : "circle")
                                .foregroundColor(moodColor(value))
                                .font(.system(size: 24))
                            Text("\(value)分")
                                .font(.caption)
                                .foregroundColor(selectedValue == value ? moodColor(value) : .gray)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
            // 备注输入框
            TextField("添加备注（可选）", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3)
            
            // 提交按钮
            Button(action: submitMood) {
                Text("保存")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("心情已记录")
        }
    }
    
    private func submitMood() {
        // 检查是否已经存在当天的记录
        let startOfDay = calendar.startOfDay(for: date)
        if let existingMood = item.moods.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
            // 更新现有记录
            existingMood.value = selectedValue
            existingMood.note = note
            existingMood.date = date
        } else {
            // 创建新记录
            let mood = Mood(date: date, value: selectedValue, note: note, item: item)
            item.moods.append(mood)
        }
        
        // 保存更改
        try? modelContext.save()
        
        // 显示提示并重置输入
        showAlert = true
        note = ""
    }
    
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}
