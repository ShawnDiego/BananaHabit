//
//  AppIntent.swift
//  PomodoroWidget
//
//  Created by 邵文萱(ShaoWenxuan)-顺丰科技技术集团 on 2025/2/17.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
