import SwiftUI
import SwiftData

struct QuickMoodInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var selectedValue = 3
    @State private var note = ""
    @State private var selectedItemId: PersistentIdentifier?
    
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
            VStack(spacing: 20) {
                if preSelectedItem == nil {
                    if !items.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(items) { item in
                                    Button {
                                        selectedItemId = item.persistentModelID
                                    } label: {
                                        VStack(spacing: 6) {
                                            ItemIconView(
                                                icon: item.icon,
                                                size: 24,
                                                color: selectedItemId == item.persistentModelID ? .blue : .gray
                                            )
                                            Text(item.name)
                                                .font(.subheadline)
                                        }
                                        .frame(width: 80, height: 80)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedItemId == item.persistentModelID ? 
                                                    Color.blue.opacity(0.1) : 
                                                    Color(.systemBackground))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(selectedItemId == item.persistentModelID ? 
                                                            Color.blue : Color.gray.opacity(0.2),
                                                            lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                NavigationLink {
                                    AddItemView()
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                        Text("添加事项")
                                            .font(.subheadline)
                                    }
                                    .frame(width: 80, height: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    HStack {
                        ItemIconView(icon: preSelectedItem!.icon, size: 24)
                        Text(preSelectedItem!.name)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                Text("今天心情如何？")
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                .padding(.vertical, 20)
                
                TextField("添加备注（可选）", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                let mood = Mood(date: Date(), value: selectedValue, note: note, item: newItem)
                newItem.moods.append(mood)
                modelContext.insert(newItem)
                try? modelContext.save()
                return
            }
            targetItem = selectedItem
        }
        
        if let existingMood = targetItem.moods.first(where: { Calendar.current.isDateInToday($0.date) }) {
            existingMood.value = selectedValue
            existingMood.note = note
        } else {
            let mood = Mood(date: Date(), value: selectedValue, note: note, item: targetItem)
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