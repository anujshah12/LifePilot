import Foundation

// MARK: - Configuration
// Replace these with your Supabase project values from:
// https://supabase.com/dashboard → Project Settings → API
enum SupabaseConfig {
    static let projectURL = "https://qdezssvoznpivdkqvprv.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkZXpzc3Zvem5waXZka3F2cHJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5NjU2OTIsImV4cCI6MjA5MDU0MTY5Mn0.a0leBQluAmcjkVTULBthUu9lGC_-aHKX7L8Y0YTi8GU"
}

// MARK: - Supabase Service

@Observable
final class SupabaseService {

    static let shared = SupabaseService()

    // Auth state
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var currentUserId: String?
    private(set) var currentUserEmail: String?

    var isLoggedIn: Bool { accessToken != nil }

    private let defaults = UserDefaults.standard

    private init() {
        restoreSession()
    }

    // MARK: - Session Persistence

    private func restoreSession() {
        accessToken = defaults.string(forKey: "sb_access_token")
        refreshToken = defaults.string(forKey: "sb_refresh_token")
        currentUserId = defaults.string(forKey: "sb_user_id")
        currentUserEmail = defaults.string(forKey: "sb_user_email")
    }

    private func saveSession(access: String, refresh: String, userId: String, email: String) {
        accessToken = access
        refreshToken = refresh
        currentUserId = userId
        currentUserEmail = email
        defaults.set(access, forKey: "sb_access_token")
        defaults.set(refresh, forKey: "sb_refresh_token")
        defaults.set(userId, forKey: "sb_user_id")
        defaults.set(email, forKey: "sb_user_email")
    }

    private func clearSession() {
        accessToken = nil
        refreshToken = nil
        currentUserId = nil
        currentUserEmail = nil
        defaults.removeObject(forKey: "sb_access_token")
        defaults.removeObject(forKey: "sb_refresh_token")
        defaults.removeObject(forKey: "sb_user_id")
        defaults.removeObject(forKey: "sb_user_email")
    }

    // MARK: - Auth

    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/signup")!
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": [
                "first_name": firstName,
                "last_name": lastName
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError(errorBody)
        }

        // If email confirmation is disabled, response includes tokens — log in directly.
        // If enabled, response has the user but no access_token — auto sign in after.
        if let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data),
           !authResponse.access_token.isEmpty {
            saveSession(
                access: authResponse.access_token,
                refresh: authResponse.refresh_token,
                userId: authResponse.user.id,
                email: authResponse.user.email ?? email
            )
        } else {
            // Email confirmation is off but response shape differs, or confirmation is on.
            // Try signing in immediately.
            try await signIn(email: email, password: password)
        }
    }

    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=password")!
        let body: [String: String] = ["email": email, "password": password]
        let response: AuthResponse = try await post(url: url, body: body, authenticated: false)
        saveSession(
            access: response.access_token,
            refresh: response.refresh_token,
            userId: response.user.id,
            email: response.user.email ?? email
        )
    }

    func signOut() async {
        if let token = accessToken {
            let url = URL(string: "\(SupabaseConfig.projectURL)/auth/v1/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        clearSession()
    }

    // MARK: - Bookmarks

    func fetchBookmarks() async throws -> [BookmarkRecord] {
        guard let userId = currentUserId, let token = accessToken else { return [] }
        let urlString = "\(SupabaseConfig.projectURL)/rest/v1/bookmarks?select=*&user_id=eq.\(userId)&order=created_at.desc"
        let url = URL(string: urlString)!
        return try await get(url: url, token: token)
    }

    func addBookmark(quoteText: String, quoteAuthor: String) async throws -> BookmarkRecord {
        guard let userId = currentUserId, let token = accessToken else {
            throw SupabaseError.notAuthenticated
        }
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/bookmarks")!
        let body: [String: String] = [
            "user_id": userId,
            "quote_text": quoteText,
            "quote_author": quoteAuthor
        ]
        let results: [BookmarkRecord] = try await post(url: url, body: body, token: token)
        guard let record = results.first else { throw SupabaseError.noData }
        return record
    }

    func deleteBookmark(id: String) async throws {
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/bookmarks?id=eq.\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.serverError
        }
    }

    func isBookmarked(quoteText: String) async -> Bool {
        guard let userId = currentUserId, let token = accessToken else { return false }
        let encoded = quoteText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(SupabaseConfig.projectURL)/rest/v1/bookmarks?select=id&user_id=eq.\(userId)&quote_text=eq.\(encoded)"
        guard let url = URL(string: urlString) else { return false }
        let results: [BookmarkRecord] = (try? await get(url: url, token: token)) ?? []
        return !results.isEmpty
    }

    // MARK: - Comments

    func fetchComments(quoteText: String, quoteAuthor: String) async throws -> [CommentRecord] {
        let params = [
            "select=*",
            "quote_text=eq.\(quoteText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            "quote_author=eq.\(quoteAuthor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            "order=created_at.desc"
        ].joined(separator: "&")
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/comments?\(params)")!
        // Comments are public — use anon key only (no user token needed for reading)
        return try await get(url: url, token: SupabaseConfig.anonKey, useAnonAsBearer: true)
    }

    func addComment(quoteText: String, quoteAuthor: String, content: String) async throws -> CommentRecord {
        guard let userId = currentUserId, let email = currentUserEmail, let token = accessToken else {
            throw SupabaseError.notAuthenticated
        }
        let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/comments")!
        let body: [String: String] = [
            "user_id": userId,
            "user_email": email,
            "quote_text": quoteText,
            "quote_author": quoteAuthor,
            "content": content
        ]
        let results: [CommentRecord] = try await post(url: url, body: body, token: token)
        guard let record = results.first else { throw SupabaseError.noData }
        return record
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(url: URL, token: String, useAnonAsBearer: Bool = false) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        if useAnonAsBearer {
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.serverError
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(url: URL, body: [String: String], authenticated: Bool = true) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError(errorBody)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(url: URL, body: [String: String], token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.apiError(errorBody)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Data Models

struct AuthResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let user: AuthUser
}

struct AuthUser: Decodable {
    let id: String
    let email: String?
}

struct BookmarkRecord: Codable, Identifiable {
    let id: String
    let user_id: String
    let quote_text: String
    let quote_author: String
    let created_at: String
}

struct CommentRecord: Codable, Identifiable {
    let id: String
    let user_id: String
    let user_email: String
    let quote_text: String
    let quote_author: String
    let content: String
    let created_at: String
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case serverError
    case noData
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be logged in."
        case .serverError: return "Server error. Try again later."
        case .noData: return "No data returned."
        case .apiError(let msg): return msg
        }
    }
}
