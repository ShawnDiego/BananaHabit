import SwiftUI
import ActivityKit
import WidgetKit

struct PomodoroLiveActivityView: View {
    let context: ActivityViewContext<PomodoroAttributes>
    
    var body: some View {
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
                
                HStack(spacing: 20) {
                    // 进度环
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        
                        Circle()
                            .trim(from: 0, to: context.state.isCountUp ?
                                min(CGFloat(context.state.elapsedTime / 3600), 1.0) :
                                context.state.progress)
                            .stroke(
                                context.state.isCountUp ? Color.green : Color.blue,
                                style: StrokeStyle(
                                    lineWidth: 8,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: context.state.isCountUp ? context.state.elapsedTime : context.state.timeRemaining)
                        
                        Text(context.state.isCountUp ?
                            timeString(from: context.state.elapsedTime) :
                            timeString(from: context.state.timeRemaining))
                            .font(.system(.title2, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(width: 80, height: 80)
                    
                    // 状态和控制
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.isRunning ? "正在进行" : "已暂停")
                            .font(.headline)
                            .foregroundColor(context.state.isRunning ? .blue : .secondary)
                        
                        Text("开始时间: \(timeFormatter.string(from: context.attributes.startTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
//    PomodoroLiveActivityView(
//        context: ActivityViewContext(
//            attributes: attributes,
//            state: state
//        )
//    )
//    .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
//} 
