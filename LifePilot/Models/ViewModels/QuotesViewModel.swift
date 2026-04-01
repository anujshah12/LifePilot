import Foundation

@Observable
final class QuotesViewModel {

    var quoteText = ""
    var quoteAuthor = ""
    var isLoadingQuote = false

    var bookmarks: [BookmarkRecord] = []
    var isLoadingBookmarks = false
    var isCurrentQuoteBookmarked = false

    var comments: [CommentRecord] = []
    var isLoadingComments = false
    var newCommentText = ""
    var showComments = false

    var errorMessage: String?

    private let supabase = SupabaseService.shared
    private let quoteService = QuoteService.shared

    // MARK: - Quotes

    @MainActor
    func fetchNewQuote() async {
        isLoadingQuote = true
        await quoteService.refreshQuote()
        quoteText = quoteService.quoteText
        quoteAuthor = quoteService.quoteAuthor
        isLoadingQuote = false
        await checkIfBookmarked()
    }

    // MARK: - Bookmarks

    @MainActor
    func toggleBookmark() async {
        guard supabase.isLoggedIn else {
            errorMessage = "Log in to bookmark quotes."
            return
        }
        errorMessage = nil
        if isCurrentQuoteBookmarked {
            if let bookmark = bookmarks.first(where: { $0.quote_text == quoteText }) {
                do {
                    try await supabase.deleteBookmark(id: bookmark.id)
                    bookmarks.removeAll { $0.id == bookmark.id }
                    isCurrentQuoteBookmarked = false
                } catch {
                    errorMessage = "Could not remove bookmark. Please try again."
                }
            }
        } else {
            do {
                let record = try await supabase.addBookmark(quoteText: quoteText, quoteAuthor: quoteAuthor)
                bookmarks.insert(record, at: 0)
                isCurrentQuoteBookmarked = true
            } catch {
                errorMessage = "Could not save bookmark. Please try again."
            }
        }
    }

    @MainActor
    func loadBookmarks() async {
        isLoadingBookmarks = true
        do {
            bookmarks = try await supabase.fetchBookmarks()
        } catch {
            errorMessage = "Could not load bookmarks. Please try again."
        }
        isLoadingBookmarks = false
    }

    @MainActor
    func deleteBookmark(_ bookmark: BookmarkRecord) async {
        do {
            try await supabase.deleteBookmark(id: bookmark.id)
            bookmarks.removeAll { $0.id == bookmark.id }
            if bookmark.quote_text == quoteText {
                isCurrentQuoteBookmarked = false
            }
        } catch {
            errorMessage = "Could not delete bookmark. Please try again."
        }
    }

    @MainActor
    private func checkIfBookmarked() async {
        guard supabase.isLoggedIn, !quoteText.isEmpty else {
            isCurrentQuoteBookmarked = false
            return
        }
        isCurrentQuoteBookmarked = bookmarks.contains { $0.quote_text == quoteText }
        if !isCurrentQuoteBookmarked {
            isCurrentQuoteBookmarked = await supabase.isBookmarked(quoteText: quoteText)
        }
    }

    // MARK: - Comments

    @MainActor
    func loadComments() async {
        guard !quoteText.isEmpty else { return }
        isLoadingComments = true
        do {
            comments = try await supabase.fetchComments(quoteText: quoteText, quoteAuthor: quoteAuthor)
        } catch {
            errorMessage = "Could not load comments. Please try again."
        }
        isLoadingComments = false
    }

    @MainActor
    func postComment() async {
        guard supabase.isLoggedIn else {
            errorMessage = "Log in to post comments."
            return
        }
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        do {
            let record = try await supabase.addComment(
                quoteText: quoteText,
                quoteAuthor: quoteAuthor,
                content: text
            )
            comments.insert(record, at: 0)
            newCommentText = ""
        } catch {
            errorMessage = "Could not post comment. Please try again."
        }
    }

    @MainActor
    func clearUserData() {
        bookmarks = []
        isCurrentQuoteBookmarked = false
        comments = []
    }
}
