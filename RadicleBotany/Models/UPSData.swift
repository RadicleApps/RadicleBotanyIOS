import Foundation

// MARK: - United Plant Savers Species Data

struct UPSSpecies: Identifiable, Hashable {
    let id = UUID()
    let commonName: String
    let scientificName: String
    let status: UPSStatus
    let description: String

    enum UPSStatus: String, CaseIterable {
        case critical = "Critical"
        case atRisk = "At-Risk"
        case inReview = "In Review"

        var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .atRisk: return 1
            case .inReview: return 2
            }
        }
    }
}

// MARK: - Full UPS Species List (July 2022 Revision)

struct UPSData {

    static let allSpecies: [UPSSpecies] = criticalSpecies + atRiskSpecies + inReviewSpecies

    // MARK: - Critical (Never wild-harvest)

    static let criticalSpecies: [UPSSpecies] = [
        UPSSpecies(
            commonName: "American Ginseng",
            scientificName: "Panax quinquefolius",
            status: .critical,
            description: "A slow-growing perennial prized for its root. CITES Appendix II listed. Wild populations severely depleted by commercial harvesting."
        ),
        UPSSpecies(
            commonName: "Goldenseal",
            scientificName: "Hydrastis canadensis",
            status: .critical,
            description: "A woodland herb valued for its antimicrobial properties. CITES Appendix II listed. Overharvesting has decimated wild populations."
        ),
        UPSSpecies(
            commonName: "Lady's Slipper Orchid",
            scientificName: "Cypripedium spp.",
            status: .critical,
            description: "Native orchids with distinctive pouch-shaped flowers. Extremely sensitive to habitat disturbance and nearly impossible to transplant."
        ),
        UPSSpecies(
            commonName: "Peyote",
            scientificName: "Lophophora williamsii",
            status: .critical,
            description: "A small spineless cactus native to southern Texas and Mexico. Sacred to Indigenous peoples. Federally protected and severely threatened."
        ),
        UPSSpecies(
            commonName: "Sandalwood",
            scientificName: "Santalum spp.",
            status: .critical,
            description: "Hawaiian native trees harvested for aromatic heartwood. Historically overharvested; remaining wild populations are critically reduced."
        ),
        UPSSpecies(
            commonName: "Trillium",
            scientificName: "Trillium spp.",
            status: .critical,
            description: "Spring woodland wildflowers with three-petaled blooms. Extremely slow to reproduce; a single plant may take 7-10 years to flower from seed."
        ),
        UPSSpecies(
            commonName: "Venus Fly Trap",
            scientificName: "Dionaea muscipula",
            status: .critical,
            description: "Carnivorous plant native only to a small area of the Carolinas. Poaching is a felony in North Carolina. Wild populations critically endangered."
        ),
        UPSSpecies(
            commonName: "Virginia Snakeroot",
            scientificName: "Aristolochia serpentaria",
            status: .critical,
            description: "A small woodland herb historically used as a snakebite remedy. Rare throughout its range due to habitat loss and overharvesting."
        ),
    ]

    // MARK: - At-Risk

    static let atRiskSpecies: [UPSSpecies] = [
        UPSSpecies(
            commonName: "Black Cohosh",
            scientificName: "Actaea racemosa",
            status: .atRisk,
            description: "A tall woodland perennial used for women's health. High commercial demand has led to significant wild population declines."
        ),
        UPSSpecies(
            commonName: "Bloodroot",
            scientificName: "Sanguinaria canadensis",
            status: .atRisk,
            description: "A spring ephemeral with distinctive red-orange sap. Slow to reproduce and vulnerable to habitat disturbance."
        ),
        UPSSpecies(
            commonName: "Blue Cohosh",
            scientificName: "Caulophyllum thalictroides",
            status: .atRisk,
            description: "A woodland herb traditionally used in childbirth. Wild populations declining due to overharvesting and habitat loss."
        ),
        UPSSpecies(
            commonName: "Calamus",
            scientificName: "Acorus calamus",
            status: .atRisk,
            description: "A wetland plant also known as Sweet Flag. Wetland drainage and overharvesting have reduced wild populations."
        ),
        UPSSpecies(
            commonName: "Cascara Sagrada",
            scientificName: "Frangula purshiana",
            status: .atRisk,
            description: "A Pacific Northwest tree whose bark is used as a laxative. Bark stripping kills or severely damages trees."
        ),
        UPSSpecies(
            commonName: "Chaparro",
            scientificName: "Castela emoryi",
            status: .atRisk,
            description: "A desert shrub native to the Sonoran Desert. Limited range and slow growth make it vulnerable to overharvesting."
        ),
        UPSSpecies(
            commonName: "Devil's Club",
            scientificName: "Oplopanax horridum",
            status: .atRisk,
            description: "A spiny understory shrub of Pacific Northwest old-growth forests. Sacred to many Indigenous peoples; habitat-dependent."
        ),
        UPSSpecies(
            commonName: "Echinacea",
            scientificName: "Echinacea spp.",
            status: .atRisk,
            description: "Prairie wildflowers widely used for immune support. Wild populations of E. angustifolia significantly reduced by commercial harvest."
        ),
        UPSSpecies(
            commonName: "Elephant Tree",
            scientificName: "Bursera microphylla",
            status: .atRisk,
            description: "A rare desert tree found in southern California and Arizona. Extremely limited range and slow growing."
        ),
        UPSSpecies(
            commonName: "False Unicorn Root",
            scientificName: "Chamaelirium luteum",
            status: .atRisk,
            description: "A woodland perennial used for reproductive health. Cannot be commercially cultivated; all supply is wild-harvested."
        ),
        UPSSpecies(
            commonName: "Gentian",
            scientificName: "Gentiana spp.",
            status: .atRisk,
            description: "Bitter-rooted herbs used for digestive support. Slow-growing with specific habitat requirements."
        ),
        UPSSpecies(
            commonName: "Ghost Pipe",
            scientificName: "Monotropa uniflora",
            status: .atRisk,
            description: "A parasitic plant that lacks chlorophyll, depending on mycorrhizal fungi. Cannot be cultivated; entirely dependent on intact forest ecosystems."
        ),
        UPSSpecies(
            commonName: "Goldthread",
            scientificName: "Coptis spp.",
            status: .atRisk,
            description: "Small woodland herbs with bright yellow roots. Slow-growing and sensitive to habitat disturbance."
        ),
        UPSSpecies(
            commonName: "Kava",
            scientificName: "Piper methysticum",
            status: .atRisk,
            description: "A Pacific Island plant used ceremonially and medicinally. Hawaiian populations face pressure from overharvesting and habitat loss."
        ),
        UPSSpecies(
            commonName: "Lomatium",
            scientificName: "Lomatium dissectum",
            status: .atRisk,
            description: "A large-rooted plant of western rangelands. Demand surged during respiratory illness outbreaks, straining wild populations."
        ),
        UPSSpecies(
            commonName: "Maidenhair Fern",
            scientificName: "Adiantum pedatum",
            status: .atRisk,
            description: "A delicate woodland fern with fan-shaped fronds. Sensitive to habitat disturbance and difficult to transplant."
        ),
        UPSSpecies(
            commonName: "Mayapple",
            scientificName: "Podophyllum peltatum",
            status: .atRisk,
            description: "A woodland herb with umbrella-like leaves and a single fruit. Contains podophyllotoxin used in cancer treatments."
        ),
        UPSSpecies(
            commonName: "Oregon Grape",
            scientificName: "Berberis spp.",
            status: .atRisk,
            description: "Evergreen shrubs with yellow inner bark containing berberine. Increasing commercial demand threatens wild stands."
        ),
        UPSSpecies(
            commonName: "Osha",
            scientificName: "Ligusticum porteri",
            status: .atRisk,
            description: "A high-altitude root used for respiratory conditions. Cannot be cultivated; all supply is wild-harvested from mountain habitats."
        ),
        UPSSpecies(
            commonName: "Partridge Berry",
            scientificName: "Mitchella repens",
            status: .atRisk,
            description: "A creeping woodland plant traditionally used for childbirth. Slow-growing and sensitive to forest floor disturbance."
        ),
        UPSSpecies(
            commonName: "Pinkroot",
            scientificName: "Spigelia marilandica",
            status: .atRisk,
            description: "A southeastern woodland herb with striking tubular red flowers. Limited range and habitat-specific requirements."
        ),
        UPSSpecies(
            commonName: "Pipsissewa",
            scientificName: "Chimaphila umbellata",
            status: .atRisk,
            description: "A low-growing evergreen woodland plant. Dependent on mycorrhizal relationships; very difficult to cultivate."
        ),
        UPSSpecies(
            commonName: "Pleurisy Root",
            scientificName: "Asclepias tuberosa",
            status: .atRisk,
            description: "A native milkweed also known as Butterfly Weed. Important pollinator plant; wild harvesting reduces critical habitat."
        ),
        UPSSpecies(
            commonName: "Ramps",
            scientificName: "Allium tricoccum",
            status: .atRisk,
            description: "A spring ephemeral wild leek prized culinarily. Takes 5-7 years to reach maturity; overharvesting depletes colonies."
        ),
        UPSSpecies(
            commonName: "Slippery Elm",
            scientificName: "Ulmus rubra",
            status: .atRisk,
            description: "A native elm harvested for its mucilaginous inner bark. Bark stripping often kills the tree; also threatened by Dutch elm disease."
        ),
        UPSSpecies(
            commonName: "Spikenard",
            scientificName: "Aralia racemosa",
            status: .atRisk,
            description: "A large woodland herb with aromatic roots. Slow to reproduce and vulnerable to habitat fragmentation."
        ),
        UPSSpecies(
            commonName: "Stillingia",
            scientificName: "Stillingia sylvatica",
            status: .atRisk,
            description: "A southeastern perennial also called Queen's Delight. Limited range with declining habitat."
        ),
        UPSSpecies(
            commonName: "Stone Root",
            scientificName: "Collinsonia canadensis",
            status: .atRisk,
            description: "A woodland mint relative with an extremely hard root. Difficult to cultivate and slow-growing."
        ),
        UPSSpecies(
            commonName: "Stream Orchid",
            scientificName: "Epipactis gigantea",
            status: .atRisk,
            description: "A native orchid found along streams and seeps in western North America. Habitat-dependent and declining."
        ),
        UPSSpecies(
            commonName: "Sundew",
            scientificName: "Drosera spp.",
            status: .atRisk,
            description: "Carnivorous bog plants with sticky glandular leaves. Wetland habitat loss is the primary threat."
        ),
        UPSSpecies(
            commonName: "True Unicorn",
            scientificName: "Aletris farinosa",
            status: .atRisk,
            description: "A grassland perennial used traditionally for reproductive health. Habitat loss and overharvesting have reduced populations."
        ),
        UPSSpecies(
            commonName: "Turkey Corn",
            scientificName: "Dicentra canadensis",
            status: .atRisk,
            description: "A delicate spring ephemeral related to Dutchman's Breeches. Dependent on rich woodland soils and ant-dispersed seeds."
        ),
        UPSSpecies(
            commonName: "White Sage",
            scientificName: "Salvia apiana",
            status: .atRisk,
            description: "A sacred plant used in smudging ceremonies. Commercial demand has led to illegal harvesting from wild lands."
        ),
        UPSSpecies(
            commonName: "Wild Indigo",
            scientificName: "Baptisia tinctoria",
            status: .atRisk,
            description: "A prairie legume with immune-modulating properties. Slow-growing with specific habitat requirements."
        ),
        UPSSpecies(
            commonName: "Wild Yam",
            scientificName: "Dioscorea villosa",
            status: .atRisk,
            description: "A twining vine harvested for its root. Source of diosgenin used in hormone production; wild populations declining."
        ),
        UPSSpecies(
            commonName: "Yerba Mansa",
            scientificName: "Anemopsis californica",
            status: .atRisk,
            description: "A wetland herb of the American Southwest. Wetland habitat loss is the primary threat to wild populations."
        ),
    ]

    // MARK: - In Review (formerly To-Watch)

    static let inReviewSpecies: [UPSSpecies] = [
        UPSSpecies(
            commonName: "Arnica",
            scientificName: "Arnica spp.",
            status: .inReview,
            description: "Mountain wildflowers used topically for bruises and inflammation. Increasing commercial demand on limited alpine populations."
        ),
        UPSSpecies(
            commonName: "Chaga",
            scientificName: "Inonotus obliquus",
            status: .inReview,
            description: "A parasitic fungus growing on birch trees. Surging popularity as a health tonic is driving overharvesting."
        ),
        UPSSpecies(
            commonName: "Eyebright",
            scientificName: "Euphrasia spp.",
            status: .inReview,
            description: "Small semi-parasitic herbs used for eye conditions. Difficult to cultivate due to parasitic nature."
        ),
        UPSSpecies(
            commonName: "Lobelia",
            scientificName: "Lobelia spp.",
            status: .inReview,
            description: "Native herbs historically used for respiratory conditions. Several species face habitat pressure."
        ),
        UPSSpecies(
            commonName: "Skunk Cabbage",
            scientificName: "Symplocarpus foetidus",
            status: .inReview,
            description: "A wetland plant known for generating heat to melt through snow. Wetland drainage threatens populations."
        ),
        UPSSpecies(
            commonName: "Solomon's Seal",
            scientificName: "Polygonatum biflorum",
            status: .inReview,
            description: "A graceful woodland herb with arching stems. Increasing herbal demand could impact wild populations."
        ),
        UPSSpecies(
            commonName: "Wild Cherry",
            scientificName: "Prunus serotina",
            status: .inReview,
            description: "A native tree whose bark is used for cough remedies. Bark harvesting can damage or kill trees."
        ),
        UPSSpecies(
            commonName: "Wild Geranium",
            scientificName: "Geranium maculatum",
            status: .inReview,
            description: "A woodland wildflower used as an astringent. Monitoring is underway to assess harvest impacts."
        ),
        UPSSpecies(
            commonName: "Wild Rice",
            scientificName: "Zizania palustris",
            status: .inReview,
            description: "An aquatic grass sacred to many Indigenous nations. Climate change and water pollution threaten wild stands."
        ),
        UPSSpecies(
            commonName: "Yaupon",
            scientificName: "Ilex vomitoria",
            status: .inReview,
            description: "The only native North American caffeinated plant. Growing commercial interest is being monitored."
        ),
        UPSSpecies(
            commonName: "Yerba Santa",
            scientificName: "Eriodictyon spp.",
            status: .inReview,
            description: "A western shrub used for respiratory conditions. Fire suppression and development threaten habitat."
        ),
    ]

    // MARK: - In-App Species Matching

    /// Scientific names or genus prefixes that match in-app Plant records
    static let inAppMatches: [String: String] = [
        "Cypripedium": "Cypripedium acaule",
        "Dicentra canadensis": "Dicentra canadensis",
        "Podophyllum peltatum": "Podophyllum peltatum",
        "Gentiana": "Gentiana andrewsii",
        "Berberis": "Berberis julianae",
        "Chimaphila": "Chimaphila maculata",
    ]

    /// Check if a UPS species matches an in-app plant by scientific name or genus
    static func matchingPlantName(for species: UPSSpecies) -> String? {
        // Direct match
        if let match = inAppMatches[species.scientificName] {
            return match
        }
        // Genus match (for "spp." entries)
        let genus = species.scientificName.components(separatedBy: " ").first ?? ""
        if let match = inAppMatches[genus] {
            return match
        }
        return nil
    }
}
