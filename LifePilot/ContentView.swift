import SwiftUI

struct ContentView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var quotesViewModel: QuotesViewModel
    @State private var selectedTab = "today"

    var body: some View {
        if authViewModel.isLoggedIn {
            TabView(selection: $selectedTab) {
                Tab(value: "today") {
                    TodayView()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }

                Tab(value: "habits") {
                    HabitListView()
                } label: {
                    Image(systemName: "list.bullet")
                }

                Tab(value: "stats") {
                    StatsView()
                } label: {
                    Image(systemName: "flame.fill")
                }

                Tab(value: "quotes") {
                    QuoteFeedView(quotesViewModel: quotesViewModel, isLoggedIn: authViewModel.isLoggedIn)
                } label: {
                    Image(systemName: "quote.bubble")
                }

                Tab(value: "profile") {
                    ProfileView(authViewModel: authViewModel, quotesViewModel: quotesViewModel)
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        } else {
            AuthView(viewModel: authViewModel)
        }
    }
}
