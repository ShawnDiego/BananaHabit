import SwiftUI
import SwiftData
import Charts


struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectedTab) private var selectedTab
    @Query private var items: [Item]
    @Query private var diaries: [Diary]
    @Query(sort: \PomodoroRecord.startTime, order: .reverse) private var records: [PomodoroRecord]
    @State private var showingAddItem = false
    @EnvironmentObject private var userVM: UserViewModel
    @EnvironmentObject private var pomodoroTimer: PomodoroTimer
    @State private var showingUserProfile = false
    @State private var showingMoodInput = false
    @State private var selectedItemId: PersistentIdentifier?
    @State private var isItemSelectorExpanded = false
    
    var selectedItem: Item? {
        if let selectedItemId = selectedItemId {
            return items.first { $0.persistentModelID == selectedItemId }
        }
        return items.first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户信息头部
                    userProfileHeader
                    
                    // 当前番茄钟状态
                    if pomodoroTimer.isRunning {
                        currentPomodoroStatus
                    }
                    
                    if items.isEmpty {
                        emptyStateView
                    } else {
                        // 事项选择器
                        itemSelector
                        
                        if let item = selectedItem {
                            // 心情快速记录区域
                            if hasTodayMood(item) {
                                TodayMoodView(item: item)
                            } else {
                                AddMoodButton {
                                    showingMoodInput = true
                                }
                            }
                            
                            // 统计汇总视图
                            StatsOverviewView(items: [item], diaries: diaries, records: records)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView()
                .environmentObject(userVM)
        }
        .sheet(isPresented: $showingMoodInput) {
            if let item = selectedItem {
                QuickMoodInputView(preSelectedItem: item)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .onAppear {
            if selectedItemId == nil, let firstItem = items.first {
                selectedItemId = firstItem.persistentModelID
            }
        }
    }
    
    // MARK: - 组件
    
    private var currentPomodoroStatus: some View {
        Button {
            selectedTab.wrappedValue = 2  // 切换到专注标签页
        } label: {
            HStack(spacing: 16) {
                Text(pomodoroTimer.isCountUp ?
                        timeString(from: pomodoroTimer.elapsedTime) :
                        timeString(from: pomodoroTimer.timeRemaining))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(pomodoroTimer.isCountUp ? Color.green : Color.blue)
                
                VStack(alignment: .leading) {
                    Text("正在进行的番茄钟")
                        .font(.headline)
                    Text(pomodoroTimer.isCountUp ? "正计时" : "倒计时")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(pomodoroTimer.isCountUp ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
            )
            .padding(.horizontal)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            // 主要的添加习惯卡片
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                
                VStack(spacing: 12) {
                    Text("开始记录你的第一个事项心情")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("添加一个你想要记录的事项\n观察每天的心情变化")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    showingAddItem = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加事项")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
            .padding(.horizontal)
            
            // 功能预览区域
            VStack(alignment: .leading, spacing: 20) {
                Text("添加事项心情后，你可以...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // 心情记录预览
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.gray.opacity(0.5))
                        Text("每日心情记录")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { value in
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .opacity(0.7)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                )
                .padding(.horizontal)
                
                // 趋势图表预览
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.gray.opacity(0.5))
                        Text("心情趋势分析")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 50))
                        path.addCurve(
                            to: CGPoint(x: 300, y: 30),
                            control1: CGPoint(x: 100, y: 0),
                            control2: CGPoint(x: 200, y: 60)
                        )
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(height: 80)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .opacity(0.7)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                )
                .padding(.horizontal)
                
                // 统计概览预览
                HStack(spacing: 20) {
                    // 连续记录预览
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange.opacity(0.3))
                            Text("连续记录")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        Text("-- 天")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 周平均预览
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue.opacity(0.3))
                            Text("周平均")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        Text("--")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .opacity(0.7)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                )
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    

    
    private var itemSelector: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedItemId = item.persistentModelID
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ItemIconView(
                                    icon: item.icon,
                                    size: 24,
                                    color: selectedItemId == item.persistentModelID ? .blue : .gray
                                )
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundColor(selectedItemId == item.persistentModelID ? .blue : .primary)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedItemId == item.persistentModelID ? 
                                          Color.blue.opacity(0.1) : 
                                          Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        showingAddItem = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                            Text("添加事项")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                .background(Color.blue.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var userProfileHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(userVM.getGreeting())")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if userVM.isAuthenticated, let user = userVM.currentUser {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Text("点击登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                showingUserProfile = true
            } label: {
                if userVM.isAuthenticated, let user = userVM.currentUser,
                   let avatarUrl = user.avatarUrl {
                    // 添加随机查询参数强制刷新
                    AsyncImage(url: URL(string: "file://\(avatarUrl)?cache=\(UUID().uuidString)")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
    

    

    

    
    // MARK: - 辅助函数
    
    private func hasTodayMood(_ item: Item) -> Bool {
        let calendar = Calendar.current
        return item.moods.contains { calendar.isDate($0.date, inSameDayAs: Date()) }
    }
    

    

}





#Preview {
    OverviewView()
        .modelContainer(for: Item.self, inMemory: true)
}
