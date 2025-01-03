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
                Spacer()
                
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= mood.value ? "circle.fill" : "circle")
                        .foregroundColor(moodColor(value))
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
    
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red.opacity(0.8)
        case 2: return .orange.opacity(0.8)
        case 3: return .yellow.opacity(0.8)
        case 4: return .mint.opacity(0.8)
        case 5: return .blue.opacity(0.8)
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
        NavigationView {
            List {
                Section {
                    VStack(alignment: .center, spacing: 20) {
                        Text("今天心情如何？")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 20) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedValue = value
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: value == selectedValue ? "circle.fill" : "circle")
                                            .font(.system(size: 32))
                                            .foregroundStyle(moodColor(value))
                                            .symbolEffect(.bounce, value: selectedValue == value)
                                        
                                        Text(moodText(value))
                                            .font(.caption)
                                            .foregroundStyle(value == selectedValue ? moodColor(value) : .gray)
                                    }
                                    .frame(width: 50)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                Section {
                    TextField("添加备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(.vertical, 8)
                } header: {
                    Text("备注")
                } footer: {
                    Text("记录一下此刻的想法...")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("记录心情")
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
    
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red.opacity(0.8)
        case 2: return .orange.opacity(0.8)
        case 3: return .yellow.opacity(0.8)
        case 4: return .mint.opacity(0.8)
        case 5: return .blue.opacity(0.8)
        default: return .gray
        }
    }
}
