import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "checkmark.circle.fill") {
                TodayView()
            }

            Tab("Habits", systemImage: "list.bullet") {
                HabitListView()
            }

            Tab("Stats", systemImage: "flame.fill") {
                StatsView()
            }
        }
    }
}
