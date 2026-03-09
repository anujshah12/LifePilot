import SwiftUI
import SwiftData

struct TemplateListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.updatedAt, order: .reverse) private var templates: [Template]

    @State private var viewModel = TemplateViewModel()
    @State private var showNewTemplateAlert = false
    @State private var newTemplateName = ""
    @State private var templateToLoad: Template?
    @State private var showLoadConfirmation = false
    @State private var showValidationAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else {
                    templateList
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newTemplateName = ""
                        showNewTemplateAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Template", isPresented: $showNewTemplateAlert) {
                TextField("Template Name", text: $newTemplateName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    viewModel.createTemplate(name: newTemplateName, context: modelContext)
                    if viewModel.validationError != nil {
                        showValidationAlert = true
                    }
                }
            } message: {
                Text("Enter a name for your new template.")
            }
            .alert("Use Template Today?", isPresented: $showLoadConfirmation) {
                Button("Cancel", role: .cancel) {
                    templateToLoad = nil
                }
                Button("Use Today") {
                    if let template = templateToLoad {
                        viewModel.loadTemplateIntoDayPlan(
                            template: template,
                            context: modelContext
                        )
                        if viewModel.validationError != nil {
                            showValidationAlert = true
                        }
                    }
                    templateToLoad = nil
                }
            } message: {
                if let template = templateToLoad {
                    Text("Create today's plan from \"\(template.name)\" with \(template.tasks.count) tasks?")
                }
            }
            .alert("Validation Error", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {
                    viewModel.validationError = nil
                }
            } message: {
                Text(viewModel.validationError ?? "")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Templates", systemImage: "doc.on.doc")
        } description: {
            Text("Create a template to quickly set up your day plan with pre-defined tasks.")
        } actions: {
            Button("Create Template") {
                newTemplateName = ""
                showNewTemplateAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Template List

    private var templateList: some View {
        List {
            ForEach(templates) { template in
                NavigationLink(value: template) {
                    TemplateCardView(
                        template: template,
                        viewModel: viewModel,
                        onUseToday: {
                            templateToLoad = template
                            showLoadConfirmation = true
                        }
                    )
                }
            }
            .onDelete(perform: deleteTemplates)
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Template.self) { template in
            TemplateEditorView(template: template, viewModel: viewModel)
        }
    }

    // MARK: - Actions

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteTemplate(templates[index], context: modelContext)
        }
    }
}

// MARK: - Template Card

private struct TemplateCardView: View {

    let template: Template
    let viewModel: TemplateViewModel
    let onUseToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.name)
                    .font(.headline)

                Spacer()

                Button {
                    onUseToday()
                } label: {
                    Label("Use Today", systemImage: "play.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }

            HStack(spacing: 16) {
                Label(
                    "\(template.tasks.count) task\(template.tasks.count == 1 ? "" : "s")",
                    systemImage: "checklist"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Label(
                    TimeFormatter.minutesToDisplay(
                        viewModel.totalEstimatedMinutes(for: template)
                    ),
                    systemImage: "clock"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            // Category color dots
            if !categoryColors.isEmpty {
                HStack(spacing: 4) {
                    ForEach(categoryColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColors: [Color] {
        let unique = Set(
            template.tasks.compactMap { $0.category?.colorHex }
        )
        return unique.sorted().map { Color(hex: $0) }
    }
}

#Preview {
    TemplateListView()
        .modelContainer(for: [
            Template.self,
            TemplateTask.self,
            TaskCategory.self,
            DayPlan.self,
            DayTask.self
        ], inMemory: true)
}
