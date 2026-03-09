import SwiftUI
import SwiftData

@main
struct LifePilotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            TaskItem.self,
            TaskCategory.self,
            DayPlan.self,
            DayTask.self,
            Template.self,
            TemplateTask.self
        ])
    }
}
