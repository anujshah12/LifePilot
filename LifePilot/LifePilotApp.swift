import SwiftUI
import SwiftData

@main
struct LifePilotApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var quotesViewModel = QuotesViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(authViewModel: authViewModel, quotesViewModel: quotesViewModel)
        }
        .modelContainer(for: [
            Habit.self,
            HabitCompletion.self
        ])
    }
}
