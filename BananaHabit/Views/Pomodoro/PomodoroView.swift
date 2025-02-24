import SwiftUI
import SwiftData
import ActivityKit
import BackgroundTasks

@MainActor
class PomodoroTimer: ObservableObject {
    // 添加静态实例以便在后台任务中访问
    static var shared: PomodoroTimer?
    
    @Published var timeRemaining: TimeInterval
    @Published var targetDuration: TimeInterval
    @Published var isRunning = false
    @Published var startTime: Date?
    @Published var isCountUp = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var isBackgrounded = false
    
    private var timer: Timer?
    private var liveActivity: Activity<PomodoroAttributes>?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var lastUpdateTime: Date = Date()
    var onComplete: (() -> Void)?
    
    init(duration: TimeInterval = 25 * 60) {
        self.timeRemaining = duration
        self.targetDuration = duration
        
        // 设置共享实例
        PomodoroTimer.shared = self
        
        // 注册后台任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.bananahabit.pomodorotimer", using: nil) { task in
            Self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
        
        // 监听应用程序状态变化
        NotificationCenter.default.addObserver(self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
            
        NotificationCenter.default.addObserver(self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil)
    }
    
    // 添加静态方法处理后台任务
    private static func handleBackgroundTask(task: BGProcessingTask) {
        guard let shared = Self.shared else {
            task.setTaskCompleted(success: false)
            return
        }
        
        // 确保在后台任务超时前完成
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // 在后台任务中只更新 Live Activity
        if shared.isRunning {
            shared.updateLiveActivity()
        }
        
        // 完成任务并安排下一个任务
        task.setTaskCompleted(success: true)
        shared.scheduleBackgroundTask()
    }
    
    @objc private func applicationWillTerminate() {
        if isRunning {
            // 保存当前状态
            saveCurrentSession()
            UserDefaults.standard.synchronize()
        }
    }
    
    @objc private func applicationDidEnterBackground() {
        isBackgrounded = true
        lastUpdateTime = Date()
        
        if isRunning {
            // 保存当前状态
            saveCurrentSession()
            UserDefaults.standard.synchronize()
            
            startBackgroundTask()
            scheduleBackgroundTask()
        }
        
        updateLiveActivity()
    }
    
    @objc private func applicationWillEnterForeground() {
        isBackgrounded = false
        
        if isRunning {
            // 计算后台经过的时间
            let timePassed = Date().timeIntervalSince(lastUpdateTime)
            lastUpdateTime = Date()
            
            if isCountUp {
                elapsedTime += timePassed
            } else {
                timeRemaining = max(0, timeRemaining - timePassed)
                if timeRemaining == 0 {
                    completeTimer()
                }
            }
            
            // 重新启动前台计时器
            timer?.invalidate()
            startTimer()
        }
        
        updateLiveActivity()
        endBackgroundTask()
    }
    
    private func startBackgroundTask() {
        // 结束之前的后台任务（如果存在）
        endBackgroundTask()
        
        // 开始新的后台任务
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // 在后台模式下更新计时器状态和Live Activity
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self, self.isRunning else {
                timer.invalidate()
                return
            }
            
            let now = Date()
            let timePassed = now.timeIntervalSince(self.lastUpdateTime)
            self.lastUpdateTime = now
            
            if self.isCountUp {
                self.elapsedTime += timePassed
            } else {
                self.timeRemaining = max(0, self.timeRemaining - timePassed)
                if self.timeRemaining == 0 {
                    self.completeTimer()
                }
            }
            
            self.updateLiveActivity()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.bananahabit.pomodorotimer")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            // 立即安排下一个任务
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                self.scheduleBackgroundTask()
            }
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
    
    func startTimer(itemName: String? = nil, itemIcon: String? = nil) {
        if startTime == nil {
            startTime = Date()
        }
        lastUpdateTime = Date()
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            let timePassed = now.timeIntervalSince(self.lastUpdateTime)
            self.lastUpdateTime = now
            
            if self.isCountUp {
                self.elapsedTime += timePassed
                self.updateLiveActivity(itemName: itemName, itemIcon: itemIcon)
            } else {
                if self.timeRemaining > 0 {
                    self.timeRemaining = max(0, self.timeRemaining - timePassed)
                    self.updateLiveActivity(itemName: itemName, itemIcon: itemIcon)
                    if self.timeRemaining == 0 {
                        self.completeTimer()
                    }
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
    
    func completeTimer() {
        pauseTimer()
        endLiveActivity()
        onComplete?()
    }
    
    // MARK: - Live Activity Methods
    
    private func startLiveActivity(itemName: String? = nil, itemIcon: String? = nil) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // 先结束现有的活动
        Task {
            // 结束当前的活动
            if let currentActivity = liveActivity {
                await currentActivity.end(dismissalPolicy: .immediate)
            }
            
            // 获取所有正在运行的同类型活动并结束它们
            for activity in Activity<PomodoroAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
            
            // 创建新的活动
            let attributes = PomodoroAttributes(
                targetDuration: targetDuration,
                startTime: startTime ?? Date()
            )
            
            let contentState = PomodoroAttributes.ContentState(
                timeRemaining: timeRemaining,
                progress: isCountUp ? 1.0 : 1 - (timeRemaining / targetDuration),
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
    }
    
    func updateLiveActivity(itemName: String? = nil, itemIcon: String? = nil) {
        Task {
            let contentState = PomodoroAttributes.ContentState(
                timeRemaining: timeRemaining,
                progress: isCountUp ? 1.0 : 1 - (timeRemaining / targetDuration),
                isRunning: isRunning,
                isCountUp: isCountUp,
                elapsedTime: elapsedTime,
                itemName: itemName,
                itemIcon: itemIcon,
                showSeconds: !isBackgrounded
            )
            
            let content = ActivityContent(
                state: contentState,
                staleDate: isBackgrounded ? 
                    Date(timeIntervalSinceNow: 5) : // 后台模式下5秒后过期
                    nil // 前台模式下不过期
            )
            
            // 更新当前活动
            await liveActivity?.update(content)
            
            // 更新所有正在运行的同类型活动
            for activity in Activity<PomodoroAttributes>.activities {
                await activity.update(content)
            }
            
            // 如果在后台模式下，确保活动不会过期
            if isBackgrounded && isRunning {
                Task {
                    try? await Task.sleep(nanoseconds: 4 * NSEC_PER_SEC) // 4秒后
                    await self.updateLiveActivity(itemName: itemName, itemIcon: itemIcon)
                }
            }
        }
    }
    
    private func endLiveActivity() {
        Task {
            // 结束当前活动
            await liveActivity?.end(dismissalPolicy: .immediate)
            liveActivity = nil
            
            // 结束所有正在运行的同类型活动
            for activity in Activity<PomodoroAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
    
    private func saveCurrentSession() {
        let sessionData: [String: Any] = [
            "timeRemaining": timeRemaining,
            "targetDuration": targetDuration,
            "startTime": startTime as Any,
            "lastActiveTime": Date(),
            "isCountUp": isCountUp,
            "elapsedTime": elapsedTime,
            "isRunning": isRunning
        ]
        UserDefaults.standard.set(sessionData, forKey: "unfinishedPomodoroSession")
    }
    
    func clearSavedSession() {
        UserDefaults.standard.removeObject(forKey: "unfinishedPomodoroSession")
        // 不再调用resetTimer，只清除保存的数据
    }
    
    func checkForUnfinishedSession() -> Bool {
        // 首先检查是否有保存的会话数据
        guard let sessionData = UserDefaults.standard.dictionary(forKey: "unfinishedPomodoroSession") else {
            return false
        }
        
        // 检查是否之前在运行
        guard let isRunning = sessionData["isRunning"] as? Bool, isRunning else {
            clearSavedSession()
            return false
        }
        
        // 检查上次活动时间
        guard let lastActiveTime = sessionData["lastActiveTime"] as? Date else {
            clearSavedSession()
            return false
        }
        
        // 检查是否在合理的时间范围内（例如1小时内）
        let timePassed = Date().timeIntervalSince(lastActiveTime)
        if timePassed > 3600 {
            clearSavedSession()
            return false
        }
        
        // 恢复状态并自动启动计时器
        restoreSessionAndStart(from: sessionData)
        return false
    }
    
    private func restoreSessionAndStart(from sessionData: [String: Any]) {
        restoreSessionWithoutStarting(from: sessionData)
        
        // 如果时间还没用完，启动计时器
        if (isCountUp || timeRemaining > 0) {
            startTimer()
        }
        
        // 移除保存的会话数据
        UserDefaults.standard.removeObject(forKey: "unfinishedPomodoroSession")
    }
    
    private func restoreSessionWithoutStarting(from sessionData: [String: Any]) {
        guard let targetDuration = sessionData["targetDuration"] as? TimeInterval,
              let startTime = sessionData["startTime"] as? Date,
              let lastActiveTime = sessionData["lastActiveTime"] as? Date,
              let isCountUp = sessionData["isCountUp"] as? Bool else {
            return
        }
        
        self.targetDuration = targetDuration
        self.startTime = startTime
        self.isCountUp = isCountUp
        
        let timePassed = Date().timeIntervalSince(lastActiveTime)
        
        if isCountUp {
            if let elapsedTime = sessionData["elapsedTime"] as? TimeInterval {
                self.elapsedTime = elapsedTime + timePassed
            }
        } else {
            if let timeRemaining = sessionData["timeRemaining"] as? TimeInterval {
                self.timeRemaining = max(0, timeRemaining - timePassed)
            }
        }
    }
}

// MARK: - 时间选择器视图
struct TimeOptionsView: View {
    @EnvironmentObject private var pomodoroTimer: PomodoroTimer
    @Binding var showingCustomTimeSheet: Bool
    
    let timeOptions: [(String, TimeInterval)] = [
        ("15分钟", 15 * 60),
        ("25分钟", 25 * 60),
        ("30分钟", 30 * 60),
        ("45分钟", 45 * 60),
        ("60分钟", 60 * 60),
        ("自定义", 0)
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(timeOptions, id: \.1) { option in
                    Button {
                        if option.1 == 0 {
                            showingCustomTimeSheet = true
                        } else {
                            pomodoroTimer.setDuration(option.1)
                        }
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
}

// MARK: - 自定义时间表单
struct CustomTimeSheet: View {
    @EnvironmentObject private var pomodoroTimer: PomodoroTimer
    @Binding var isPresented: Bool
    @Binding var customTime: Date
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            Text("小时")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("分钟")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 36)
                        
                        DatePicker("选择时长",
                                 selection: $customTime,
                                 in: Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!...Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!,
                                 displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        
                        HStack {
                            Spacer()
                            let components = Calendar.current.dateComponents([.hour, .minute], from: customTime)
                            if let hours = components.hour, let minutes = components.minute {
                                if hours > 0 {
                                    Text("\(hours)小时\(minutes)分钟")
                                } else {
                                    Text("\(minutes)分钟")
                                }
                            }
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("选择时长")
                } footer: {
                    Text("可选择1分钟到24小时的时长")
                }
            }
            .navigationTitle("自定义时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: customTime)
                        if let hours = components.hour, let minutes = components.minute {
                            let totalMinutes = hours * 60 + minutes
                            if totalMinutes > 0 {
                                pomodoroTimer.setDuration(TimeInterval(totalMinutes * 60))
                                isPresented = false
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 主视图
struct PomodoroView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var items: [Item]
    @Query(sort: \PomodoroRecord.startTime, order: .reverse) private var records: [PomodoroRecord]
    
    @EnvironmentObject private var pomodoroTimer: PomodoroTimer
    @State private var selectedItem: Item?
    @State private var showingItemPicker = false
    @State private var note: String = ""
    @State private var title: String = ""
    @State private var showingCompletionAlert = false
    @State private var showingResumeAlert = false
    @State private var showingCustomTimeSheet = false
    @State private var customTime = Calendar.current.date(bySettingHour: 0, minute: 25, second: 0, of: Date()) ?? Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 时间选择器（仅在倒计时模式显示）
                    if !pomodoroTimer.isCountUp {
                        TimeOptionsView(showingCustomTimeSheet: $showingCustomTimeSheet)
                    }
                    
                    // 计时器显示
                    TimerDisplayView(selectedItem: $selectedItem, showingItemPicker: $showingItemPicker)
                    
                    // 今日记录
                    TodayRecordsView(records: getTodayRecords())
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
            .sheet(isPresented: $showingCustomTimeSheet) {
                CustomTimeSheet(isPresented: $showingCustomTimeSheet, customTime: $customTime)
            }
            .alert("专注完成", isPresented: $showingCompletionAlert) {
                Button("确定") {
                    saveRecord()
                }
            } message: {
                Text("太棒了！你完成了一次专注。")
            }
            .alert("继续上次的专注？", isPresented: $showingResumeAlert) {
                Button("继续") {
                    pomodoroTimer.startTimer(
                        itemName: selectedItem?.name,
                        itemIcon: selectedItem?.icon
                    )
                }
                Button("放弃", role: .destructive) {
                    pomodoroTimer.clearSavedSession()
                }
            } message: {
                VStack(spacing: 8) {
                    if pomodoroTimer.isCountUp {
                        Text("上次计时已进行 \(Int(pomodoroTimer.elapsedTime / 60)) 分钟")
                    } else {
                        Text("上次倒计时还剩 \(Int(pomodoroTimer.timeRemaining / 60)) 分钟")
                    }
                    Text("是否继续？")
                }
            }
            .onAppear {
                pomodoroTimer.onComplete = { showingCompletionAlert = true }
                
                // 检查未完成的会话
                if pomodoroTimer.checkForUnfinishedSession() {
                    showingResumeAlert = true
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    pomodoroTimer.isBackgrounded = true
                    pomodoroTimer.updateLiveActivity(itemName: selectedItem?.name, itemIcon: selectedItem?.icon)
                } else if newPhase == .active {
                    pomodoroTimer.isBackgrounded = false
                    pomodoroTimer.updateLiveActivity(itemName: selectedItem?.name, itemIcon: selectedItem?.icon)
                    
                    // 检查是否有未完成的会话
                    if !showingResumeAlert && !showingCompletionAlert {
                        if pomodoroTimer.checkForUnfinishedSession() {
                            showingResumeAlert = true
                        }
                    }
                }
            }
        }
    }
    
    private func saveRecord() {
        guard let startTime = pomodoroTimer.startTime else { return }
        
        let record = PomodoroRecord(
            startTime: startTime,
            duration: pomodoroTimer.targetDuration - pomodoroTimer.timeRemaining,
            targetDuration: pomodoroTimer.targetDuration,
            relatedItem: selectedItem,
            note: nil,
            title: nil,
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
}

// MARK: - 计时器显示视图
struct TimerDisplayView: View {
    @EnvironmentObject private var pomodoroTimer: PomodoroTimer
    @Binding var selectedItem: Item?
    @Binding var showingItemPicker: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                // 进度环
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 280, height: 280)
                
                Circle()
                    .trim(from: 0, to: pomodoroTimer.isCountUp ?
                        1.0 : // 正计时显示满圆
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
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 今日记录视图
struct TodayRecordsView: View {
    let records: [PomodoroRecord]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日记录")
                .font(.headline)
                .padding(.horizontal)
            
            if let records = records {
                ForEach(records) { record in
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


