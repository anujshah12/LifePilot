import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text(viewModel.showSignUp ? "Create Account" : "Welcome Back")
                .font(.title.bold())

            VStack(spacing: 16) {
                if viewModel.showSignUp {
                    HStack(spacing: 12) {
                        TextField("First Name", text: $viewModel.firstName)
                            .textContentType(.givenName)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.showFieldError && viewModel.firstName.isEmpty ? .red : .clear, lineWidth: 2)
                            )

                        TextField("Last Name", text: $viewModel.lastName)
                            .textContentType(.familyName)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.showFieldError && viewModel.lastName.isEmpty ? .red : .clear, lineWidth: 2)
                            )
                    }
                }

                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.showFieldError ? .red : .clear, lineWidth: 2)
                    )

                SecureField("Password", text: $viewModel.password)
                    .textContentType(viewModel.showSignUp ? .newPassword : .password)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.showFieldError ? .red : .clear, lineWidth: 2)
                    )
            }
            .onChange(of: viewModel.email) {
                viewModel.showFieldError = false
                viewModel.errorMessage = nil
            }
            .onChange(of: viewModel.password) {
                viewModel.showFieldError = false
                viewModel.errorMessage = nil
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    if viewModel.showSignUp {
                        await viewModel.signUp()
                    } else {
                        await viewModel.signIn()
                    }
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text(viewModel.showSignUp ? "Sign Up" : "Log In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button(viewModel.showSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up") {
                viewModel.showSignUp.toggle()
                viewModel.errorMessage = nil
            }
            .font(.subheadline)

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
