import Foundation

@Observable
final class AuthViewModel {

    var email = ""
    var password = ""
    var firstName = ""
    var lastName = ""
    var isLoading = false
    var errorMessage: String?
    var showSignUp = false
    var showFieldError = false

    private let supabase = SupabaseService.shared

    var isLoggedIn: Bool { supabase.isLoggedIn }
    var userEmail: String? { supabase.currentUserEmail }

    @MainActor
    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            showFieldError = true
            return
        }
        isLoading = true
        errorMessage = nil
        showFieldError = false
        do {
            try await supabase.signIn(email: email, password: password)
            email = ""
            password = ""
        } catch {
            errorMessage = "Invalid email or password."
            showFieldError = true
        }
        isLoading = false
    }

    @MainActor
    func signUp() async {
        guard !firstName.isEmpty, !lastName.isEmpty else {
            errorMessage = "Please enter your first and last name."
            showFieldError = true
            return
        }
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            showFieldError = true
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            showFieldError = true
            return
        }
        isLoading = true
        errorMessage = nil
        showFieldError = false
        do {
            try await supabase.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
            email = ""
            password = ""
            firstName = ""
            lastName = ""
        } catch {
            errorMessage = "Could not create account. Email may already be in use."
            showFieldError = true
        }
        isLoading = false
    }

    @MainActor
    func signOut() async {
        await supabase.signOut()
    }
}
