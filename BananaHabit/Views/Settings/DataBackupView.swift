import SwiftUI
import SwiftData

struct DataBackupView: View {
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
                        Text("上次备份")
                        Spacer()
                        if let lastSyncDate = backupManager.lastSyncDate {
                            Text(lastSyncDate, style: .date)
                                .foregroundColor(.secondary)
                        } else {
                            Text("从未备份")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { 
                        exportAndBackup()
                    }) {
                        Label("创建备份", systemImage: "arrow.up.doc.on.clipboard")
                    }
                    .alert("确认备份", isPresented: $showingConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("确认") {
                            if let url = exportURL {
                                backupManager.backup(fromURL: url)
                            }
                        }
                    } message: {
                        Text("确定要备份当前数据吗？")
                    }
                    
                    Button(action: { loadBackups() }) {
                        Label("刷新备份列表", systemImage: "arrow.clockwise")
                    }
                }
                
                Section("备份文件") {
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
            .navigationTitle("数据备份")
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
                Button("还原", action: {
                    guard let backup = selectedBackup else { return }
                    importFromBackup(backup)
                })
            } message: {
                Text("确定要从该备份还原数据吗？当前数据会被替换。")
            }
            .alert(isPresented: Binding<Bool>(
                get: { backupManager.syncError != nil },
                set: { if !$0 { backupManager.syncError = nil } }
            )) {
                Alert(
                    title: Text("备份错误"),
                    message: Text(backupManager.syncError ?? "未知错误"),
                    dismissButton: .default(Text("确定"))
                )
            }
            .alert("备份成功", isPresented: $backupManager.syncSuccess) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("数据备份操作已成功完成！")
            }
            .overlay {
                if backupManager.isSyncing {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .padding()
                            Text("处理中...")
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
    DataBackupView()
} 