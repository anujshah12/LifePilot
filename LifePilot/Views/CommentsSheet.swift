import SwiftUI

struct CommentsSheet: View {
    @Bindable var viewModel: QuotesViewModel
    let isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quote context
                VStack(spacing: 4) {
                    Text("\"\(viewModel.quoteText)\"")
                        .font(.subheadline)
                        .italic()
                        .multilineTextAlignment(.center)
                    Text("- \(viewModel.quoteAuthor)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)

                Divider()

                // Comments list
                if viewModel.isLoadingComments {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.comments.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Comments Yet",
                        systemImage: "bubble.left",
                        description: Text("Be the first to share your thoughts!")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }

                Divider()

                // Compose area
                if isLoggedIn {
                    HStack(spacing: 12) {
                        TextField("Add a comment...", text: $viewModel.newCommentText)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task { await viewModel.postComment() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                } else {
                    Text("Log in to post comments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
