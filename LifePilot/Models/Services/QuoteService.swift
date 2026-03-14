import Foundation

/// Fetches motivational quotes from the ZenQuotes API.
///
/// Uses async/await with URLSession for networking and caches the daily quote
/// so repeated calls don't trigger redundant network requests.
@Observable
final class QuoteService {

    // MARK: - Singleton

    static let shared = QuoteService()

    // MARK: - Properties

    /// The quote text to display.
    var quoteText: String = ""

    /// The author of the current quote.
    var quoteAuthor: String = ""

    /// Whether a fetch is currently in progress.
    var isLoading = false

    /// Error message if the last fetch failed.
    var errorMessage: String?

    // MARK: - Private

    /// Cached date so we only fetch once per day.
    private var lastFetchDate: Date?

    private init() {}

    // MARK: - API

    /// Fetches a random motivational quote from ZenQuotes.
    ///
    /// Caches the result for the current day. Subsequent calls on the same day
    /// return the cached quote without hitting the network.
    @MainActor
    func fetchDailyQuote() async {
        // Return cached quote if we already fetched today.
        if let lastDate = lastFetchDate,
           Calendar.current.isDateInToday(lastDate),
           !quoteText.isEmpty {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let quote = try await fetchRandomQuote()
            quoteText = quote.text
            quoteAuthor = quote.author
            lastFetchDate = Date()
        } catch {
            errorMessage = error.localizedDescription
            // Provide a fallback quote so the UI always has content.
            if quoteText.isEmpty {
                quoteText = "The secret of getting ahead is getting started."
                quoteAuthor = "Mark Twain"
            }
        }

        isLoading = false
    }

    /// Forces a new quote fetch, ignoring the cache.
    @MainActor
    func refreshQuote() async {
        lastFetchDate = nil
        await fetchDailyQuote()
    }

    // MARK: - Networking

    /// Calls the ZenQuotes random endpoint and decodes the response.
    private func fetchRandomQuote() async throws -> Quote {
        guard let url = URL(string: "https://zenquotes.io/api/random") else {
            throw QuoteError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw QuoteError.serverError
        }

        // ZenQuotes returns an array with a single quote object.
        let decoded = try JSONDecoder().decode([ZenQuoteResponse].self, from: data)

        guard let first = decoded.first else {
            throw QuoteError.noData
        }

        return Quote(text: first.q, author: first.a)
    }
}

// MARK: - Models

/// Internal representation of a motivational quote.
struct Quote {
    let text: String
    let author: String
}

/// Matches the JSON shape returned by ZenQuotes: [{"q": "...", "a": "...", "h": "..."}]
private struct ZenQuoteResponse: Decodable {
    let q: String   // quote text
    let a: String   // author
}

// MARK: - Errors

enum QuoteError: LocalizedError {
    case invalidURL
    case serverError
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:   return "Invalid quote service URL."
        case .serverError:  return "The quote service is unavailable. Try again later."
        case .noData:       return "No quote was returned."
        }
    }
}
