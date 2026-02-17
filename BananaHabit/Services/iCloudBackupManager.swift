import Foundation
import SwiftData

class iCloudBackupManager: ObservableObject {
    static let shared = iCloudBackupManager()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncSuccess = false
    
    // 备份文件信息模型
    struct BackupInfo: Identifiable {
        var id: String { url.lastPathComponent }
        let url: URL
        let fileName: String
        let date: Date
        let size: Int
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        var formattedSize: String {
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.allowedUnits = [.useKB, .useMB]
            byteCountFormatter.countStyle = .file
            return byteCountFormatter.string(fromByteCount: Int64(size))
        }
    }
    
    private let backupDirectoryName = "BananaHabitBackups"
    
    // 获取备份目录URL (使用应用文档目录)
    private var backupDirectoryURL: URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent(backupDirectoryName, isDirectory: true)
    }
    
    // 初始化方法
    private init() {
        // 创建备份文件夹（如果不存在）
        setupBackupDirectory()
        // 检查上次同步时间
        checkLastSyncDate()
    }
    
    // 设置备份目录
    private func setupBackupDirectory() {
        guard let directoryURL = backupDirectoryURL else {
            syncError = "无法访问文档目录"
            return
        }
        
        do {
            // 创建备份目录（如果不存在）
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                print("成功创建备份目录: \(directoryURL.path)")
            }
        } catch {
            syncError = "创建备份目录失败: \(error.localizedDescription)"
            print("创建备份目录失败: \(error)")
        }
    }
    
    // 检查上次同步时间
    private func checkLastSyncDate() {
        // 从UserDefaults读取上次同步时间
        if let date = UserDefaults.standard.object(forKey: "LastBackupDate") as? Date {
            lastSyncDate = date
        }
    }
    
    // 保存上次同步时间
    private func saveLastSyncDate() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: "LastBackupDate")
        lastSyncDate = now
    }
    
    // 备份数据
    func backup(fromURL tempURL: URL) {
        syncError = nil
        isSyncing = true
        syncSuccess = false
        
        // 确保备份目录可用
        guard let directoryURL = backupDirectoryURL else {
            syncError = "无法访问备份目录"
            isSyncing = false
            return
        }
        
        // 在后台线程执行文件操作
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 创建备份文件名
                let backupFileName = "BananaHabit_Backup_\(Date().formatted(.iso8601)).json"
                let backupURL = directoryURL.appendingPathComponent(backupFileName)
                
                // 如果存在旧文件，先删除
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    try FileManager.default.removeItem(at: backupURL)
                }
                
                // 复制备份文件到备份目录
                try FileManager.default.copyItem(at: tempURL, to: backupURL)
                print("成功创建备份文件: \(backupURL.path)")
                
                DispatchQueue.main.async {
                    // 更新同步时间
                    self.saveLastSyncDate()
                    self.syncSuccess = true
                    self.isSyncing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.syncError = "备份失败: \(error.localizedDescription)"
                    self.isSyncing = false
                }
            }
        }
    }
    
    // 获取所有备份文件信息
    func getBackupsList() -> [BackupInfo] {
        guard let directoryURL = backupDirectoryURL else { return [] }
        
        do {
            // 确保目录存在
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                return []
            }
            
            // 获取目录中的所有文件
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skipsHiddenFiles)
            
            // 筛选JSON文件并转换为BackupInfo
            return try fileURLs.filter { $0.pathExtension == "json" }
                .map {
                    let attributes = try $0.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                    return BackupInfo(
                        url: $0,
                        fileName: $0.lastPathComponent,
                        date: attributes.contentModificationDate ?? Date.distantPast,
                        size: attributes.fileSize ?? 0
                    )
                }
                .sorted { $0.date > $1.date } // 按日期降序排序
        } catch {
            syncError = "获取备份列表失败: \(error.localizedDescription)"
            return []
        }
    }
    
    // 删除指定备份
    func deleteBackup(_ backup: BackupInfo) -> Bool {
        do {
            try FileManager.default.removeItem(at: backup.url)
            return true
        } catch {
            syncError = "删除备份失败: \(error.localizedDescription)"
            return false
        }
    }
} 