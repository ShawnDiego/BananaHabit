import Foundation
import SwiftData

@Model
final class PomodoroRecord {
    var id: UUID
    var startTime: Date
    var duration: TimeInterval  // 实际专注时长（秒）
    var targetDuration: TimeInterval  // 目标时长（秒）
    var relatedItem: Item?  // 关联的心情事项
    var note: String?  // 备注
    var isCompleted: Bool  // 是否完成（未中断）
    
    init(id: UUID = UUID(),
         startTime: Date = Date(),
         duration: TimeInterval,
         targetDuration: TimeInterval,
         relatedItem: Item? = nil,
         note: String? = nil,
         isCompleted: Bool = true) {
        self.id = id
        self.startTime = startTime
        self.duration = duration
        self.targetDuration = targetDuration
        self.relatedItem = relatedItem
        self.note = note
        self.isCompleted = isCompleted
    }
} 