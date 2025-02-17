//
//  PomodoroWidgetLiveActivity.swift
//  PomodoroWidget
//
//  Created by 邵文萱(ShaoWenxuan)-顺丰科技技术集团 on 2025/2/17.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PomodoroWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PomodoroWidgetAttributes {
    fileprivate static var preview: PomodoroWidgetAttributes {
        PomodoroWidgetAttributes(name: "World")
    }
}

extension PomodoroWidgetAttributes.ContentState {
    fileprivate static var smiley: PomodoroWidgetAttributes.ContentState {
        PomodoroWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PomodoroWidgetAttributes.ContentState {
         PomodoroWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PomodoroWidgetAttributes.preview) {
   PomodoroWidgetLiveActivity()
} contentStates: {
    PomodoroWidgetAttributes.ContentState.smiley
    PomodoroWidgetAttributes.ContentState.starEyes
}
