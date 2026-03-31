import SwiftUI

struct QuoteFeedView: View {
    @Bindable var quotesViewModel: QuotesViewModel
    let isLoggedIn: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    quoteCard
                    commentsSection
                }
                .padding()
            }
            .navigationTitle("Quotes")
            .sheet(isPresented: $quotesViewModel.showComments) {
                CommentsSheet(viewModel: quotesViewModel, isLoggedIn: isLoggedIn)
            }
            .task {
                if quotesViewModel.quoteText.isEmpty {
                    await quotesViewModel.fetchNewQuote()
                }
            }
        }
    }

    private var quoteCard: some View {
        VStack(spacing: 16) {
            if quotesViewModel.isLoadingQuote {
                ProgressView()
                    .padding(40)
            } else {
                Image(systemName: "quote.opening")
                    .font(.title)
                    .foregroundStyle(.blue.opacity(0.6))

                Text(quotesViewModel.quoteText)
                    .font(.title3)
                    .italic()
                    .multilineTextAlignment(.center)

                Text("- \(quotesViewModel.quoteAuthor)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 32) {
                Button {
                    Task { await quotesViewModel.fetchNewQuote() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }

                Button {
                    Task { await quotesViewModel.toggleBookmark() }
                } label: {
                    Image(systemName: quotesViewModel.isCurrentQuoteBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                }
                .tint(quotesViewModel.isCurrentQuoteBookmarked ? .yellow : .blue)

                Button {
                    Task {
                        await quotesViewModel.loadComments()
                        quotesViewModel.showComments = true
                    }
                } label: {
                    Image(systemName: "bubble.left")
                        .font(.title3)
                }
            }

            if let error = quotesViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Comments")
                    .font(.headline)
                Spacer()
                Button("View All") {
                    Task {
                        await quotesViewModel.loadComments()
                        quotesViewModel.showComments = true
                    }
                }
                .font(.subheadline)
            }

            if quotesViewModel.comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(quotesViewModel.comments.prefix(3)) { comment in
                    CommentRow(comment: comment)
                }
            }
        }
        .task {
            if !quotesViewModel.quoteText.isEmpty {
                await quotesViewModel.loadComments()
            }
        }
    }
}

struct CommentRow: View {
    let comment: CommentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundStyle(.secondary)
                Text(comment.user_email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(comment.content)
                .font(.subheadline)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: comment.created_at) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: comment.created_at) else { return "" }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
