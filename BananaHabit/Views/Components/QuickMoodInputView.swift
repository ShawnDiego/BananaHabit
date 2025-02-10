import SwiftUI
import SwiftData

struct QuickMoodInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var selectedValue = 3
    @State private var note = ""
    @State private var selectedItemId: PersistentIdentifier?
    @State private var selectedDate = Date()
    
    let preSelectedItem: Item?
    
    init(preSelectedItem: Item? = nil) {
        self.preSelectedItem = preSelectedItem
        
        if let item = preSelectedItem,
           let todayMood = item.moods.first(where: { Calendar.current.isDateInToday($0.date) }) {
            _selectedValue = State(initialValue: todayMood.value)
            _note = State(initialValue: todayMood.note)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if preSelectedItem == nil {
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("选择事项")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(items) { item in
                                            Button {
                                                selectedItemId = item.persistentModelID
                                            } label: {
                                                VStack(spacing: 8) {
                                                    ItemIconView(
                                                        icon: item.icon,
                                                        size: 32,
                                                        color: selectedItemId == item.persistentModelID ? .blue : .gray
                                                    )
                                                    Text(item.name)
                                                        .font(.subheadline)
                                                        .foregroundColor(selectedItemId == item.persistentModelID ? .primary : .secondary)
                                                }
                                                .frame(width: 80, height: 80)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(selectedItemId == item.persistentModelID ? 
                                                            Color.blue.opacity(0.1) : 
                                                            Color(.tertiarySystemBackground))
                                                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        NavigationLink {
                                            AddItemView()
                                        } label: {
                                            VStack(spacing: 8) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.blue)
                                                Text("添加事项")
                                                    .font(.subheadline)
                                                    .foregroundColor(.blue)
                                            }
                                            .frame(width: 80, height: 80)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.blue.opacity(0.05))
                                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(Calendar.current.isDateInToday(selectedDate) ? "今天心情如何？" : "这天心情如何？")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 24) {
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
                                            .font(.subheadline)
                                            .foregroundStyle(value == selectedValue ? moodColor(value) : .gray)
                                    }
                                    .frame(width: 50)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.tertiarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker("选择日期", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(.blue)
                            .padding(.vertical, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.tertiarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("添加备注")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("记录一下此刻的想法...", text: $note, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                            .padding(.vertical, 8)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.tertiarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let preSelectedItem = preSelectedItem {
                        HStack(spacing: 8) {
                            ItemIconView(icon: preSelectedItem.icon, size: 24, color: .blue)
                            Text(preSelectedItem.name)
                                .font(.headline)
                        }
                    } else if let selectedItemId = selectedItemId,
                              let selectedItem = items.first(where: { $0.persistentModelID == selectedItemId }) {
                        HStack(spacing: 8) {
                            ItemIconView(icon: selectedItem.icon, size: 24, color: .blue)
                            Text(selectedItem.name)
                                .font(.headline)
                        }
                    } else {
                        Text("记录心情")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveMood()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if preSelectedItem != nil {
                    selectedItemId = preSelectedItem!.persistentModelID
                } else if let firstItem = items.first {
                    selectedItemId = firstItem.persistentModelID
                }
            }
        }
    }
    
    private func saveMood() {
        let targetItem: Item
        if let preSelectedItem = preSelectedItem {
            targetItem = preSelectedItem
        } else {
            guard let selectedItemId = selectedItemId,
                  let selectedItem = items.first(where: { $0.persistentModelID == selectedItemId }) else {
                let newItem = Item(name: "默认事项", icon: "star.fill")
                let mood = Mood(date: selectedDate, value: selectedValue, note: note, item: newItem)
                newItem.moods.append(mood)
                modelContext.insert(newItem)
                try? modelContext.save()
                return
            }
            targetItem = selectedItem
        }
        
        let calendar = Calendar.current
        if let existingMood = targetItem.moods.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) {
            existingMood.value = selectedValue
            existingMood.note = note
            existingMood.date = selectedDate
        } else {
            let mood = Mood(date: selectedDate, value: selectedValue, note: note, item: targetItem)
            targetItem.moods.append(mood)
        }
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

#Preview {
    QuickMoodInputView()
        .modelContainer(for: Item.self, inMemory: true)
} 