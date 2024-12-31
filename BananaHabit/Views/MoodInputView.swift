import SwiftUI
import SwiftData

struct MoodInputView: View {
    @Bindable var item: Item
    let date: Date
    let onSave: () -> Void
    
    @State private var selectedValue = 0
    @State private var note = ""
    @State private var showAlert = false
    @State private var hasSelectedMood = false
    @Environment(\.modelContext) private var modelContext
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - 心情选择器
            HStack(spacing: 25) {
                Spacer()
                ForEach(1...5, id: \.self) { value in
                    Button {
                        selectedValue = value
                        hasSelectedMood = true
                        saveMood(note: "")  // 只保存心情值
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
                Spacer()
            }
            .padding(.vertical, 8)
            
            // MARK: - 备注输入区
            if hasSelectedMood {
                TextField("添加备注（可选）", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)
                    .onSubmit {
                        submitWithNote()
                    }
                
                Button(action: submitWithNote) {
                    Text("完成")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("心情已记录")
        }
    }
    
    // MARK: - 辅助方法
    private func saveMood(note: String) {
        let startOfDay = calendar.startOfDay(for: date)
        if let existingMood = item.moods.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
            existingMood.value = selectedValue
            existingMood.note = note
            existingMood.date = date
        } else {
            let mood = Mood(date: date, value: selectedValue, note: note, item: item)
            item.moods.append(mood)
        }
        try? modelContext.save()
    }
    
    private func submitWithNote() {
        saveMood(note: note)
        showAlert = true
        onSave()
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
