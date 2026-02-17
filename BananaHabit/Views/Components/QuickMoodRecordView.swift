import SwiftUI
import SwiftData

// MARK: - 今日心情显示视图
struct TodayMoodView: View {
    let item: Item
    
    var body: some View {
        if let mood = item.moods.first(where: { Calendar.current.isDateInToday($0.date) }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日心情")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { value in
                            Circle()
                                .fill(value <= mood.value ? MoodUtils.moodColor(Double(mood.value)) : Color.gray.opacity(0.3))
                                .frame(width: 16, height: 16)
                        }
                    }
                    
                    if !mood.note.isEmpty {
                        Text(mood.note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Text(MoodUtils.moodText(mood.value))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(MoodUtils.moodColor(Double(mood.value)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 5)
            )
            .frame(height: 120)
            .padding(.horizontal)
        } else {
            EmptyView()
        }
    }
}

// MARK: - 添加心情按钮
struct AddMoodButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("记录今天的心情")
                    .font(.headline)
                
                Text("每日记录帮助你更好地了解自己")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.tertiarySystemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - 快速心情输入行
struct QuickMoodRow: View {
    @Bindable var item: Item
    @State private var showingNote = false
    @State private var note: String = ""
    @State private var currentValue: Int
    
    init(item: Item) {
        self.item = item
        let initialValue = item.moods.first { Calendar.current.isDateInToday($0.date) }?.value ?? 0
        _currentValue = State(initialValue: initialValue)
        _note = State(initialValue: item.moods.first { Calendar.current.isDateInToday($0.date) }?.note ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= currentValue ? "circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(MoodUtils.moodColor(value))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                currentValue = value
                                updateMood(value: value)
                            }
                        }
                }
            }
            
            if currentValue > 0 {
                HStack {
                    Text("备注:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if note.isEmpty {
                        Button("添加备注") {
                            showingNote = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    } else {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .onTapGesture {
                                showingNote = true
                            }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .padding(.horizontal)
        .sheet(isPresented: $showingNote) {
            NavigationView {
                Form {
                    Section("添加备注") {
                        TextField("今天的感受...", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .navigationTitle("心情备注")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            note = getTodayMood()?.note ?? ""
                            showingNote = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if let mood = getTodayMood() {
                                mood.note = note
                            }
                            showingNote = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func getTodayMood() -> Mood? {
        let calendar = Calendar.current
        return item.moods.first { calendar.isDateInToday($0.date) }
    }
    
    private func updateMood(value: Int) {
        let calendar = Calendar.current
        if let existingMood = item.moods.first(where: { calendar.isDateInToday($0.date) }) {
            existingMood.value = value
        } else {
            let newMood = Mood(date: Date(), value: value, note: "", item: item)
            item.moods.append(newMood)
        }
    }
    

}

// MARK: - 今日心情汇总视图
struct TodayMoodSummaryView: View {
    let items: [Item]
    @State private var showingMoodInput = false
    @State private var selectedItemId: PersistentIdentifier?
    
    var todayMoods: [(Item, Mood)] {
        let calendar = Calendar.current
        return items.compactMap { item in
            if let mood = item.moods.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
                return (item, mood)
            }
            return nil
        }
    }
    
    var itemsWithoutMood: [Item] {
        let calendar = Calendar.current
        return items.filter { item in
            !item.moods.contains { calendar.isDate($0.date, inSameDayAs: Date()) }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 事项选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            selectedItemId = item.persistentModelID
                            showingMoodInput = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 24))
                                    .foregroundStyle(hasMoodToday(item) ? .blue : .gray)
                                Text(item.name)
                                    .font(.subheadline)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            // 已记录的心情
            ForEach(todayMoods, id: \.0.persistentModelID) { item, mood in
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        ItemIconView(icon: item.icon, size: 32, color: .blue)
                        Text(item.name)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button {
                            selectedItemId = item.persistentModelID
                            showingMoodInput = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        ForEach(1...5, id: \.self) { value in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(value <= mood.value ? MoodUtils.moodColor(mood.value) : Color.gray.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                        }
                        
                        Spacer()
                        
                        Text(MoodUtils.moodText(mood.value))
                            .font(.headline)
                            .foregroundColor(MoodUtils.moodColor(mood.value))
                    }
                    
                    if !mood.note.isEmpty {
                        Text(mood.note)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 10)
                )
            }
            
            // 待记录事项
            if !itemsWithoutMood.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("待记录事项")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ForEach(itemsWithoutMood) { item in
                        Button {
                            selectedItemId = item.persistentModelID
                            showingMoodInput = true
                        } label: {
                            HStack {
                                ItemIconView(icon: item.icon, color: .gray)
                                Text(item.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingMoodInput) {
            if let selectedItemId = selectedItemId,
               let selectedItem = items.first(where: { $0.persistentModelID == selectedItemId }) {
                QuickMoodInputView(preSelectedItem: selectedItem)
            }
        }
    }
    
    private func hasMoodToday(_ item: Item) -> Bool {
        let calendar = Calendar.current
        return item.moods.contains { calendar.isDateInToday($0.date) }
    }
    

}