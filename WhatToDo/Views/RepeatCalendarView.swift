import SwiftUI
import SwiftData

private let paperColor = Color(red: 0.98, green: 0.97, blue: 0.94)
private let cellHeight: CGFloat = 44

struct RepeatCalendarView: View {
    let sourceItem: TodoItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var displayMonth: Date
    @State private var selectedDates: Set<Date> = []
    @State private var dragStart: Date? = nil
    @State private var dragEnd: Date? = nil
    @State private var gridWidth: CGFloat = 300

    private let calendar = Calendar.current

    init(sourceItem: TodoItem) {
        self.sourceItem = sourceItem
        self._displayMonth = State(initialValue: Calendar.current.startOfDay(for: Date()))
    }

    // 현재 드래그 중인 날짜 범위
    private var dragRange: Set<Date> {
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

    // 셀에 표시할 날짜 = 확정 선택 + 현재 드래그 미리보기
    private var displayDates: Set<Date> {
        selectedDates.union(dragRange)
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
        dragStart = nil
        dragEnd = nil
        // selectedDates는 월 이동해도 유지 (다른 달 날짜도 선택 가능)
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
            modelContext.insert(TodoItem(title: sourceItem.title, date: date, lineIndex: sourceItem.lineIndex))
        }
        try? modelContext.save()
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 안내 헤더
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

            // 월 이동
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

            // 날짜 그리드
            let days = calendarDays
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 0
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        RepeatDayCell(
                            date: date,
                            isSelected: displayDates.contains(date),
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
                        if dragStart == dragEnd, let d = dragStart {
                            // 탭: 개별 날짜 토글
                            if selectedDates.contains(d) {
                                selectedDates.remove(d)
                            } else {
                                selectedDates.insert(d)
                            }
                        } else {
                            // 드래그: 범위를 기존 선택에 추가
                            selectedDates.formUnion(dragRange)
                        }
                        dragStart = nil
                        dragEnd = nil
                    }
            )
            .padding(.horizontal, 4)

            // 선택 현황 + 완료 버튼
            VStack(spacing: 12) {
                if selectedDates.isEmpty {
                    Text("Drag to select a range · Tap to toggle a date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(selectedDates.count) day(s) selected")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                Button(action: duplicate) {
                    Text("Repeat")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedDates.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(selectedDates.isEmpty ? .secondary : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedDates.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(paperColor)
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
                .fontWeight(isSelected || isSource || isToday ? .semibold : .regular)
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
