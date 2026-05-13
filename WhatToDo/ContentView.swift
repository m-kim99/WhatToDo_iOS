import SwiftUI

struct ContentView: View {
    @State private var currentDate = Calendar.current.startOfDay(for: Date())
    @State private var showCalendar = false

    private var dateTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: currentDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { showCalendar = true } label: {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .padding(.leading, 20)
                        .padding(.vertical, 12)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Text(dateTitle)
                        .font(.headline)

                    Button {
                        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                Spacer()

                Image(systemName: "calendar")
                    .font(.title2)
                    .opacity(0)
                    .padding(.trailing, 20)
                    .padding(.vertical, 12)
            }
            .foregroundColor(.primary)
            .background(Color(red: 0.98, green: 0.97, blue: 0.94))

            Divider()

            NotepadView(date: currentDate)
                .id(currentDate)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showCalendar) {
            CalendarView(selectedDate: $currentDate)
                .presentationDetents([.medium])
        }
    }
}
