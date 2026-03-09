import SwiftUI
import SwiftData

struct ContentView: View {

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                TodayView()
            }

            Tab("Templates", systemImage: "doc.on.doc.fill") {
                TemplateListView()
            }

            Tab("History", systemImage: "calendar") {
                WeeklyDashboardView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    CategoryManagerView()
                } label: {
                    Label("Categories", systemImage: "tag.fill")
                }

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell.fill")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
