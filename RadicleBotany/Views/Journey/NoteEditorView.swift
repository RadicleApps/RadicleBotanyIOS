import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var note: JournalNote

    @State private var showLinkPicker = false
    @State private var showDeleteAlert = false
    @State private var showNotionExport = false
    @State private var notionExportStatus: NotionExportStatus = .idle
    @State private var showNotionSettings = false

    @AppStorage("notionToken") private var notionToken = ""
    @AppStorage("notionPageID") private var notionPageID = ""

    var isNewNote: Bool = false
    var onDelete: (() -> Void)? = nil

    enum NotionExportStatus: Equatable {
        case idle
        case exporting
        case success
        case error(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                TextField("Note title...", text: $note.title)
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Date
                Text(note.date.formatted(date: .long, time: .shortened))
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Entity link
                linkSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Divider
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                // Content
                ZStack(alignment: .topLeading) {
                    if note.content.isEmpty {
                        Text("Write your note...")
                            .font(AppTypography.bodyText)
                            .foregroundStyle(AppColors.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $note.content)
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // Notion export button (always visible)
                notionExportSection
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                // Delete button (only for existing notes)
                if !isNewNote {
                    deleteSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    // Clean up empty new notes
                    if isNewNote && note.title.isEmpty && note.content.isEmpty {
                        modelContext.delete(note)
                    }
                    dismiss()
                }
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.primaryAmber)
            }
        }
        .sheet(isPresented: $showLinkPicker) {
            EntityLinkPicker { entityType, entityID in
                note.linkedEntityType = entityType.rawValue
                note.linkedEntityID = entityID
            }
        }
        .alert("Delete Note", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("This note will be permanently deleted. This action cannot be undone.")
        }
        .navigationDestination(isPresented: $showNotionSettings) {
            SettingsView(scrollToNotion: true)
        }
    }

    // MARK: - Link Section

    private var linkSection: some View {
        Group {
            if note.hasLink, let entityType = note.entityType {
                // Linked entity pill
                HStack(spacing: 8) {
                    Image(systemName: entityType.icon)
                        .font(AppTypography.inter(size: 11))
                        .foregroundStyle(entityType.color)

                    Text(note.linkedEntityID ?? "")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Unlink button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            note.linkedEntityType = nil
                            note.linkedEntityID = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(entityType.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .stroke(entityType.color.opacity(0.2), lineWidth: 0.5)
                )
            } else {
                // Link placeholder
                Button {
                    showLinkPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(AppTypography.inter(size: 12))
                            .foregroundStyle(AppColors.textMuted)

                        Text("Link to a plant, family, or term...")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textMuted)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(AppTypography.inter(size: 10))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Notion Export

    private var isNotionConfigured: Bool {
        !notionToken.isEmpty && !notionPageID.isEmpty
    }

    private var notionExportSection: some View {
        VStack(spacing: 8) {
            if isNotionConfigured {
                // Configured — show export button
                Button {
                    exportToNotion()
                } label: {
                    HStack(spacing: 8) {
                        if notionExportStatus == .exporting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else if notionExportStatus == .success {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppTypography.inter(size: 14))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(AppTypography.inter(size: 14))
                        }

                        Text(notionExportButtonText)
                            .font(AppTypography.sectionHeader)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(notionExportButtonColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
                .disabled(notionExportStatus == .exporting || note.content.isEmpty)

                if case .error(let message) = notionExportStatus {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.error)
                        .multilineTextAlignment(.center)
                }
            } else {
                // Not configured — tappable link to Settings → Notion
                Button {
                    showNotionSettings = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.brandPurple)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export to Notion")
                                .font(AppTypography.sectionHeader)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Tap to set up in Settings")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(AppTypography.inter(size: 12))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .padding(14)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .stroke(AppColors.brandPurple.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notionExportButtonText: String {
        switch notionExportStatus {
        case .idle: return "Send to Notion"
        case .exporting: return "Sending..."
        case .success: return "Sent to Notion"
        case .error: return "Try Again"
        }
    }

    private var notionExportButtonColor: Color {
        switch notionExportStatus {
        case .idle, .error: return AppColors.brandPurple
        case .exporting: return AppColors.brandPurple.opacity(0.6)
        case .success: return AppColors.success
        }
    }

    private func exportToNotion() {
        guard !notionToken.isEmpty, !notionPageID.isEmpty else { return }

        notionExportStatus = .exporting
        Task {
            do {
                _ = try await NotionService.shared.exportNote(
                    note,
                    token: notionToken,
                    parentPageID: notionPageID
                )
                await MainActor.run {
                    notionExportStatus = .success
                }
                // Reset after a delay
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    notionExportStatus = .idle
                }
            } catch {
                await MainActor.run {
                    notionExportStatus = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(AppTypography.inter(size: 13))
                Text("Delete Note")
                    .font(AppTypography.sectionHeader)
            }
            .foregroundStyle(AppColors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.error.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        NoteEditorView(
            note: JournalNote(title: "Sample Note", content: "Some content here..."),
            isNewNote: false
        )
    }
    .modelContainer(for: [JournalNote.self, Plant.self, Family.self, BotanyTerm.self], inMemory: true)
}
