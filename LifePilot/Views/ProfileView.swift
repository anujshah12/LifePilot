import SwiftUI

struct ProfileView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var quotesViewModel: QuotesViewModel

    var body: some View {
        NavigationStack {
            if authViewModel.isLoggedIn {
                loggedInView
            } else {
                AuthView(viewModel: authViewModel)
                    .navigationTitle("Profile")
            }
        }
    }

    private var loggedInView: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Logged In")
                            .font(.headline)
                        Text(authViewModel.userEmail ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Bookmarked Quotes") {
                if quotesViewModel.isLoadingBookmarks {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if quotesViewModel.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Browse quotes and tap the bookmark icon to save them here.")
                    )
                } else {
                    ForEach(quotesViewModel.bookmarks) { bookmark in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\"\(bookmark.quote_text)\"")
                                .font(.subheadline)
                                .italic()
                            Text("- \(bookmark.quote_author)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await quotesViewModel.deleteBookmark(bookmark) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                        quotesViewModel.clearUserData()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Log Out")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .task {
            await quotesViewModel.loadBookmarks()
        }
    }
}
