import Foundation

/// Fetches species metadata from PlantNet's species database, including IUCN conservation status
/// and common names in multiple languages.
final class PlantNetSpeciesService {
    static let shared = PlantNetSpeciesService()
    private init() {}

    private var apiKey: String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let key = config["PLANTNET_API_KEY"] as? String else {
            return nil
        }
        return key
    }

    /// Fetches species info from PlantNet for a given scientific name prefix.
    func fetchSpeciesInfo(scientificName: String) async -> SpeciesInfo? {
        guard let apiKey else {
            print("[PlantNetSpeciesService] No API key found")
            return nil
        }

        var components = URLComponents(string: "https://my-api.plantnet.org/v2/species")!
        components.queryItems = [
            URLQueryItem(name: "prefix", value: scientificName),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let results = try JSONDecoder().decode([SpeciesInfo].self, from: data)

            // Find exact match by scientific name (case-insensitive)
            return results.first { info in
                info.scientificNameWithoutAuthor?.lowercased() == scientificName.lowercased()
            } ?? results.first
        } catch {
            print("[PlantNetSpeciesService] Failed for \(scientificName): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Response Models

struct SpeciesInfo: Codable {
    let scientificNameWithoutAuthor: String?
    let scientificNameAuthorship: String?
    let commonNames: [String]?
    let gbif: SpeciesGBIF?
    let powo: SpeciesPOWO?
    let iucnCategory: String?
}

struct SpeciesGBIF: Codable {
    let id: Int?
}

struct SpeciesPOWO: Codable {
    let id: String?
}

// MARK: - IUCN Category

enum IUCNCategory: String {
    case CR // Critically Endangered
    case EN // Endangered
    case VU // Vulnerable
    case NT // Near Threatened
    case LC // Least Concern
    case DD // Data Deficient
    case NE // Not Evaluated

    init?(rawValue: String) {
        switch rawValue.uppercased() {
        case "CR": self = .CR
        case "EN": self = .EN
        case "VU": self = .VU
        case "NT": self = .NT
        case "LC": self = .LC
        case "DD": self = .DD
        case "NE": self = .NE
        default: return nil
        }
    }

    var displayString: String {
        switch self {
        case .CR: return "Critically Endangered"
        case .EN: return "Endangered"
        case .VU: return "Vulnerable"
        case .NT: return "Near Threatened"
        case .LC: return "Least Concern"
        case .DD: return "Data Deficient"
        case .NE: return "Not Evaluated"
        }
    }

    var isAtRisk: Bool {
        switch self {
        case .CR, .EN, .VU, .NT: return true
        case .LC, .DD, .NE: return false
        }
    }
}
