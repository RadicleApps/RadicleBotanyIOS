import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \JournalNote.date, order: .reverse)
    private var notes: [JournalNote]

    @State private var selectedNote: JournalNote? = nil
    @State private var showDeleteAlert = false
    @State private var noteToDelete: JournalNote? = nil

    var body: some View {
        Group {
            if notes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createNewNote()
                } label: {
                    Image(systemName: "plus")
                        .font(AppTypography.inter(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                NoteEditorView(
                    note: note,
                    isNewNote: false,
                    onDelete: {
                        modelContext.delete(note)
                        selectedNote = nil
                    }
                )
            }
        }
        .alert("Delete Note", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    withAnimation {
                        modelContext.delete(note)
                    }
                    noteToDelete = nil
                }
            }
        } message: {
            Text("This note will be permanently deleted.")
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(notes) { note in
                    noteCard(note)
                        .contextMenu {
                            Button {
                                selectedNote = note
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                noteToDelete = note
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func noteCard(_ note: JournalNote) -> some View {
        Button {
            selectedNote = note
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Title + date row
                HStack(alignment: .top) {
                    Text(note.displayTitle)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(note.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                }

                // Content preview
                if !note.content.isEmpty {
                    Text(note.contentPreview)
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }

                // Entity link pill
                if note.hasLink, let entityType = note.entityType {
                    HStack(spacing: 5) {
                        Image(systemName: entityType.icon)
                            .font(AppTypography.inter(size: 9))
                        Text(note.linkedEntityID ?? "")
                            .font(AppTypography.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(entityType.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(entityType.color.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("Solitary flower color")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
                .opacity(0.6)

            VStack(spacing: 8) {
                Text("No Notes Yet")
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Capture your botanical observations, field notes, and learning reflections.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                createNewNote()
            } label: {
                Text("Write Your First Note")
            }
            .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Actions

    private func createNewNote() {
        let newNote = JournalNote()
        modelContext.insert(newNote)
        selectedNote = newNote
    }
}

#Preview {
    NavigationStack {
        NotesListView()
            .modelContainer(for: [JournalNote.self], inMemory: true)
    }
}
