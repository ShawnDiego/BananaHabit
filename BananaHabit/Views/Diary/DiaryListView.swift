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
            List {
                ForEach(sortedDiaries, id: \.id) { diary in
                    NavigationLink(destination: DiaryDetailView(diary: diary)) {
                        DiaryRowView(diary: diary)
                    }
                }
                .onDelete(perform: deleteDiary)
            }
            .navigationTitle("日记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddDiary = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("按标题", action: { sortOption = .title })
                        Button("按创建时间", action: { sortOption = .createdDate })
                        Button("按修改时间", action: { sortOption = .modifiedDate })
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingAddDiary) {
                DiaryDetailView(diary: nil)
            }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = diary.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            if !contentText.isEmpty {
                Text(contentText)
                    .lineLimit(2)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text(diary.modifiedAt, style: .date)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
} 