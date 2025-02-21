import SwiftUI
import ActivityKit
import WidgetKit

public struct PomodoroLiveActivityView: View {
    let context: ActivityViewContext<PomodoroAttributes>
    
    public init(context: ActivityViewContext<PomodoroAttributes>) {
        self.context = context
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
            
            VStack(spacing: 12) {
                HStack {
                    if let title = context.attributes.title {
                        Text(title)
                            .font(.headline)
                    } else {
                        Text("专注")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    if let itemName = context.state.itemName,
                       let itemIcon = context.state.itemIcon {
                        HStack(spacing: 4) {
                            Image(systemName: itemIcon)
                            Text(itemName)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                
                HStack() {
                    // 时间显示和进度背景
                    ZStack {
                        // 背景进度条
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(context.state.isCountUp ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                                .frame(width: geometry.size.width * (context.state.isCountUp ? 
                                    min(CGFloat(context.state.elapsedTime / 3600), 1.0) : 
                                    context.state.progress))
                        }
                        
                        HStack {
                            // 大字体时间显示
                            Text(context.state.isCountUp ?
                                timeString(from: context.state.elapsedTime) :
                                timeString(from: context.state.timeRemaining))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(context.state.isCountUp ? .green : .blue)
                                .padding(.leading, 20)
                            
                            Spacer()
                            
                            // 状态和控制
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(context.state.isRunning ? "正在进行" : "已暂停")
                                    .font(.headline)
                                    .foregroundColor(context.state.isRunning ? .blue : .secondary)
                                
                                Text("开始时间: \(timeFormatter.string(from: context.attributes.startTime))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 20)
                        }
                    }
                    .frame(height: 80)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
            }
            .padding()
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        

        return String(format: "%02d:%02d", minutes, seconds)
        
    }
    
    private var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
} 
