import SwiftUI

// MARK: - Capture Area

struct CaptureAreaView: View {
    let capturedImage: UIImage?
    let height: CGFloat
    let placeholderIcon: String
    let placeholderTitle: String
    let placeholderSubtitle: String
    var accentColor: Color = .orangePrimary
    var onRetake: (() -> Void)?

    var body: some View {
        ZStack {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let onRetake {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                onRetake()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12))
                                    Text("Retake")
                                        .font(AppFont.caption())
                                }
                                .foregroundStyle(Color.textPrimary)
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surface)
                    .frame(height: height)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: placeholderIcon)
                                .font(.system(size: 36))
                                .foregroundStyle(accentColor.opacity(0.5))

                            Text(placeholderTitle)
                                .font(AppFont.sectionHeader())
                                .foregroundStyle(Color.textSecondary)

                            Text(placeholderSubtitle)
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.borderSubtle, lineWidth: 0.5)
                    )
            }
        }
    }
}

// MARK: - Organ Selector

struct OrganSelectorView: View {
    @Binding var selectedOrgan: CaptureOrgan
    var accentColor: Color = .orangePrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ORGAN TYPE")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)

            HStack(spacing: 8) {
                ForEach(CaptureOrgan.allCases) { organ in
                    Button {
                        selectedOrgan = organ
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: organ.icon)
                                .font(.system(size: 13))
                            Text(organ.rawValue)
                                .font(AppFont.caption())
                        }
                        .foregroundStyle(selectedOrgan == organ ? accentColor : Color.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedOrgan == organ ? accentColor.opacity(0.12) : Color.surface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedOrgan == organ ? accentColor.opacity(0.4) : Color.borderSubtle, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Capture Controls

struct CaptureControlsView: View {
    var accentColor: Color = .orangePrimary
    var isDisabled: Bool = false
    var onCamera: () -> Void
    var onLibrary: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            Button {
                onLibrary()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("Library")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            }
            .buttonStyle(.plain)

            Button {
                onCamera()
            } label: {
                ZStack {
                    Circle()
                        .stroke(accentColor, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(Color.textPrimary)
                        .frame(width: 58, height: 58)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.appBackground)
                }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            // Balance placeholder
            VStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Auto")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }
            .opacity(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Identifying Card

struct IdentifyingCardView: View {
    let organName: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.orangePrimary)
                .scaleEffect(1.1)

            Text("Identifying...")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)

            Text(subtitle ?? "Analyzing your \(organName.lowercased()) photo")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let score: Double

    private var percentage: Int { Int(score * 100) }
    private var color: Color { score >= 0.5 ? .highConfidence : .mediumConfidence }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(percentage)%")
                .font(AppFont.sectionHeader())
                .foregroundStyle(color)

            Text("match")
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(width: 48, height: 48)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Result Row

struct IdentificationResultRow: View {
    let match: PlantMatch
    let isInDatabase: Bool
    var commonNamesDisplay: String?

    var body: some View {
        HStack(spacing: 12) {
            ConfidenceBadge(score: match.score)

            VStack(alignment: .leading, spacing: 3) {
                Text(match.scientificName)
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)
                    .italic()

                Text(commonNamesDisplay ?? match.commonName)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)

                if let family = match.species.family?.scientificNameWithoutAuthor {
                    Text(family)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            }

            Spacer()

            if isInDatabase {
                VStack(spacing: 4) {
                    CategoryPill(text: "In Database", color: .greenSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
            } else {
                Text("API")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.surfaceElevated)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
    }
}

// MARK: - Save to Journal Button

struct SaveToJournalButton: View {
    let isUnlocked: Bool
    var accentColor: Color = .orangePrimary
    var onSave: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        if isUnlocked {
            Button {
                onSave()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                    Text("Save to Journal")
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: accentColor))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        } else {
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("Save to Journal")
                    CategoryPill(text: "LIFETIME+", color: .orangePrimary)
                }
            }
            .buttonStyle(SecondaryButtonStyle(color: accentColor))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }
}

// MARK: - Quick Results Preview

struct QuickResultsPreview: View {
    let result: PlantIdentificationResult
    let isInDatabase: (String) -> Bool
    var commonNamesDisplay: String?
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                if let best = result.bestMatch {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Top Result")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)

                            Text(commonNamesDisplay ?? best.commonName)
                                .font(AppFont.title(18))
                                .foregroundStyle(Color.textPrimary)

                            Text(best.scientificName)
                                .font(AppFont.italic())
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        ConfidenceBadge(score: best.score)
                    }

                    HStack {
                        Text("\(min(result.results.count, 5)) results found")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)

                        if isInDatabase(best.scientificName) {
                            CategoryPill(text: "In Database", color: .greenSecondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("See all")
                                .font(AppFont.caption())
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.orangePrimary)
                    }
                } else {
                    Text("No matches found")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orangePrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
