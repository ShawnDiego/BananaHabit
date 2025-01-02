import SwiftUI
import SwiftData

struct MoodDisplayView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var mood: Mood
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= mood.value ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                Menu {
                    Button(action: { showingEdit = true }) {
                        Label("编辑", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
            
            if !mood.note.isEmpty {
                Text(mood.note)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingEdit) {
            MoodEditView(mood: mood)
        }
        .alert("删除记录", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteMood()
            }
        } message: {
            Text("确定要删除这条心情记录吗？")
        }
    }
    
    private func deleteMood() {
        if let item = mood.item {
            item.moods.removeAll { $0.id == mood.id }
        }
        modelContext.delete(mood)
        try? modelContext.save()
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
        NavigationView {
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
            .navigationTitle("编辑心情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        updateMood()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
