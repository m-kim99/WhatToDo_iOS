import SwiftUI
import SwiftData

private let paperColor = Color(red: 0.98, green: 0.97, blue: 0.94)
private let cellHeight: CGFloat = 44

struct RepeatCalendarView: View {
    let sourceItem: TodoItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var displayMonth: Date
    @State private var dragStart: Date? = nil
    @State private var dragEnd: Date? = nil
    @State private var gridWidth: CGFloat = 300

    private let calendar = Calendar.current

    init(sourceItem: TodoItem) {
        self.sourceItem = sourceItem
        self._displayMonth = State(initialValue: Calendar.current.startOfDay(for: Date()))
    }

    // 드래그 범위에 포함된 날짜들
    private var selectedDates: Set<Date> {
        guard let s = dragStart, let e = dragEnd else { return [] }
        let (early, late) = s <= e ? (s, e) : (e, s)
        var result = Set<Date>()
        var cur = early
        while cur <= late {
            result.insert(cur)
            cur = calendar.date(byAdding: .day, value: 1, to: cur) ?? late
        }
        return result
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMM", options: 0, locale: .current)
        return f.string(from: displayMonth)
    }

    private func changeMonth(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayMonth) else { return }
        displayMonth = next
        // 월 이동 시 선택 초기화
        dragStart = nil
        dragEnd = nil
    }

    private var orderedDaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func weekday(forColumn col: Int) -> Int {
        (col + calendar.firstWeekday - 1) % 7 + 1
    }

    private var calendarDays: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayMonth)
        let firstDay = calendar.date(from: comps)!
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)!.count

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for i in 0..<daysInMonth {
            days.append(calendar.date(byAdding: .day, value: i, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    // 드래그 위치 → 날짜
    private func date(at location: CGPoint, in days: [Date?]) -> Date? {
        let cellW = gridWidth / 7
        guard cellW > 0 else { return nil }
        let col = max(0, min(6, Int(location.x / cellW)))
        let row = max(0, Int(location.y / cellHeight))
        let index = row * 7 + col
        guard index < days.count else { return nil }
        return days[index]
    }

    private func duplicate() {
        for date in selectedDates {
            let newItem = TodoItem(title: sourceItem.title, date: date, lineIndex: sourceItem.lineIndex)
            modelContext.insert(newItem)
        }
        try? modelContext.save()
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 안내
            VStack(spacing: 4) {
                Text("Repeat task on selected dates")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\"\(sourceItem.title)\"")
                    .font(.headline)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // 월 이동 헤더
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
            }
            .foregroundColor(.primary)

            Divider()

            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(Array(orderedDaySymbols.enumerated()), id: \.offset) { col, symbol in
                    let wd = weekday(forColumn: col)
                    Text(symbol)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(wd == 1 ? .red : wd == 7 ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }

            Divider()

            // 날짜 그리드 + 드래그 제스처
            let days = calendarDays
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 0
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        RepeatDayCell(
                            date: date,
                            isSelected: selectedDates.contains(date),
                            isToday: calendar.isDateInToday(date),
                            isSource: calendar.isDate(date, inSameDayAs: sourceItem.date)
                        )
                    } else {
                        Color.clear.frame(height: cellHeight)
                    }
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { gridWidth = geo.size.width }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if let d = date(at: value.location, in: days) {
                            if dragStart == nil { dragStart = d }
                            dragEnd = d
                        }
                    }
                    .onEnded { _ in
                        guard !selectedDates.isEmpty else { return }
                        duplicate()
                    }
            )
            .padding(.horizontal, 4)

            // 선택 현황
            Group {
                if selectedDates.isEmpty {
                    Text("Drag across dates to repeat")
                        .foregroundColor(.secondary)
                } else {
                    Text("Repeating on \(selectedDates.count) day(s)")
                        .foregroundColor(.blue)
                }
            }
            .font(.subheadline)
            .padding(.top, 14)

            Spacer()
        }
        .background(paperColor)
        .interactiveDismissDisabled(!selectedDates.isEmpty)
    }
}

private struct RepeatDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isSource: Bool

    private let calendar = Calendar.current
    private var day: Int { calendar.component(.day, from: date) }
    private var weekday: Int { calendar.component(.weekday, from: date) }

    var body: some View {
        ZStack {
            if isSelected {
                // 사용자가 말한 "네모칸으로 배경색 칠해진" 형태
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.25))
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
            } else if isSource {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.orange, lineWidth: 1.5)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
            } else if isToday {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.4), lineWidth: 1)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
            }

            Text("\(day)")
                .font(.system(size: 15))
                .fontWeight(isToday || isSelected || isSource ? .semibold : .regular)
                .foregroundColor(
                    weekday == 1 ? .red :
                    weekday == 7 ? .blue :
                    .primary
                )
        }
        .frame(height: cellHeight)
        .frame(maxWidth: .infinity)
    }
}
