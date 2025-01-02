import Foundation
import SwiftData
import UniformTypeIdentifiers

struct ExportData: Codable {
    struct ItemData: Codable {
        let name: String
        let createdDate: Date
        let moods: [MoodData]
    }
    
    struct MoodData: Codable {
        let date: Date
        let value: Int
        let note: String
    }
    
    let items: [ItemData]
    let exportDate: Date
    
    static func encode(_ items: [Item]) -> Data? {
        let itemsData = items.map { item in
            ItemData(
                name: item.name,
                createdDate: item.createdDate,
                moods: item.moods.map { mood in
                    MoodData(
                        date: mood.date,
                        value: mood.value,
                        note: mood.note
                    )
                }
            )
        }
        
        let exportData = ExportData(
            items: itemsData,
            exportDate: Date()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
}

class DataExportManager: ObservableObject {
    static let shared = DataExportManager()
    
    @Published var importError: String?
    @Published var showSuccessAlert = false
    
    func exportData(_ items: [Item]) -> URL? {
        guard let data = ExportData.encode(items) else { return nil }
        
        let fileName = "BananaHabit_\(Date().formatted(.iso8601)).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("导出失败: \(error)")
            return nil
        }
    }
    
    func importData(_ url: URL, into context: ModelContext) {
        do {
            // 读取文件内容
            let data = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(ExportData.self, from: data)
            
            // 获取现有数据用于查重
            let descriptor = FetchDescriptor<Item>()
            let existingItems = try context.fetch(descriptor)
            let existingItemMap = Dictionary(
                grouping: existingItems,
                by: { "\($0.name)_\($0.createdDate.timeIntervalSince1970)" }
            )
            
            // 导入数据
            for itemData in exportData.items {
                let itemIdentifier = "\(itemData.name)_\(itemData.createdDate.timeIntervalSince1970)"
                
                if let existingItem = existingItemMap[itemIdentifier]?.first {
                    // 如果项目存在，只添加新的心情记录
                    let existingMoodMap = Dictionary(
                        grouping: existingItem.moods,
                        by: { "\($0.date.timeIntervalSince1970)_\($0.value)" }
                    )
                    
                    for moodData in itemData.moods {
                        let moodIdentifier = "\(moodData.date.timeIntervalSince1970)_\(moodData.value)"
                        if existingMoodMap[moodIdentifier] == nil {
                            existingItem.moods.append(
                                Mood(
                                    date: moodData.date,
                                    value: moodData.value,
                                    note: moodData.note,
                                    item: existingItem
                                )
                            )
                        }
                    }
                } else {
                    // 如果项目不存在，创建新项目
                    let newItem = Item(name: itemData.name, createdDate: itemData.createdDate)
                    for moodData in itemData.moods {
                        newItem.moods.append(
                            Mood(
                                date: moodData.date,
                                value: moodData.value,
                                note: moodData.note,
                                item: newItem
                            )
                        )
                    }
                    context.insert(newItem)
                }
            }
            
            try context.save()
            showSuccessAlert = true
            
        } catch {
            print("导入失败: \(error)")
            importError = error.localizedDescription
        }
    }
} 