import Foundation
import SwiftData

@Model
final class Item {
    var name: String
    var createdDate: Date
    var sortOrder: Int // 添加排序字段
    var icon: String // 添加图标字段
    @Relationship(deleteRule: .cascade) var moods: [Mood]
    
    init(name: String, createdDate: Date = Date(), icon: String = "star.fill") {
        self.name = name
        self.createdDate = createdDate
        self.sortOrder = 0 // 默认排序值
        self.icon = icon
        self.moods = []
    }
}

@Model
final class Mood {
    var date: Date
    var value: Int // 1-5 表示心情值
    var note: String // 添加备注字段
    var item: Item?
    
    init(date: Date, value: Int, note: String = "", item: Item) {
        self.date = date
        self.value = value
        self.note = note
        self.item = item
    }
} 