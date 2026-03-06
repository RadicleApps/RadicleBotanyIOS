import SwiftUI

// MARK: - Shared Identification UI Components
// Reusable components shared between CaptureView and BothModeView.

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let score: Double

    private var percentage: Int { Int(score * 100) }
    private var color: Color { score >= 0.5 ? .highConfidence : .mediumConfidence }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(percentage)%")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(color)

            Text("match")
                .font(AppTypography.inter(size: 9))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(width: 48, height: 48)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }
}

// MARK: - Reference Image Strip

/// Horizontal scroll of PlantNet reference images for a match.
struct ReferenceImageStrip: View {
    let images: [RelatedImage]
    var maxCount: Int = 6
    var onImageTap: ((String) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(images.prefix(maxCount)) { img in
                    if let urlStr = img.bestURL, let url = URL(string: urlStr) {
                        Button {
                            onImageTap?(urlStr)
                        } label: {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 56, height: 56)
                                        .clipped()
                                default:
                                    RoundedRectangle(cornerRadius: AppRadius.small)
                                        .fill(AppColors.cardElevated)
                                        .frame(width: 56, height: 56)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .stroke(AppColors.border, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Organ Selector

/// Horizontal pill selector for CaptureOrgan (Flower, Leaf, Fruit, Bark).
struct OrganSelector: View {
    @Binding var selectedOrgan: CaptureOrgan
    var accentColor: Color = .orangePrimary
    var showLabel: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLabel {
                Text("ORGAN TYPE")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            HStack(spacing: 8) {
                ForEach(CaptureOrgan.allCases) { organ in
                    Button {
                        selectedOrgan = organ
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: organ.icon)
                                .font(AppTypography.inter(size: 13))
                            Text(organ.rawValue)
                                .font(AppTypography.tagText)
                        }
                        .foregroundStyle(selectedOrgan == organ ? accentColor : AppColors.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedOrgan == organ ? accentColor.opacity(0.12) : AppColors.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedOrgan == organ ? accentColor.opacity(0.4) : AppColors.border, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Capture Controls

/// Camera + Library buttons with centered shutter.
struct CaptureControls: View {
    var accentColor: Color = .orangePrimary
    var isDisabled: Bool = false
    var onCamera: () -> Void
    var onLibrary: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            // Photo library
            Button {
                onLibrary()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(AppTypography.inter(size: 22))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(AppColors.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                    Text("Library")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            .buttonStyle(.plain)

            // Capture button
            Button {
                onCamera()
            } label: {
                ZStack {
                    Circle()
                        .stroke(accentColor, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(AppColors.textPrimary)
                        .frame(width: 58, height: 58)

                    Image(systemName: "camera.fill")
                        .font(AppTypography.inter(size: 22))
                        .foregroundStyle(AppColors.appBackground)
                }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            // Spacer placeholder for layout balance
            VStack(spacing: 4) {
                Color.clear
                    .frame(width: 48, height: 48)
                Text("")
                    .font(AppTypography.tagText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Capture Image Preview

/// Displays a captured image with optional retake button, or a placeholder prompt.
struct CaptureImagePreview: View {
    let image: UIImage?
    var height: CGFloat = 280
    var placeholderIcon: String = "camera.fill"
    var placeholderText: String = "Take or select a photo"
    var placeholderIconColor: Color = AppColors.textMuted
    var showRetake: Bool = true
    var onRetake: (() -> Void)?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))

                if showRetake, let onRetake {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                onRetake()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(AppTypography.inter(size: 12))
                                    Text("Retake")
                                        .font(AppTypography.tagText)
                                }
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                            .padding(12)
                        }
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: AppRadius.badge)
                    .fill(AppColors.cardBackground)
                    .frame(height: height)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: placeholderIcon)
                                .font(AppTypography.inter(size: 36))
                                .foregroundStyle(placeholderIconColor.opacity(0.4))

                            Text(placeholderText)
                                .font(AppTypography.bodyText)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.badge)
                            .stroke(AppColors.border, lineWidth: 0.5)
                    )
            }
        }
    }
}

// MARK: - Save to Journal Bar

/// Bottom safe area bar with Save to Journal button (locked/unlocked) and optional Write a Note.
struct SaveToJournalBar: View {
    let isUnlocked: Bool
    var accentColor: Color = .orangePrimary
    var onSave: () -> Void
    var onDismiss: () -> Void
    var onWriteNote: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            if isUnlocked {
                HStack(spacing: 8) {
                    Button {
                        onSave()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(AppTypography.inter(size: 13))
                            Text("Save to Journal")
                                .font(AppTypography.sectionHeader)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: accentColor))

                    if let noteAction = onWriteNote {
                        Button {
                            noteAction()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.line")
                                    .font(AppTypography.inter(size: 13))
                                Text("Write a Note")
                                    .font(AppTypography.sectionHeader)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .purpleSecondary))
                    }
                }
            } else {
                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Save to Journal")
                        CategoryPill(text: "ANNUAL+", color: .orangePrimary)
                    }
                }
                .buttonStyle(SecondaryButtonStyle(color: accentColor))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppColors.appBackground)
    }
}

// MARK: - Identifying Card

/// Loading indicator shown during PlantNet identification.
struct IdentifyingCard: View {
    let organName: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppColors.primaryAmber)
                .scaleEffect(1.1)

            Text("Identifying...")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)

            Text(subtitle ?? "Analyzing your \(organName.lowercased()) photo")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }
}

// MARK: - Result Row

/// A single identification result row with confidence, species info, database badge, and reference images.
struct IdentificationResultRow: View {
    let match: PlantMatch
    let isInDatabase: Bool
    var onTap: (() -> Void)? = nil
    var onImageTap: ((String) -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ConfidenceBadge(score: match.score)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.scientificName)
                            .font(AppTypography.sectionHeader)
                            .foregroundStyle(AppColors.textPrimary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)

                        Text(match.commonName)
                            .font(AppTypography.bodyText)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let family = match.species.family?.scientificNameWithoutAuthor {
                            Text(family)
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isInDatabase {
                        VStack(alignment: .trailing, spacing: 4) {
                            CategoryPill(text: "In DB", color: .orangePrimary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.inter(size: 10))
                                .foregroundStyle(AppColors.textMuted)
                        }
                    } else {
                        Text("API")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColors.cardElevated)
                            .clipShape(Capsule())
                    }
                }

                // Reference images
                if let images = match.images, !images.isEmpty {
                    ReferenceImageStrip(images: images, onImageTap: onImageTap)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Results Modal Header

/// Captured image + title header used in results modals.
struct ResultsModalHeader: View {
    let image: UIImage?
    let title: String
    var trailingPill: String?
    var pillColor: Color = .orangePrimary
    var imageHeight: CGFloat = 180

    var body: some View {
        VStack(spacing: 0) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            HStack {
                Text(title)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if let pill = trailingPill {
                    CategoryPill(text: pill, color: pillColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Empty Results Placeholder

struct EmptyResultsPlaceholder: View {
    var message: String = "No species identified"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 30))
                .foregroundStyle(AppColors.textMuted)
            Text(message)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
