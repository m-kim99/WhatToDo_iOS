import SwiftUI

private let paperColor = Color(red: 0.98, green: 0.97, blue: 0.94)

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var displayMonth: Date

    private let calendar = Calendar.current

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._displayMonth = State(initialValue: selectedDate.wrappedValue)
    }

    // 기기 로케일 기반 월 제목 (예: "May 2026", "2026년 5월")
    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "yMMMM",
            options: 0,
            locale: .current
        )
        return f.string(from: displayMonth)
    }

    // 기기 첫째 요일 기준으로 정렬된 요일 약자
    private var orderedDaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols // ["S","M",…] or ["일","월",…]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    // 첫째 요일 기준 열 인덱스 → 실제 weekday (1=일, 7=토)
    private func weekday(forColumn col: Int) -> Int {
        (col + calendar.firstWeekday - 1) % 7 + 1
    }

    private func changeMonth(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayMonth) else { return }
        displayMonth = next
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

    var body: some View {
        VStack(spacing: 0) {
            // 월 이동 헤더
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()

                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
            }
            .foregroundColor(.primary)

            Divider()

            // 요일 헤더 (로케일/첫째요일 자동 반영)
            HStack(spacing: 0) {
                ForEach(Array(orderedDaySymbols.enumerated()), id: \.offset) { col, symbol in
                    let wd = weekday(forColumn: col)
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(wd == 1 ? .red : wd == 7 ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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
                        CalendarDayCell(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                        )
                        .onTapGesture {
                            selectedDate = calendar.startOfDay(for: date)
                            dismiss()
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .background(paperColor)
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool

    private let calendar = Calendar.current

    private var day: Int { calendar.component(.day, from: date) }
    private var weekday: Int { calendar.component(.weekday, from: date) }

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.primary).frame(width: 36, height: 36)
            } else if isToday {
                Circle().stroke(Color.primary, lineWidth: 1.5).frame(width: 36, height: 36)
            }

            Text("\(day)")
                .font(.system(size: 15))
                .fontWeight(isToday || isSelected ? .semibold : .regular)
                .foregroundColor(
                    isSelected ? paperColor :
                    weekday == 1 ? .red :
                    weekday == 7 ? .blue :
                    .primary
                )
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }
}
