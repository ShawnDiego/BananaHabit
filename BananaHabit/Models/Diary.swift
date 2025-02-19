import Foundation
import SwiftUI
import SwiftData

@Model
final class Diary {
    var id: UUID
    var title: String?
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var images: [Data]
    var relatedItem: Item?
    var selectedDate: Date?
    var isLocked: Bool = false 
    var password: String?
    
    init(id: UUID = UUID(), 
         title: String? = nil,
         content: String = "",
         createdAt: Date = Date(),
         modifiedAt: Date = Date(),
         images: [Data] = [],
         relatedItem: Item? = nil,
         selectedDate: Date? = nil,
         isLocked: Bool = false,
         password: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.images = images
        self.relatedItem = relatedItem
        self.selectedDate = selectedDate
        self.isLocked = isLocked
        self.password = password
    }
} 
