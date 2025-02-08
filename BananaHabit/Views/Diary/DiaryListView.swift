import SwiftUI
import SwiftData

enum DiarySort {
    case title
    case createdDate
    case modifiedDate
}

struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var diaries: [Diary]
    @State private var sortOption: DiarySort = .modifiedDate
    @State private var showingAddDiary = false
    
    init() {
        let sortDescriptors: [SortDescriptor<Diary>] = [
            SortDescriptor(\Diary.modifiedAt, order: .reverse)
        ]
        _diaries = Query(sort: sortDescriptors)
    }
    
    var groupedDiaries: [(String, [Diary])] {
        let grouped = Dictionary(grouping: sortedDiaries) { diary -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月"
            return formatter.string(from: diary.modifiedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var sortedDiaries: [Diary] {
        switch sortOption {
        case .title:
            return diaries.sorted { ($0.title ?? "") < ($1.title ?? "") }
        case .createdDate:
            return diaries.sorted { $0.createdAt > $1.createdAt }
        case .modifiedDate:
            return diaries.sorted { $0.modifiedAt > $1.modifiedAt }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if diaries.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(groupedDiaries, id: \.0) { month, monthDiaries in
                                Section(header: monthHeaderView(month: month)) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(monthDiaries.enumerated()), id: \.element.id) { index, diary in
                                            NavigationLink(destination: DiaryDetailView(diary: diary)) {
                                                DiaryRowView(
                                                    diary: diary,
                                                    isLastInSection: index == monthDiaries.count - 1
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("日记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddDiary = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18))
                    }
                }
            }
            .sheet(isPresented: $showingAddDiary) {
                DiaryDetailView(diary: nil)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.8))
            
            VStack(spacing: 8) {
                Text("还没有任何日记")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("记录下你的心情故事吧")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button {
                showingAddDiary = true
            } label: {
                Label("写下第一篇日记", systemImage: "square.and.pencil")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private func monthHeaderView(month: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(month)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            // 添加渐变分隔线
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemGroupedBackground),
                    Color(.systemGroupedBackground).opacity(0.5),
                    Color(.systemGroupedBackground).opacity(0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 8)
        }
    }
    
    private func deleteDiary(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedDiaries[index])
        }
        try? modelContext.save()
    }
}

struct DiaryRowView: View {
    let diary: Diary
    let isLastInSection: Bool
    
    var contentText: String {
        guard !diary.content.isEmpty,
              let data = diary.content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let items = json["items"] as? [[String: Any]],
              let firstItem = items.first,
              let content = firstItem["content"] as? String else {
            return ""
        }
        return content
    }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: diary.modifiedAt)
    }
    
    var weekDay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: diary.modifiedAt)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: diary.modifiedAt)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // 左侧日期显示
                VStack(spacing: 2) {
                    Text(dayNumber)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                    Text(weekDay)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(width: 40)
                
                // 时间线
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: 6, height: 6)
                    if !isLastInSection {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    }
                }
                .padding(.top, 8)
                
                // 右侧内容区
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let title = diary.title, !title.isEmpty {
                            Text(title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text(timeString)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    if !contentText.isEmpty {
                        Text(contentText)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .lineSpacing(2)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            
            if !isLastInSection {
                Divider()
                    .padding(.leading, 68)
            }
        }
    }
} 
