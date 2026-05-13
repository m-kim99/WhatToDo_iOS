import SwiftUI
import SwiftData

private let lineCount = 30
private let paperColor = Color(red: 0.98, green: 0.97, blue: 0.94)
private let lineColor = Color(red: 0.75, green: 0.82, blue: 0.95).opacity(0.7)
private let marginColor = Color(red: 0.88, green: 0.3, blue: 0.3).opacity(0.45)

struct NotepadView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TodoItem]

    let date: Date
    @State private var texts: [Int: String] = [:]
    @State private var repeatItem: TodoItem?

    init(date: Date) {
        self.date = date
        let end = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        _items = Query(
            filter: #Predicate<TodoItem> { item in
                item.date >= date && item.date < end
            },
            sort: \.lineIndex
        )
    }

    private func item(at index: Int) -> TodoItem? {
        items.first { $0.lineIndex == index }
    }

    private func save(index: Int) {
        let text = texts[index] ?? ""
        if let existing = item(at: index) {
            if text.isEmpty {
                modelContext.delete(existing)
            } else {
                existing.title = text
            }
        } else if !text.isEmpty {
            modelContext.insert(TodoItem(title: text, date: date, lineIndex: index))
        }
        try? modelContext.save()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<lineCount, id: \.self) { index in
                    let existing = item(at: index)
                    NotepadLine(
                        text: Binding(
                            get: { texts[index] ?? existing?.title ?? "" },
                            set: { texts[index] = $0 }
                        ),
                        isCompleted: existing?.isCompleted ?? false,
                        onSave: { save(index: index) },
                        onToggle: {
                            existing?.isCompleted.toggle()
                            try? modelContext.save()
                        },
                        onLongPress: {
                            repeatItem = item(at: index)
                        }
                    )
                }
            }
            .padding(.bottom, 60)
        }
        .background(paperColor)
        .sheet(item: $repeatItem) { item in
            RepeatCalendarView(sourceItem: item)
        }
    }
}

struct NotepadLine: View {
    @Binding var text: String
    let isCompleted: Bool
    let onSave: () -> Void
    let onToggle: () -> Void
    let onLongPress: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 0) {
            // 체크박스
            Button(action: onToggle) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.gray.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .overlay {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
            }
            .buttonStyle(.plain)
            .frame(width: 50)
            .opacity(text.isEmpty ? 0.3 : 1)

            // 빨간 여백선
            Rectangle()
                .fill(marginColor)
                .frame(width: 1.5)

            // 텍스트 영역 — 더블탭으로 편집 진입
            ZStack(alignment: .leading) {
                TextField("", text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(isCompleted ? Color.primary.opacity(0.35) : .primary)
                    .padding(.horizontal, 10)
                    .focused($isFocused)
                    .disabled(!isEditing)
                    .submitLabel(.done)
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            isEditing = false
                            onSave()
                        }
                    }

                if isCompleted && !text.isEmpty {
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(height: 1)
                        .padding(.horizontal, 10)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                isEditing = true
                isFocused = true
            }
        }
        .frame(height: 44)
        .background(paperColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(lineColor)
                .frame(height: 1)
        }
        // 롱프레스 — 내용 있는 줄만 반응
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard !text.isEmpty else { return }
                onLongPress()
            }
        )
    }
}
