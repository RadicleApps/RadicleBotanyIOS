import SwiftUI
import SwiftData

struct TermDetailView: View {
    let term: BotanyTerm

    @Query private var allPlants: [Plant]
    @Query private var allTerms: [BotanyTerm]

    // MARK: - Filtered Data

    private var speciesWithTrait: [Plant] {
        let searchValue = term.term.lowercased()
        return allPlants.filter { plant in
            matchesAnyTrait(plant: plant, value: searchValue)
        }
    }

    private var relatedTerms: [BotanyTerm] {
        allTerms.filter { $0.category == term.category && $0.term != term.term }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                illustrationSection
                descriptionSection
                speciesWithTraitSection
                relatedTermsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle(term.term)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Plant.self) { plant in
            PlantDetailView(plant: plant)
        }
        .navigationDestination(for: BotanyTerm.self) { botanyTerm in
            TermDetailView(term: botanyTerm)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(term.term)
                .font(AppFont.title())
                .foregroundStyle(Color.textPrimary)

            CategoryPill(text: term.category, color: .purpleSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Illustration

    private var illustrationSection: some View {
        Group {
            if let imageURL = term.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        illustrationPlaceholder
                            .overlay(
                                ProgressView()
                                    .tint(Color.textMuted)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    case .failure:
                        illustrationPlaceholder
                            .overlay(
                                VStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.title3)
                                        .foregroundStyle(Color.textMuted)
                                    Text("Failed to load image")
                                        .font(AppFont.caption())
                                        .foregroundStyle(Color.textMuted)
                                }
                            )
                    @unknown default:
                        illustrationPlaceholder
                    }
                }
            } else {
                illustrationPlaceholder
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.purpleSecondary.opacity(0.4))
                            Text("Illustration")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)
                        }
                    )
            }
        }
    }

    private var illustrationPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.surfaceElevated)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)

            if !term.descriptionShort.isEmpty {
                Text(term.descriptionShort)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)
                    .lineSpacing(4)
            }

            if !term.descriptionLong.isEmpty {
                Text(term.descriptionLong)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
            }

            if term.descriptionShort.isEmpty && term.descriptionLong.isEmpty {
                Text("Botanical term in the \(term.category) category.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
            }
        }
        .cardStyle()
    }

    // MARK: - Species with this Trait

    @ViewBuilder
    private var speciesWithTraitSection: some View {
        if !speciesWithTrait.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Species with this Trait")
                        .font(AppFont.sectionHeader())
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Text("\(speciesWithTrait.count)")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(speciesWithTrait, id: \.scientificName) { plant in
                            NavigationLink(value: plant) {
                                speciesCard(plant)
                            }
                        }
                    }
                }
            }
        }
    }

    private func speciesCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.surfaceElevated)
                .frame(width: 130, height: 90)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundStyle(Color.greenSecondary.opacity(0.3))
                )

            Text(plant.commonName)
                .font(AppFont.caption())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(plant.scientificName)
                .font(AppFont.caption(10))
                .foregroundStyle(Color.textMuted)
                .italic()
                .lineLimit(1)
        }
        .frame(width: 130)
        .padding(8)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Related Terms

    @ViewBuilder
    private var relatedTermsSection: some View {
        if !relatedTerms.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Related Terms")
                        .font(AppFont.sectionHeader())
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Text("\(relatedTerms.count)")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(relatedTerms, id: \.term) { relatedTerm in
                            NavigationLink(value: relatedTerm) {
                                termCard(relatedTerm)
                            }
                        }
                    }
                }
            }
        }
    }

    private func termCard(_ botanyTerm: BotanyTerm) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.surfaceElevated)
                .frame(width: 130, height: 80)
                .overlay(
                    Group {
                        if let imageURL = botanyTerm.imageURL, let url = URL(string: imageURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 130, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                default:
                                    Image(systemName: "text.book.closed.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.purpleSecondary.opacity(0.3))
                                }
                            }
                        } else {
                            Image(systemName: "text.book.closed.fill")
                                .font(.title3)
                                .foregroundStyle(Color.purpleSecondary.opacity(0.3))
                        }
                    }
                )

            Text(botanyTerm.term)
                .font(AppFont.caption())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(botanyTerm.category)
                .font(AppFont.caption(10))
                .foregroundStyle(Color.purpleSecondary)
                .lineLimit(1)
        }
        .frame(width: 130)
        .padding(8)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Trait Matching

    private func matchesAnyTrait(plant: Plant, value: String) -> Bool {
        let traitFields: [String?] = [
            // Leaf
            plant.leafType,
            plant.leafAttachment,
            plant.leafArrangement,
            plant.leafShape,
            plant.leafMargin,
            plant.leafApex,
            plant.leafBase,
            plant.leafVenation,
            plant.leafTexture,
            plant.leafStipules,
            // Stem
            plant.stemHabit,
            plant.stemStructure,
            plant.stemBranching,
            // Flower
            plant.flowerInflorescence,
            plant.flowerSymmetry,
            plant.flowerPetalCount,
            plant.flowerPetalFusion,
            plant.flowerSepalPresence,
            plant.flowerSepalFusion,
            plant.flowerColor,
            plant.flowerPosition,
            plant.flowerOvaryPosition,
            plant.flowerSexuality,
            plant.flowerFloralPart,
            // Fruit
            plant.fruitType,
            plant.fruitSeedTrait,
            // Root
            plant.rootType
        ]

        return traitFields.contains { field in
            guard let field = field else { return false }
            return field.localizedCaseInsensitiveContains(value)
        }
    }
}

// MARK: - Hashable Conformance for BotanyTerm Navigation

extension BotanyTerm: Hashable {
    static func == (lhs: BotanyTerm, rhs: BotanyTerm) -> Bool {
        lhs.term == rhs.term
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(term)
    }
}

#Preview {
    NavigationStack {
        TermDetailView(
            term: BotanyTerm(
                term: "Pinnate",
                category: "Leaf Venation",
                imageURL: nil,
                showPlantID: true,
                isFree: true
            )
        )
    }
}
