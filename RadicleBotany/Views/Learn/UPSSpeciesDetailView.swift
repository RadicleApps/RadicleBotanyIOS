import SwiftUI

/// Detail view for United Plant Savers species that are NOT in the app's plant database.
/// Provides conservation information, status, description, and ecological context.
struct UPSSpeciesDetailView: View {
    let species: UPSSpecies
    let imageURL: URL?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                contentSection
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Image or placeholder
            if let url = imageURL {
                ThrottledAsyncImage(url: url, contentMode: .fill) {
                    placeholderImage
                }
                .frame(height: 280)
                .clipped()
            } else {
                placeholderImage
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, AppColors.appBackground.opacity(0.6), AppColors.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            // Bottom label
            VStack(alignment: .leading, spacing: 6) {
                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: species.category.icon)
                        .font(AppTypography.inter(size: 10, weight: .semibold))
                    Text(species.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.5)
                }
                .foregroundStyle(species.category.color)

                // Names
                Text(species.commonName.titleCased)
                    .font(.cormorant(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(species.scientificName)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var placeholderImage: some View {
        ZStack {
            AppColors.cardElevated
                .frame(height: 280)

            VStack(spacing: 12) {
                Image(systemName: species.category.icon)
                    .font(AppTypography.inter(size: 48, weight: .light))
                    .foregroundStyle(species.category.color.opacity(0.3))

                Text(species.commonName.titleCased)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Conservation status card
            conservationStatusCard

            // Description
            descriptionCard

            // Ecological context
            ecologyCard

            // How to help
            helpCard

            // Source attribution
            sourceAttribution
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 100)
    }

    // MARK: - Conservation Status Card

    private var conservationStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: species.category.icon)
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(species.category.color)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text("CONSERVATION STATUS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.textMuted)
                        .kerning(1.5)

                    Text("UPS \(species.category.rawValue)")
                        .font(AppTypography.inter(size: 15, weight: .semibold))
                        .foregroundStyle(species.category.color)
                }
            }

            Text(species.category.description)
                .font(AppTypography.inter(size: 13, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)

            // Severity indicator bar
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    let isActive = severityLevel >= index + 1
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? species.category.color : AppColors.cardElevated)
                        .frame(height: 4)
                }
            }
        }
    }

    private var severityLevel: Int {
        switch species.category {
        case .critical: return 3
        case .atRisk: return 2
        case .toWatch: return 1
        }
    }

    // MARK: - Description Card

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ABOUT THIS SPECIES")

            Text(speciesDescription)
                .font(AppTypography.inter(size: 13, weight: .regular))
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(5)
        }
    }

    // MARK: - Ecology Card

    private var ecologyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ECOLOGICAL CONTEXT")

            // Quick facts
            VStack(spacing: 8) {
                ecologyRow(icon: "exclamationmark.triangle.fill", label: "Primary Threats", value: primaryThreats)
                ecologyRow(icon: "map.fill", label: "Habitat", value: habitat)
                ecologyRow(icon: "leaf.fill", label: "Conservation Priority", value: conservationPriority)
            }
        }
    }

    private func ecologyRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 11))
                .foregroundStyle(species.category.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.inter(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)

                Text(value)
                    .font(AppTypography.inter(size: 12, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - How to Help Card

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("HOW YOU CAN HELP")

            VStack(alignment: .leading, spacing: 8) {
                helpTip("Avoid purchasing wild-harvested specimens")
                helpTip("Support nurseries that propagate from cultivated stock")
                helpTip("Report wild populations to local conservation groups")
                helpTip("Learn to identify this species in the field")
            }
        }
    }

    private func helpTip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(AppTypography.inter(size: 10))
                .foregroundStyle(AppColors.success)
                .padding(.top, 2)

            Text(text)
                .font(AppTypography.inter(size: 12, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Source Attribution

    private var sourceAttribution: some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(AppTypography.inter(size: 10))
            Text("Source: United Plant Savers")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            Text("unitedplantsavers.org")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .underline()
        }
        .foregroundStyle(AppColors.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(AppColors.textMuted)
            .kerning(1.5)
    }

    // MARK: - Species-Specific Content

    private var speciesDescription: String {
        speciesData[species.scientificName]?.description ?? defaultDescription
    }

    private var primaryThreats: String {
        speciesData[species.scientificName]?.threats ?? defaultThreats
    }

    private var habitat: String {
        speciesData[species.scientificName]?.habitat ?? "Varies by species and region"
    }

    private var conservationPriority: String {
        switch species.category {
        case .critical: return "Highest — Immediate protection needed"
        case .atRisk: return "High — Monitoring and habitat preservation required"
        case .toWatch: return "Moderate — Population trends being monitored"
        }
    }

    private var defaultDescription: String {
        "\(species.commonName.titleCased) (\(species.scientificName)) is listed as \(species.category.rawValue) by United Plant Savers. \(species.category.description) This species deserves attention from botanists and conservationists alike."
    }

    private var defaultThreats: String {
        switch species.category {
        case .critical: return "Severe habitat loss, overharvesting, illegal trade"
        case .atRisk: return "Overharvesting, habitat degradation, climate pressure"
        case .toWatch: return "Growing demand, habitat fragmentation, monitoring needed"
        }
    }

    // Species-specific data
    private struct SpeciesInfo {
        let description: String
        let threats: String
        let habitat: String
    }

    private var speciesData: [String: SpeciesInfo] {
        [
            "Chamaelirium luteum": SpeciesInfo(
                description: "False Unicorn is a perennial herb used in traditional herbalism for reproductive health. Slow growth and specific habitat requirements make wild populations extremely vulnerable to overharvesting.",
                threats: "Commercial overharvesting for herbal trade, habitat loss in eastern deciduous forests",
                habitat: "Moist, rich woodlands in eastern North America"
            ),
            "Cypripedium spp.": SpeciesInfo(
                description: "Lady's Slipper Orchids are among the rarest wild orchids in North America. The species requires specific mycorrhizal fungi to germinate and grow, making transplantation nearly impossible.",
                threats: "Collection for gardens, habitat destruction, extremely slow reproduction",
                habitat: "Bogs, wetlands, and shaded woodlands across temperate regions"
            ),
            "Lophophora williamsii": SpeciesInfo(
                description: "Peyote is a small, spineless cactus with deep cultural importance to indigenous peoples. The species grows extremely slowly and faces severe pressure from illegal harvesting and habitat conversion.",
                threats: "Illegal harvesting, cultural extraction, ranching habitat conversion",
                habitat: "Chihuahuan Desert scrublands of southern Texas and northern Mexico"
            ),
            "Santalum spp.": SpeciesInfo(
                description: "Sandalwood trees are prized for their fragrant heartwood and essential oil. Multiple species worldwide face critical decline due to centuries of overexploitation for perfumery and religious uses.",
                threats: "Illegal logging, oil extraction overharvesting, slow maturation (20+ years)",
                habitat: "Tropical and subtropical dry forests across Asia and Pacific islands"
            ),
            "Drosera spp.": SpeciesInfo(
                description: "Sundews are carnivorous plants that capture insects with sticky, glandular tentacles. These plants inhabit nutrient-poor wetlands that are rapidly disappearing worldwide.",
                threats: "Wetland drainage, peat harvesting, collection for herbal trade",
                habitat: "Bogs, fens, and acidic wetlands globally"
            ),
            "Trillium spp.": SpeciesInfo(
                description: "Trilliums are spring wildflowers with three-petaled blooms. The species takes 7-10 years to flower from seed and is highly sensitive to habitat disturbance and deer browsing.",
                threats: "Forest fragmentation, deer overpopulation, slow reproduction cycle",
                habitat: "Rich, deciduous woodlands across eastern North America"
            ),
            "Aletris farinosa": SpeciesInfo(
                description: "True Unicorn is a grasslike perennial with a distinctive white, mealy flower spike, overharvested for traditional medicine and now increasingly rare throughout the range.",
                threats: "Overharvesting for herbal trade, grassland habitat loss",
                habitat: "Moist meadows, savannas, and open woodlands in eastern North America"
            ),
            "Dionaea muscipula": SpeciesInfo(
                description: "The Venus Fly Trap is a carnivorous plant that snaps shut on insect prey within milliseconds. The species occurs naturally only within a narrow range of coastal Carolina wetlands.",
                threats: "Poaching (a federal crime), habitat loss, fire suppression",
                habitat: "Longleaf pine savannas within 100 miles of Wilmington, North Carolina"
            ),
            "Panax quinquefolius": SpeciesInfo(
                description: "American Ginseng is one of the most commercially valuable wild-harvested plants in North America. Slow growth, high market value, and specific habitat requirements compound vulnerability to overharvesting.",
                threats: "Commercial overharvesting for Asian market, habitat loss, deer browsing",
                habitat: "Rich, shaded hardwood forests of eastern North America"
            ),
            "Actaea racemosa": SpeciesInfo(
                description: "Black Cohosh is a perennial woodland plant widely used in herbal medicine for menopausal symptoms. Increasing global demand has put severe pressure on wild populations.",
                threats: "Commercial overharvesting, pharmaceutical demand, forest habitat loss",
                habitat: "Rich, moist deciduous forests of eastern North America"
            ),
            "Sanguinaria canadensis": SpeciesInfo(
                description: "Bloodroot is named for the vivid red-orange sap in the rhizome. This early spring ephemeral produces white flowers lasting only a day or two and has been extensively harvested for sanguinarine.",
                threats: "Overharvesting for alkaloid extraction, woodland habitat fragmentation",
                habitat: "Rich, moist deciduous woodlands across eastern North America"
            ),
            "Hydrastis canadensis": SpeciesInfo(
                description: "Goldenseal is one of the most heavily traded wild medicinal plants in North America. The bright yellow root contains berberine, driving intense commercial harvesting that has devastated populations.",
                threats: "Massive commercial overharvesting, habitat loss, slow reproduction",
                habitat: "Rich, moist hardwood forests of the Ohio River Valley and Appalachians"
            ),
            "Monotropa uniflora": SpeciesInfo(
                description: "Ghost Pipe is an entirely white, achlorophyllous plant. The species parasitizes mycorrhizal fungi connected to tree roots, making cultivation impossible and tying the plant closely to intact forest ecosystems.",
                threats: "Social media-driven overharvesting, forest ecosystem disruption",
                habitat: "Shaded, humus-rich floors of mature forests across North America"
            ),
            "Asclepias tuberosa": SpeciesInfo(
                description: "Butterfly Weed is an orange-flowered milkweed important for monarch butterfly populations. Unlike common milkweed, the species has a deep taproot that makes transplantation difficult.",
                threats: "Habitat loss from agriculture, herbicide use, prairie conversion",
                habitat: "Dry prairies, meadows, and open woodlands across eastern North America"
            ),
            "Ulmus rubra": SpeciesInfo(
                description: "Slippery Elm is valued for the mucilaginous inner bark, used medicinally for sore throats and digestive issues. Trees are often killed by bark stripping, compounding losses from Dutch elm disease.",
                threats: "Destructive bark harvesting, Dutch elm disease, habitat loss",
                habitat: "Moist lowlands and floodplains across eastern North America"
            ),
            "Salvia apiana": SpeciesInfo(
                description: "White Sage is a sacred plant in many Indigenous traditions, used ceremonially for smudging. Skyrocketing commercial demand has led to widespread illegal harvesting from wild stands.",
                threats: "Commercial overharvesting, illegal poaching, cultural exploitation, wildfire",
                habitat: "Coastal sage scrub of southern California and Baja Mexico"
            ),
            "Adiantum pedatum": SpeciesInfo(
                description: "Maidenhair Fern has fan-shaped fronds on glossy black stems. The species is a woodland indicator sensitive to air quality and habitat disturbance.",
                threats: "Habitat loss, collection for gardens, air pollution sensitivity",
                habitat: "Rich, moist woodlands and ravines across North America and Asia"
            ),
            "Podophyllum peltatum": SpeciesInfo(
                description: "Mayapple forms large colonies on forest floors each spring, with broad umbrella-shaped leaves. The rhizome contains podophyllotoxin, a compound used in cancer treatment, driving pharmaceutical harvesting.",
                threats: "Pharmaceutical harvesting of podophyllotoxin, habitat loss",
                habitat: "Rich deciduous forests and moist woodlands of eastern North America"
            ),
            "Piper methysticum": SpeciesInfo(
                description: "Kava is a culturally significant plant in Pacific Island societies, used for centuries in ceremonial and social contexts. Growing global demand for the calming properties threatens wild sources.",
                threats: "Expanding global demand, unsustainable wild harvesting, climate vulnerability",
                habitat: "Tropical forests and cultivated plots across Pacific Island nations"
            ),
            "Baptisia tinctoria": SpeciesInfo(
                description: "Wild Indigo is a native legume once used to produce blue dye. The deep taproot fixes nitrogen in soil, providing ecological value in prairie and woodland edge habitats.",
                threats: "Prairie habitat loss, agricultural conversion, herbicide drift",
                habitat: "Dry, open woodlands and prairies of eastern North America"
            ),
        ]
    }
}

#Preview {
    NavigationStack {
        UPSSpeciesDetailView(
            species: UPSSpecies(commonName: "Venus Fly Trap", scientificName: "Dionaea muscipula", category: .critical),
            imageURL: nil
        )
    }
    .preferredColorScheme(.dark)
}
