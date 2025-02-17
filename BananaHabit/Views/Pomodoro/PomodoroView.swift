import SwiftUI
import SwiftData
import ActivityKit

@MainActor
class PomodoroTimer: ObservableObject {
    @Published var timeRemaining: TimeInterval
    @Published var targetDuration: TimeInterval
    @Published var isRunning = false
    @Published var startTime: Date?
    @Published var isCountUp = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var isBackgrounded = false
    
    private var timer: Timer?
    private var liveActivity: Activity<PomodoroAttributes>?
    var onComplete: (() -> Void)?
    
    init(duration: TimeInterval = 25 * 60) {
        self.timeRemaining = duration
        self.targetDuration = duration
        
        // 监听应用程序状态变化
        NotificationCenter.default.addObserver(self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }
    
    @objc private func applicationDidEnterBackground() {
        isBackgrounded = true
        updateLiveActivity()
    }
    
    @objc private func applicationWillEnterForeground() {
        isBackgrounded = false
        updateLiveActivity()
    }
    
    func startTimer(itemName: String? = nil, itemIcon: String? = nil) {
        if startTime == nil {
            startTime = Date()
        }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isCountUp {
                self.elapsedTime += 1
            } else {
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    self.updateLiveActivity(itemName: itemName, itemIcon: itemIcon)
                } else {
                    self.completeTimer()
                }
            }
        }
        
        // 启动实时活动
        startLiveActivity(itemName: itemName, itemIcon: itemIcon)
    }
    
    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        updateLiveActivity()
    }
    
    func resetTimer() {
        pauseTimer()
        timeRemaining = targetDuration
        elapsedTime = 0
        startTime = nil
        endLiveActivity()
    }
    
    func setDuration(_ duration: TimeInterval) {
        if !isRunning {
            targetDuration = duration
            timeRemaining = duration
        }
    }
    
    func toggleCountMode() {
        if !isRunning {
            isCountUp.toggle()
            resetTimer()
        }
    }
    
    func restoreState(timeRemaining: TimeInterval, targetDuration: TimeInterval, startTime: Date) {
        self.timeRemaining = timeRemaining
        self.targetDuration = targetDuration
        self.startTime = startTime
    }
    
    private func completeTimer() {
        pauseTimer()
        endLiveActivity()
        onComplete?()
    }
    
    // MARK: - Live Activity Methods
    
    private func startLiveActivity(itemName: String? = nil, itemIcon: String? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = PomodoroAttributes(
            targetDuration: targetDuration,
            startTime: startTime ?? Date()
        )
        
        let contentState = PomodoroAttributes.ContentState(
            timeRemaining: timeRemaining,
            progress: 1 - (timeRemaining / targetDuration),
            isRunning: isRunning,
            isCountUp: isCountUp,
            elapsedTime: elapsedTime,
            itemName: itemName,
            itemIcon: itemIcon,
            showSeconds: !isBackgrounded
        )
        
        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
        } catch {
            print("Error starting live activity: \(error)")
        }
    }
    
    private func updateLiveActivity(itemName: String? = nil, itemIcon: String? = nil) {
        Task {
            let contentState = PomodoroAttributes.ContentState(
                timeRemaining: timeRemaining,
                progress: 1 - (timeRemaining / targetDuration),
                isRunning: isRunning,
                isCountUp: isCountUp,
                elapsedTime: elapsedTime,
                itemName: itemName,
                itemIcon: itemIcon,
                showSeconds: !isBackgrounded
            )
            
            let content = ActivityContent(state: contentState, staleDate: nil)
            await liveActivity?.update(content)
        }
    }
    
    private func endLiveActivity() {
        Task {
            await liveActivity?.end(dismissalPolicy: .immediate)
        }
    }
}

struct PomodoroView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [Item]
    @Query(sort: \PomodoroRecord.startTime, order: .reverse) private var records: [PomodoroRecord]
    
    @StateObject private var pomodoroTimer = PomodoroTimer()
    @State private var selectedItem: Item?
    @State private var showingItemPicker = false
    @State private var note: String = ""
    @State private var title: String = ""
    @State private var showingCompletionAlert = false
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
                    // 时间选择器（仅在倒计时模式显示）
                    if !pomodoroTimer.isCountUp {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(timeOptions, id: \.1) { option in
                                    Button {
                                        pomodoroTimer.setDuration(option.1)
                                    } label: {
                                        Text(option.0)
                                            .font(.headline)
                                            .foregroundColor(pomodoroTimer.targetDuration == option.1 ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(pomodoroTimer.targetDuration == option.1 ? Color.blue : Color(.tertiarySystemBackground))
                                            )
                                    }
                                    .disabled(pomodoroTimer.isRunning)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // 计时器显示
                    VStack(spacing: 32) {
                        ZStack {
                            // 进度环
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                                .frame(width: 280, height: 280)
                            
                            Circle()
                                .trim(from: 0, to: pomodoroTimer.isCountUp ?
                                    min(CGFloat(pomodoroTimer.elapsedTime / 3600), 1.0) : // 正计时最多显示1小时
                                    CGFloat(1 - (pomodoroTimer.timeRemaining / pomodoroTimer.targetDuration)))
                                .stroke(
                                    pomodoroTimer.isCountUp ? Color.green : Color.blue,
                                    style: StrokeStyle(
                                        lineWidth: 20,
                                        lineCap: .round
                                    )
                                )
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: pomodoroTimer.isCountUp ? pomodoroTimer.elapsedTime : pomodoroTimer.timeRemaining)
                            
                            VStack(spacing: 8) {
                                Text(pomodoroTimer.isCountUp ? 
                                    timeString(from: pomodoroTimer.elapsedTime) :
                                    timeString(from: pomodoroTimer.timeRemaining))
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
                                pomodoroTimer.resetTimer()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(Circle())
                            }
                            
                            Button {
                                if pomodoroTimer.isRunning {
                                    pomodoroTimer.pauseTimer()
                                } else {
                                    pomodoroTimer.startTimer(
                                        itemName: selectedItem?.name,
                                        itemIcon: selectedItem?.icon
                                    )
                                }
                            } label: {
                                Image(systemName: pomodoroTimer.isRunning ? "pause.fill" : "play.fill")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pomodoroTimer.toggleCountMode()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: pomodoroTimer.isCountUp ? "timer" : "timer.circle")
                            Text(pomodoroTimer.isCountUp ? "正计时" : "倒计时")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(pomodoroTimer.isRunning)
                }
            }
            .sheet(isPresented: $showingItemPicker) {
                ItemPickerSheet(selectedItem: $selectedItem, items: items, isPresented: $showingItemPicker)
            }
            .alert("专注完成", isPresented: $showingCompletionAlert) {
                TextField("添加备注", text: $note)
                TextField("添加标题", text: $title)
                Button("保存") {
                    saveRecord()
                    note = ""
                    title = ""
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
                pomodoroTimer.onComplete = { showingCompletionAlert = true }
                checkForUnfinishedSession()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    pomodoroTimer.isBackgrounded = true
                } else if newPhase == .active {
                    pomodoroTimer.isBackgrounded = false
                }
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func saveRecord() {
        guard let startTime = pomodoroTimer.startTime else { return }
        
        let record = PomodoroRecord(
            startTime: startTime,
            duration: pomodoroTimer.targetDuration - pomodoroTimer.timeRemaining,
            targetDuration: pomodoroTimer.targetDuration,
            relatedItem: selectedItem,
            note: note.isEmpty ? nil : note,
            title: title.isEmpty ? nil : title,
            isCompleted: pomodoroTimer.timeRemaining == 0
        )
        
        modelContext.insert(record)
        try? modelContext.save()
        
        pomodoroTimer.resetTimer()
    }
    
    private func getTodayRecords() -> [PomodoroRecord]? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayRecords = records.filter { calendar.isDate($0.startTime, inSameDayAs: today) }
        return todayRecords.isEmpty ? nil : todayRecords
    }
    
    private func checkForUnfinishedSession() {
        guard let sessionData = UserDefaults.standard.dictionary(forKey: "unfinishedPomodoroSession"),
              let targetDuration = sessionData["targetDuration"] as? TimeInterval,
              let startTime = sessionData["startTime"] as? Date,
              let lastActiveTime = sessionData["lastActiveTime"] as? Date,
              let isCountUp = sessionData["isCountUp"] as? Bool else {
            return
        }
        
        // 检查是否在合理的时间范围内（例如1小时内）
        let timePassed = Date().timeIntervalSince(lastActiveTime)
        if timePassed > 3600 {
            clearSavedSession()
            return
        }
        
        if let itemIdString = sessionData["selectedItemId"] as? String {
            selectedItem = items.first { String(describing: $0.persistentModelID) == itemIdString }
        }
        
        if isCountUp {
            if let elapsedTime = sessionData["elapsedTime"] as? TimeInterval {
                pomodoroTimer.elapsedTime = elapsedTime + timePassed
            }
            pomodoroTimer.isCountUp = true
        } else {
            if let timeRemaining = sessionData["timeRemaining"] as? TimeInterval {
                // 调整剩余时间，考虑经过的时间
                let adjustedTimeRemaining = max(0, timeRemaining - timePassed)
                pomodoroTimer.timeRemaining = adjustedTimeRemaining
            }
        }
        
        pomodoroTimer.targetDuration = targetDuration
        pomodoroTimer.startTime = startTime
        
        if !isCountUp && pomodoroTimer.timeRemaining > 0 {
            showingResumeAlert = true
        } else if isCountUp {
            showingResumeAlert = true
        } else {
            // 如果是倒计时且时间已经用完，直接显示完成提示
            showingCompletionAlert = true
        }
    }
    
    private func saveCurrentSession() {
        if pomodoroTimer.isRunning {
            let sessionData: [String: Any] = [
                "timeRemaining": pomodoroTimer.timeRemaining,
                "targetDuration": pomodoroTimer.targetDuration,
                "startTime": pomodoroTimer.startTime as Any,
                "selectedItemId": String(describing: selectedItem?.persistentModelID) as Any,
                "wasTerminated": true,
                "lastActiveTime": Date(),
                "isCountUp": pomodoroTimer.isCountUp,
                "elapsedTime": pomodoroTimer.elapsedTime
            ]
            UserDefaults.standard.set(sessionData, forKey: "unfinishedPomodoroSession")
        }
    }
    
    private func resumeLastSession() {
        pomodoroTimer.startTimer()
    }
    
    private func clearSavedSession() {
        UserDefaults.standard.removeObject(forKey: "unfinishedPomodoroSession")
        pomodoroTimer.resetTimer()
    }
}

struct PomodoroRecordRow: View {
    let record: PomodoroRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            if record.title != nil || record.note != nil {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    if let title = record.title {
                        Text(title)
                            .font(.headline)
                    }
                    
                    if let note = record.note {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
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

