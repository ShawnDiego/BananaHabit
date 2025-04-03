import SwiftUI
import SwiftData

struct iCloudBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var items: [Item]
    @Query private var diaries: [Diary]
    @Query private var records: [PomodoroRecord]
    
    @ObservedObject private var backupManager = iCloudBackupManager.shared
    @ObservedObject private var exportManager = DataExportManager.shared
    
    @State private var showingConfirmation = false
    @State private var backupsList: [iCloudBackupManager.BackupInfo] = []
    @State private var isLoadingBackups = false
    @State private var selectedBackup: iCloudBackupManager.BackupInfo?
    @State private var showingRestoreConfirmation = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("上次同步")
                        Spacer()
                        if let lastSyncDate = backupManager.lastSyncDate {
                            Text(lastSyncDate, style: .date)
                                .foregroundColor(.secondary)
                        } else {
                            Text("从未同步")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { 
                        exportAndBackup()
                    }) {
                        Label("备份到iCloud", systemImage: "arrow.up.doc.on.clipboard")
                    }
                    .alert("确认备份", isPresented: $showingConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("确认") {
                            if let url = exportURL {
                                // 手动调用复制到iCloud的逻辑
                                backupToiCloud(from: url)
                            }
                        }
                    } message: {
                        Text("确定要将当前数据备份到iCloud吗？这将覆盖旧的备份。")
                    }
                    
                    Button(action: { loadBackups() }) {
                        Label("刷新备份列表", systemImage: "arrow.clockwise")
                    }
                }
                
                Section("iCloud备份文件") {
                    if isLoadingBackups {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else if backupsList.isEmpty {
                        Text("没有找到备份文件")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(backupsList) { backup in
                            Button(action: {
                                selectedBackup = backup
                                showingRestoreConfirmation = true
                            }) {
                                VStack(alignment: .leading) {
                                    Text(backup.fileName)
                                        .font(.headline)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        Text(backup.formattedDate)
                                        Spacer()
                                        Text(backup.formattedSize)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    if backupManager.deleteBackup(backup) {
                                        loadBackups()
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("iCloud备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("还原确认", isPresented: $showingRestoreConfirmation) {
                Button("取消", role: .cancel) { }
                Button("还原") {
                    guard let backup = selectedBackup else { return }
                    importFromBackup(backup)
                }
            } message: {
                Text("确定要从该备份还原数据吗？当前数据会被替换。")
            }
            .alert(isPresented: Binding<Bool>(
                get: { backupManager.syncError != nil },
                set: { if !$0 { backupManager.syncError = nil } }
            )) {
                Alert(
                    title: Text("同步错误"),
                    message: Text(backupManager.syncError ?? "未知错误"),
                    dismissButton: .default(Text("确定"))
                )
            }
            .alert("同步成功", isPresented: $backupManager.syncSuccess) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("iCloud同步操作已成功完成！")
            }
            .overlay {
                if backupManager.isSyncing {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .padding()
                            Text("同步中...")
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    }
                }
            }
            .onAppear {
                loadBackups()
                setupNotificationObserver()
            }
        }
    }
    
    private func setupNotificationObserver() {
        // 添加通知观察者，处理从iCloud恢复时的URL通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ImportFromURL"),
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                exportManager.importData(url, into: modelContext)
            }
        }
    }
    
    private func exportAndBackup() {
        do {
            // 导出所有数据
            if let url = exportManager.exportData(items, diaries, records) {
                // 存储URL供备份使用
                exportURL = url
                showingConfirmation = true
            }
        } catch {
            backupManager.syncError = error.localizedDescription
        }
    }
    
    private func importFromBackup(_ backup: iCloudBackupManager.BackupInfo) {
        do {
            // 读取备份文件内容
            exportManager.importData(backup.url, into: modelContext)
        } catch {
            backupManager.syncError = "导入失败: \(error.localizedDescription)"
        }
    }
    
    private func backupToiCloud(from tempURL: URL) {
        // 手动将临时文件复制到iCloud目录
        backupManager.isSyncing = true
        backupManager.syncSuccess = false
        backupManager.syncError = nil
        
        // 确保iCloud可用
        let containerIdentifier = "iCloud.com.Diego.BananaHabit"
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)?.appendingPathComponent("BananaHabitBackups", isDirectory: true) else {
            backupManager.syncError = "无法访问iCloud，请确保您已登录iCloud账户"
            backupManager.isSyncing = false
            return
        }
        
        // 先检查iCloud是否可用
        if FileManager.default.ubiquityIdentityToken == nil {
            backupManager.syncError = "iCloud不可用，请确保您已登录iCloud账户并开启iCloud Drive"
            backupManager.isSyncing = false
            return
        }
        
        // 在后台线程执行文件操作
        DispatchQueue.global().async {
            do {
                // 创建同步目录（如果不存在）
                if !FileManager.default.fileExists(atPath: containerURL.path) {
                    try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
                    print("成功创建iCloud目录: \(containerURL.path)")
                }
                
                // 创建备份文件名
                let backupFileName = "BananaHabit_Backup_\(Date().formatted(.iso8601)).json"
                let backupURL = containerURL.appendingPathComponent(backupFileName)
                
                // 如果存在旧文件，先删除
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try FileManager.default.removeItem(at: backupURL)
                }
                
                // 复制备份文件到iCloud
                try FileManager.default.copyItem(at: tempURL, to: backupURL)
                print("成功复制文件到iCloud: \(backupURL.path)")
                
                // 更新UI
                DispatchQueue.main.async {
                    // 更新同步时间
                    let now = Date()
                    UserDefaults.standard.set(now, forKey: "LastiCloudSyncDate")
                    backupManager.lastSyncDate = now
                    
                    // 备份成功
                    backupManager.syncSuccess = true
                    backupManager.isSyncing = false
                    
                    // 刷新备份列表
                    loadBackups()
                }
            } catch {
                DispatchQueue.main.async {
                    backupManager.syncError = "备份到iCloud失败: \(error.localizedDescription)"
                    backupManager.isSyncing = false
                }
                print("备份到iCloud失败: \(error)")
            }
        }
    }
    
    private func loadBackups() {
        isLoadingBackups = true
        // 在后台线程加载备份列表
        DispatchQueue.global().async {
            let backups = backupManager.getBackupsList()
            DispatchQueue.main.async {
                backupsList = backups
                isLoadingBackups = false
            }
        }
    }
}

// 预览
#Preview {
    iCloudBackupView()
} 