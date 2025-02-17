import ActivityKit
import Foundation

struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: TimeInterval
        var progress: Double
        var isRunning: Bool
        var isCountUp: Bool
        var elapsedTime: TimeInterval
        var itemName: String?
        var itemIcon: String?
    }
    
    var targetDuration: TimeInterval
    var startTime: Date
    var title: String?
} 