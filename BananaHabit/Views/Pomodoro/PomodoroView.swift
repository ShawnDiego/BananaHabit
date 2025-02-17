import SwiftUI
import SwiftData

struct PomodoroView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query(sort: \PomodoroRecord.startTime, order: .reverse) private var records: [PomodoroRecord]
    
    @State private var selectedItem: Item?
    @State private var showingItemPicker = false
    @State private var note: String = ""
    @State private var timeRemaining: TimeInterval = 25 * 60  // 默认25分钟
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var showingCompletionAlert = false
    @State private var startTime: Date?
    @State private var targetDuration: TimeInterval = 25 * 60
    @State private var showingResumeAlert = false
    
    // 时间选项
    let timeOptions: [(String, TimeInterval)] = [
        ("15分钟", 15 * 60),
        ("25分钟", 25 * 60),
        ("30分钟", 30 * 60),
        ("45分钟", 45 * 60),
        ("60分钟", 60 * 60)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 时间选择器
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(timeOptions, id: \.1) { option in
                                Button {
                                    if !isRunning {
                                        targetDuration = option.1
                                        timeRemaining = option.1
                                    }
                                } label: {
                                    Text(option.0)
                                        .font(.headline)
                                        .foregroundColor(targetDuration == option.1 ? .white : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(targetDuration == option.1 ? Color.blue : Color(.tertiarySystemBackground))
                                        )
                                }
                                .disabled(isRunning)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 计时器显示
                    VStack(spacing: 32) {
                        ZStack {
                            // 进度环
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                                .frame(width: 280, height: 280)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(1 - (timeRemaining / targetDuration)))
                                .stroke(
                                    Color.blue,
                                    style: StrokeStyle(
                                        lineWidth: 20,
                                        lineCap: .round
                                    )
                                )
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: timeRemaining)
                            
                            VStack(spacing: 8) {
                                Text(timeString(from: timeRemaining))
                                    .font(.system(size: 60, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                
                                if let item = selectedItem {
                                    HStack {
                                        Image(systemName: item.icon)
                                        Text(item.name)
                                    }
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // 控制按钮
                        HStack(spacing: 40) {
                            Button {
                                resetTimer()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(Circle())
                            }
                            
                            Button {
                                if isRunning {
                                    pauseTimer()
                                } else {
                                    startTimer()
                                }
                            } label: {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 80, height: 80)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            
                            Button {
                                showingItemPicker = true
                            } label: {
                                Image(systemName: "tag")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal)
                    // .background(
                    //     RoundedRectangle(cornerRadius: 24)
                    //         .fill(Color(.systemBackground))
                    // )
                    .padding(.horizontal)
                    
                    // 今日记录
                    VStack(alignment: .leading, spacing: 16) {
                        Text("今日记录")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if let todayRecords = getTodayRecords() {
                            ForEach(todayRecords) { record in
                                PomodoroRecordRow(record: record)
                            }
                        } else {
                            Text("今天还没有专注记录")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("专注")
            .sheet(isPresented: $showingItemPicker) {
                ItemPickerSheet(selectedItem: $selectedItem, items: items, isPresented: $showingItemPicker)
            }
            .alert("专注完成", isPresented: $showingCompletionAlert) {
                TextField("添加备注", text: $note)
                Button("保存") {
                    saveRecord()
                    note = ""
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("太棒了！你完成了一次专注。")
            }
            .alert("继续上次的专注？", isPresented: $showingResumeAlert) {
                Button("继续") {
                    resumeLastSession()
                }
                Button("放弃", role: .destructive) {
                    clearSavedSession()
                }
            } message: {
                Text("发现未完成的专注任务")
            }
            .onAppear {
                checkForUnfinishedSession()
            }
            .onDisappear {
                if isRunning {
                    saveCurrentSession()
                }
                pauseTimer()
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startTimer() {
        if startTime == nil {
            startTime = Date()
        }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                completeTimer()
            }
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    private func resetTimer() {
        pauseTimer()
        timeRemaining = targetDuration
        startTime = nil
    }
    
    private func completeTimer() {
        pauseTimer()
        showingCompletionAlert = true
    }
    
    private func saveRecord() {
        guard let startTime = startTime else { return }
        
        let record = PomodoroRecord(
            startTime: startTime,
            duration: targetDuration - timeRemaining,
            targetDuration: targetDuration,
            relatedItem: selectedItem,
            note: note.isEmpty ? nil : note,
            isCompleted: timeRemaining == 0
        )
        
        modelContext.insert(record)
        try? modelContext.save()
        
        resetTimer()
    }
    
    private func getTodayRecords() -> [PomodoroRecord]? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayRecords = records.filter { calendar.isDate($0.startTime, inSameDayAs: today) }
        return todayRecords.isEmpty ? nil : todayRecords
    }
    
    private func saveCurrentSession() {
        if isRunning {
            let sessionData: [String: Any] = [
                "timeRemaining": timeRemaining,
                "targetDuration": targetDuration,
                "startTime": startTime as Any,
                "selectedItemId": String(describing: selectedItem?.persistentModelID) as Any
            ]
            UserDefaults.standard.set(sessionData, forKey: "unfinishedPomodoroSession")
        }
    }
    
    private func checkForUnfinishedSession() {
        guard let sessionData = UserDefaults.standard.dictionary(forKey: "unfinishedPomodoroSession"),
              let timeRemaining = sessionData["timeRemaining"] as? TimeInterval,
              let targetDuration = sessionData["targetDuration"] as? TimeInterval,
              let startTime = sessionData["startTime"] as? Date else {
            return
        }
        
        // 检查是否在合理的时间范围内（例如1小时内）
        if Date().timeIntervalSince(startTime) > 3600 {
            clearSavedSession()
            return
        }
        
        if let itemIdString = sessionData["selectedItemId"] as? String {
            selectedItem = items.first { String(describing: $0.persistentModelID) == itemIdString }
        }
        
        self.timeRemaining = timeRemaining
        self.targetDuration = targetDuration
        self.startTime = startTime
        showingResumeAlert = true
    }
    
    private func resumeLastSession() {
        startTimer()
    }
    
    private func clearSavedSession() {
        UserDefaults.standard.removeObject(forKey: "unfinishedPomodoroSession")
        resetTimer()
    }
}

struct PomodoroRecordRow: View {
    let record: PomodoroRecord
    
    var body: some View {
        HStack(spacing: 16) {
            // 时间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(record.startTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    Text(formatDuration(record.duration))
                        .foregroundColor(.primary)
                }
                .font(.headline)
            }
            
            Divider()
            
            // 关联事项
            if let item = record.relatedItem {
                HStack {
                    Image(systemName: item.icon)
                        .foregroundColor(.blue)
                    Text(item.name)
                        .foregroundColor(.primary)
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            // 完成状态
            Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(record.isCompleted ? .green : .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)分钟"
    }
}

private struct ItemPickerSheet: View {
    @Binding var selectedItem: Item?
    let items: [Item]
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Group {
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("还没有心情事项")
                            .font(.headline)
                        Text("请先在主页添加心情事项")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(items) { item in
                            Button(action: {
                                selectedItem = item
                                isPresented = false
                            }) {
                                HStack {
                                    Image(systemName: item.icon)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24, height: 24)
                                    Text(item.name)
                                    Spacer()
                                    if selectedItem?.id == item.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("选择心情事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
} 
