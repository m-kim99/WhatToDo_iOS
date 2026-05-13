import SwiftUI
import SwiftData

@main
struct WhatToDoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TodoItem.self])
    }
}
