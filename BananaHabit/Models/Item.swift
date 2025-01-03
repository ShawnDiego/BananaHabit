import Foundation
import SwiftData

@Model
final class Item {
    var name: String
    var createdDate: Date
    @Relationship(deleteRule: .cascade) var moods: [Mood]
    
    init(name: String, createdDate: Date = Date()) {
        self.name = name
        self.createdDate = createdDate
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