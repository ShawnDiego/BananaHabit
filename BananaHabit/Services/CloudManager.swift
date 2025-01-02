import Foundation
import SwiftData
import CloudKit

typealias PersistentIdentifier = SwiftData.PersistentIdentifier

class CloudManager: ObservableObject {
    static let shared = CloudManager()
    private let container = CKContainer.default()
    private let privateDB: CKDatabase
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var showSuccessAlert = false
    
    init() {
        self.privateDB = container.privateCloudDatabase
        loadLastSyncDate()
    }
    
    // 备份数据到 iCloud
    func backupData(items: [Item], user: User?) {
        isSyncing = true
        syncError = nil
        
        // 准备用户数据
        var records: [CKRecord] = []
        
        // 备份用户数据
        if let user = user {
            let userRecord = CKRecord(recordType: "User")
            userRecord["id"] = user.id
            userRecord["name"] = user.name
            userRecord["email"] = user.email
            
            // 如果有头像，将头像数据上传
            if let avatarUrl = user.avatarUrl,
               let avatarData = try? Data(contentsOf: URL(fileURLWithPath: avatarUrl)) {
                let asset = CKAsset(fileURL: URL(fileURLWithPath: avatarUrl))
                userRecord["avatar"] = asset
            }
            
            records.append(userRecord)
        }
        
        // 备份事项和心情数据
        for item in items {
            let itemRecord = CKRecord(recordType: "Item")
            let itemIdentifier = "\(item.name)_\(item.createdDate.timeIntervalSince1970)"
            itemRecord["identifier"] = itemIdentifier
            itemRecord["name"] = item.name
            itemRecord["createdDate"] = item.createdDate
            
            records.append(itemRecord)
            
            // 备份心情数据
            for mood in item.moods {
                let moodRecord = CKRecord(recordType: "Mood")
                let moodIdentifier = "\(mood.date.timeIntervalSince1970)_\(mood.value)"
                moodRecord["identifier"] = moodIdentifier
                moodRecord["value"] = mood.value
                moodRecord["note"] = mood.note
                moodRecord["date"] = mood.date
                moodRecord["itemIdentifier"] = itemIdentifier
                
                records.append(moodRecord)
            }
        }
        
        // 批量保存记录
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.lastSyncDate = Date()
                    self.saveLastSyncDate()
                    self.showSuccessAlert = true
                case .failure(let error):
                    self.syncError = error.localizedDescription
                }
                self.isSyncing = false
            }
        }
        
        privateDB.add(operation)
    }
    
    // 从 iCloud 恢复数据
    func restoreData(completion: @escaping ([Item]?, User?) -> Void) {
        isSyncing = true
        
        let query = CKQuery(recordType: "User", predicate: NSPredicate(value: true))
        var restoredItems: [Item] = []
        var restoredUser: User?
        var itemIdentifierMap: [String: Item] = [:]
        
        // 恢复用户数据
        privateDB.perform(query, inZoneWith: nil) { [weak self] records, error in
            guard let self = self else { return }
            
            if let userRecord = records?.first {
                restoredUser = self.createUser(from: userRecord)
                
                // 恢复事项和心情数据
                let itemQuery = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
                self.privateDB.perform(itemQuery, inZoneWith: nil) { records, error in
                    if let itemRecords = records {
                        for itemRecord in itemRecords {
                            if let item = self.createItem(from: itemRecord),
                               let identifier = itemRecord["identifier"] as? String {
                                itemIdentifierMap[identifier] = item
                                restoredItems.append(item)
                            }
                        }
                        
                        // 恢复所有心情数据
                        let moodQuery = CKQuery(recordType: "Mood", predicate: NSPredicate(value: true))
                        self.privateDB.perform(moodQuery, inZoneWith: nil) { moodRecords, error in
                            if let moodRecords = moodRecords {
                                for moodRecord in moodRecords {
                                    if let itemIdentifier = moodRecord["itemIdentifier"] as? String,
                                       let item = itemIdentifierMap[itemIdentifier],
                                       let mood = self.createMood(from: moodRecord, item: item) {
                                        item.moods.append(mood)
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.lastSyncDate = Date()
                                self.saveLastSyncDate()
                                self.isSyncing = false
                                completion(restoredItems, restoredUser)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isSyncing = false
                            completion(nil, restoredUser)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    completion(nil, nil)
                }
            }
        }
    }
    
    private func createUser(from record: CKRecord) -> User? {
        guard let id = record["id"] as? String,
              let name = record["name"] as? String else { return nil }
        
        var user = User(id: id, name: name)
        user.email = record["email"] as? String
        
        if let asset = record["avatar"] as? CKAsset,
           let url = asset.fileURL {
            // 保存头像到本地
            let fileName = "\(id)_avatar.jpg"
            let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let avatarsDirectory = applicationSupportDirectory.appendingPathComponent("Avatars", isDirectory: true)
            try? FileManager.default.createDirectory(at: avatarsDirectory, withIntermediateDirectories: true)
            let localURL = avatarsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.copyItem(at: url, to: localURL)
            user.avatarUrl = localURL.path
        }
        
        return user
    }
    
    private func createItem(from record: CKRecord) -> Item? {
        guard let name = record["name"] as? String,
              let createdDate = record["createdDate"] as? Date else { return nil }
        
        return Item(name: name, createdDate: createdDate)
    }
    
    private func createMood(from record: CKRecord, item: Item) -> Mood? {
        guard let value = record["value"] as? Int,
              let date = record["date"] as? Date else { return nil }
        
        let note = record["note"] as? String ?? ""
        return Mood(date: date, value: value, note: note, item: item)
    }
    
    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "LastCloudSyncDate")
        }
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "LastCloudSyncDate") as? Date
    }
} 
