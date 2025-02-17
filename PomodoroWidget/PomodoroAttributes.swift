import ActivityKit
import Foundation

public struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var timeRemaining: TimeInterval
        public var progress: Double
        public var isRunning: Bool
        public var isCountUp: Bool
        public var elapsedTime: TimeInterval
        public var itemName: String?
        public var itemIcon: String?
        public var showSeconds: Bool
        
        public init(
            timeRemaining: TimeInterval,
            progress: Double,
            isRunning: Bool,
            isCountUp: Bool,
            elapsedTime: TimeInterval,
            itemName: String? = nil,
            itemIcon: String? = nil,
            showSeconds: Bool
        ) {
            self.timeRemaining = timeRemaining
            self.progress = progress
            self.isRunning = isRunning
            self.isCountUp = isCountUp
            self.elapsedTime = elapsedTime
            self.itemName = itemName
            self.itemIcon = itemIcon
            self.showSeconds = showSeconds
        }
    }
    
    public var targetDuration: TimeInterval
    public var startTime: Date
    public var title: String?
    
    public init(
        targetDuration: TimeInterval,
        startTime: Date,
        title: String? = nil
    ) {
        self.targetDuration = targetDuration
        self.startTime = startTime
        self.title = title
    }
} 