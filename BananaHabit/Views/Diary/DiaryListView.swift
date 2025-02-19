import SwiftUI
import SwiftData

// 用于表示日记内容的结构
fileprivate struct DiaryContent: Codable {
    struct ContentItem: Codable {
        enum ContentType: String, Codable {
            case text
            case image
        }
        
        let type: ContentType
        var content: String
    }
    
    var items: [ContentItem]
}

enum DiarySort {
    case title
    case createdDate
    case modifiedDate
}

struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Diary.modifiedAt, order: .reverse) private var diaries: [Diary]
    @State private var showingDeleteAlert = false
    @State private var diaryToDelete: Diary?
    @State private var showingAddDiary = false
    
    var groupedDiaries: [(String, [Diary])] {
        let grouped = Dictionary(grouping: diaries) { diary -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月"
            return formatter.string(from: diary.modifiedAt)
        }
        return grouped.sorted { $0.key > $1.key }
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
                                            DiaryItemView(
                                                diary: diary,
                                                isLastInSection: index == monthDiaries.count - 1,
                                                onDelete: {
                                                    diaryToDelete = diary
                                                    showingDeleteAlert = true
                                                }
                                            )
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
        }
        .sheet(isPresented: $showingAddDiary) {
            NavigationView {
                DiaryDetailView(diary: nil)
            }
        }
        .alert("删除日记", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                diaryToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let diary = diaryToDelete {
                    withAnimation {
                        modelContext.delete(diary)
                        try? modelContext.save()
                    }
                }
                diaryToDelete = nil
            }
        } message: {
            Text("确定要删除这篇日记吗？此操作无法撤销。")
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
}

private struct DiaryItemView: View {
    let diary: Diary
    let isLastInSection: Bool
    let onDelete: () -> Void
    
    var body: some View {
        NavigationLink(destination: DiaryDetailView(diary: diary)) {
            DiaryRowView(
                diary: diary,
                isLastInSection: isLastInSection
            )
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(alignment: .bottom) {
            if !isLastInSection {
                Divider()
                    .padding(.leading, 68)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除日记", systemImage: "trash")
            }
        }
    }
}

private struct DiaryRowView: View {
    let diary: Diary
    let isLastInSection: Bool
    
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
            .padding(.top, 2)
            
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
            .padding(.top, 10)
            
            // 右侧内容区
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    if let title = diary.title, !title.isEmpty {
                        Text(diary.isLocked ? "加密日记" : title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    if diary.isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    
                    Spacer()
                    Text(timeString)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                if !diary.isLocked {
                    if let preview = getContentPreview(diary.content), !preview.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Text(preview)
                                .font(.system(size: 15))
                                .foregroundColor(diary.title == nil ? .primary : .secondary)
                                .lineLimit(3)
                                .lineSpacing(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if diary.title == nil {
                                Text(timeString)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if diary.title == nil {
                        // 当标题和预览都为空时，显示时间
                        HStack {
                            Spacer()
                            Text(timeString)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("内容已加密")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                
                // 关联信息
                if let item = diary.relatedItem {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Text(item.name)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        if let date = diary.selectedDate {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(formatDate(date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .frame(minHeight: 24)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
    
    private func getContentPreview(_ content: String) -> String? {
        if let data = content.data(using: .utf8),
           let diaryContent = try? JSONDecoder().decode(DiaryContent.self, from: data) {
            let textContent = diaryContent.items
                .filter { $0.type == .text }
                .map { $0.content }
                .joined()
            return textContent.isEmpty ? nil : textContent
        }
        return content.isEmpty ? nil : content
    }
} 
