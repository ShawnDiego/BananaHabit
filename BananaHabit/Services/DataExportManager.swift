import Foundation
import SwiftData
import UniformTypeIdentifiers

// 导入模型
@preconcurrency import class BananaHabit.Item
@preconcurrency import class BananaHabit.Mood
@preconcurrency import class BananaHabit.Diary
@preconcurrency import class BananaHabit.PomodoroRecord

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
    
    struct DiaryData: Codable {
        let id: UUID
        let title: String?
        let content: String
        let createdAt: Date
        let modifiedAt: Date 
        let relatedItemName: String?
        let relatedItemCreatedDate: Date?
        let selectedDate: Date?
        let isLocked: Bool
        let password: String?
    }
    
    struct PomodoroRecordData: Codable {
        let id: UUID
        let startTime: Date
        let duration: TimeInterval
        let targetDuration: TimeInterval
        let relatedItemName: String?
        let relatedItemCreatedDate: Date?
        let note: String?
        let isCompleted: Bool
        let title: String?
    }
    
    let items: [ItemData]
    let diaries: [DiaryData]
    let pomodoroRecords: [PomodoroRecordData]
    let exportDate: Date
    
    static func encode(_ items: [Item], _ diaries: [Diary] = [], _ records: [PomodoroRecord] = []) -> Data? {
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
        
        let diariesData = diaries.map { diary in
            DiaryData(
                id: diary.id,
                title: diary.title,
                content: diary.content,
                createdAt: diary.createdAt,
                modifiedAt: diary.modifiedAt,
                relatedItemName: diary.relatedItem?.name,
                relatedItemCreatedDate: diary.relatedItem?.createdDate,
                selectedDate: diary.selectedDate,
                isLocked: diary.isLocked,
                password: diary.password
            )
        }
        
        let pomodoroRecordsData = records.map { record in
            PomodoroRecordData(
                id: record.id,
                startTime: record.startTime,
                duration: record.duration,
                targetDuration: record.targetDuration,
                relatedItemName: record.relatedItem?.name,
                relatedItemCreatedDate: record.relatedItem?.createdDate,
                note: record.note,
                isCompleted: record.isCompleted,
                title: record.title
            )
        }
        
        let exportData = ExportData(
            items: itemsData,
            diaries: diariesData,
            pomodoroRecords: pomodoroRecordsData,
            exportDate: Date()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
}

class DataExportManager: ObservableObject {
    static let shared = DataExportManager()
    
    @Published var importError: String?
    @Published var showSuccessAlert = false
    
    func exportData(_ items: [Item], _ diaries: [Diary] = [], _ records: [PomodoroRecord] = []) -> URL? {
        guard let data = ExportData.encode(items, diaries, records) else { return nil }
        
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
            
            // 尝试解码新格式的数据
            do {
                let exportData = try JSONDecoder().decode(ExportData.self, from: data)
                
                // 导入数据
                importItemData(exportData.items, context: context)
                importDiaryData(exportData.diaries, context: context)
                importPomodoroRecordData(exportData.pomodoroRecords, context: context)
                
                try context.save()
                showSuccessAlert = true
                return
            } catch {
                // 如果无法解码新格式数据，尝试解码旧格式数据
                print("尝试解码旧格式数据")
                struct OldExportData: Codable {
                    let items: [ExportData.ItemData]
                    let exportDate: Date
                }
                
                let oldExportData = try JSONDecoder().decode(OldExportData.self, from: data)
                importItemData(oldExportData.items, context: context)
                try context.save()
                showSuccessAlert = true
            }
        } catch {
            print("导入失败: \(error)")
            importError = error.localizedDescription
        }
    }
    
    private func importItemData(_ itemsData: [ExportData.ItemData], context: ModelContext) {
        // 获取现有数据用于查重
        do {
            let itemDescriptor = FetchDescriptor<Item>()
            let existingItems = try context.fetch(itemDescriptor)
            let existingItemMap = Dictionary(
                grouping: existingItems,
                by: { "\($0.name)_\($0.createdDate.timeIntervalSince1970)" }
            )
            
            // 导入项目数据
            for itemData in itemsData {
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
        } catch {
            print("导入项目数据失败: \(error)")
        }
    }
    
    private func importDiaryData(_ diariesData: [ExportData.DiaryData], context: ModelContext) {
        // 获取现有日记数据用于查重
        do {
            let diaryDescriptor = FetchDescriptor<Diary>()
            let existingDiaries = try context.fetch(diaryDescriptor)
            let existingDiaryMap = Dictionary(grouping: existingDiaries, by: { $0.id })
            
            // 获取现有项目数据用于关联
            let itemDescriptor = FetchDescriptor<Item>()
            let existingItems = try context.fetch(itemDescriptor)
            
            // 导入日记数据
            for diaryData in diariesData {
                if existingDiaryMap[diaryData.id] == nil {
                    // 查找关联的项目
                    var relatedItem: Item? = nil
                    if let itemName = diaryData.relatedItemName, 
                       let itemDate = diaryData.relatedItemCreatedDate {
                        relatedItem = existingItems.first { 
                            $0.name == itemName && 
                            abs($0.createdDate.timeIntervalSince(itemDate)) < 1.0 // 允许1秒误差
                        }
                    }
                    
                    // 创建新日记
                    let newDiary = Diary(
                        id: diaryData.id,
                        title: diaryData.title,
                        content: diaryData.content,
                        createdAt: diaryData.createdAt,
                        modifiedAt: diaryData.modifiedAt,
                        images: [],
                        relatedItem: relatedItem,
                        selectedDate: diaryData.selectedDate,
                        isLocked: diaryData.isLocked,
                        password: diaryData.password
                    )
                    context.insert(newDiary)
                }
            }
        } catch {
            print("导入日记数据失败: \(error)")
        }
    }
    
    private func importPomodoroRecordData(_ recordsData: [ExportData.PomodoroRecordData], context: ModelContext) {
        // 获取现有番茄钟记录用于查重
        do {
            let recordDescriptor = FetchDescriptor<PomodoroRecord>()
            let existingRecords = try context.fetch(recordDescriptor)
            let existingRecordMap = Dictionary(grouping: existingRecords, by: { $0.id })
            
            // 获取现有项目数据用于关联
            let itemDescriptor = FetchDescriptor<Item>()
            let existingItems = try context.fetch(itemDescriptor)
            
            // 导入番茄钟记录
            for recordData in recordsData {
                if existingRecordMap[recordData.id] == nil {
                    // 查找关联的项目
                    var relatedItem: Item? = nil
                    if let itemName = recordData.relatedItemName, 
                       let itemDate = recordData.relatedItemCreatedDate {
                        relatedItem = existingItems.first { 
                            $0.name == itemName && 
                            abs($0.createdDate.timeIntervalSince(itemDate)) < 1.0 // 允许1秒误差
                        }
                    }
                    
                    // 创建新番茄钟记录
                    let newRecord = PomodoroRecord(
                        id: recordData.id,
                        startTime: recordData.startTime,
                        duration: recordData.duration,
                        targetDuration: recordData.targetDuration,
                        relatedItem: relatedItem,
                        note: recordData.note,
                        title: recordData.title,
                        isCompleted: recordData.isCompleted
                    )
                    context.insert(newRecord)
                }
            }
        } catch {
            print("导入番茄钟记录失败: \(error)")
        }
    }
} 