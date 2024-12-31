import SwiftUI
import SwiftData

struct MoodDisplayView: View {
    let mood: Mood
    @State private var isEditing = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(moodColor(mood.value))
                    Text("\(mood.value)分")
                        .foregroundColor(moodColor(mood.value))
                        .font(.headline)
                }
                
                Spacer()
                
                // 编辑按钮
                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            
            if !mood.note.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("备注")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(mood.note)
                        .font(.body)
                }
            }
            
            Text(mood.date.formatted(.dateTime.year().month().day().hour().minute()))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                MoodEditView(mood: mood)
                    .navigationTitle("修改心情")
//                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
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

// 添加编辑视图
struct MoodEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let mood: Mood
    
    @State private var selectedValue: Int
    @State private var note: String
    
    init(mood: Mood) {
        self.mood = mood
        _selectedValue = State(initialValue: mood.value)
        _note = State(initialValue: mood.note)
    }
    
    var body: some View {
        Form {
            Section("心情评分") {
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
            }
            
            Section("备注") {
                TextField("添加备注（可选）", text: $note, axis: .vertical)
                    .lineLimit(3)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    updateMood()
                    dismiss()
                }
            }
        }
    }
    
    private func updateMood() {
        mood.value = selectedValue
        mood.note = note
        try? modelContext.save()
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
