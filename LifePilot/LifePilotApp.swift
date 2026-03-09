import SwiftUI
import SwiftData

@main
struct LifePilotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Habit.self,
            HabitCompletion.self
        ])
    }
}
