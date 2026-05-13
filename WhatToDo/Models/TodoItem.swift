import Foundation
import SwiftData

@Model
class TodoItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var date: Date
    var lineIndex: Int
    var createdAt: Date

    init(title: String, date: Date, lineIndex: Int) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.date = date
        self.lineIndex = lineIndex
        self.createdAt = Date()
    }
}
