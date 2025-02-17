//
//  PomodoroWidget.swift
//  PomodoroWidget
//
//  Created by 邵文萱(ShaoWenxuan)-顺丰科技技术集团 on 2025/2/17.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct PomodoroWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("Time:")
            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
            Text(entry.configuration.favoriteEmoji)
        }
    }
}

struct PomodoroWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            PomodoroLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 扩展视图
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.isRunning ? "进行中" : "已暂停")
                    } icon: {
                        Image(systemName: context.state.isRunning ? "play.circle.fill" : "pause.circle.fill")
                    }
                    .font(.headline)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(context.state.isCountUp ?
                            timeString(from: context.state.elapsedTime) :
                            timeString(from: context.state.timeRemaining))
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.headline)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    if let itemName = context.state.itemName,
                       let itemIcon = context.state.itemIcon {
                        Label(itemName, systemImage: itemIcon)
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // 进度条
                    ProgressView(
                        value: context.state.isCountUp ?
                            min(context.state.elapsedTime / 3600, 1.0) :
                            context.state.progress
                    )
                    .tint(context.state.isCountUp ? .green : .blue)
                }
            } compactLeading: {
                // 紧凑前导视图
                Image(systemName: context.state.isRunning ? "play.circle.fill" : "pause.circle.fill")
                    .foregroundColor(context.state.isRunning ? .blue : .secondary)
            } compactTrailing: {
                // 紧凑尾随视图
                Text(context.state.isCountUp ?
                    timeString(from: context.state.elapsedTime) :
                    timeString(from: context.state.timeRemaining))
                .monospacedDigit()
                .font(.system(.body, design: .rounded))
            } minimal: {
                // 最小视图
                Image(systemName: "timer")
                    .foregroundColor(context.state.isRunning ? .blue : .secondary)
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

//#Preview {
//    let attributes = PomodoroAttributes(
//        targetDuration: 1500,
//        startTime: Date(),
//        title: "专注工作"
//    )
//    let state = PomodoroAttributes.ContentState(
//        timeRemaining: 1200,
//        progress: 0.2,
//        isRunning: true,
//        isCountUp: false,
//        elapsedTime: 300,
//        itemName: "工作",
//        itemIcon: "briefcase.fill"
//    )
//    
//    let previewContext = ActivityContent(state: state, stateDate: Date())
//    let context = ActivityPreviewContext(attributes: attributes, content: previewContext)
//    
//    return PomodoroLiveActivityView(context: context)
//        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
//}
