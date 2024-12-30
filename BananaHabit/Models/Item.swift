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
    var item: Item? // 改为直接引用 Item
    
    init(date: Date, value: Int, item: Item) {
        self.date = date
        self.value = value
        self.item = item
    }
} 