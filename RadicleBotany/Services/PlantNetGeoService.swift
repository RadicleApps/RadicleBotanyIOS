import Foundation

/// Fetches predicted plant species for a geographic area using PlantNet's Species Distribution Model.
final class PlantNetGeoService {
    static let shared = PlantNetGeoService()
    private init() {}

    private var apiKey: String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let key = config["PLANTNET_API_KEY"] as? String else {
            return nil
        }
        return key
    }

    /// Fetches predicted species for a geographic bounding box.
    func fetchPredictedSpecies(
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double
    ) async throws -> [GeoPrediction] {
        guard let apiKey else {
            print("[PlantNetGeoService] No API key found")
            return []
        }

        var components = URLComponents(string: "https://my-api.plantnet.org/v2/prediction/geo/species")!
        components.queryItems = [
            URLQueryItem(name: "topLeftLat", value: String(maxLat)),
            URLQueryItem(name: "topLeftLon", value: String(minLon)),
            URLQueryItem(name: "bottomRightLat", value: String(minLat)),
            URLQueryItem(name: "bottomRightLon", value: String(maxLon)),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]

        guard let url = components.url else { return [] }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[PlantNetGeoService] API error: status \(status)")
            return []
        }

        let decoded = try JSONDecoder().decode([GeoPrediction].self, from: data)
        print("[PlantNetGeoService] Found \(decoded.count) predicted species")
        return decoded
    }
}

// MARK: - Response Models

struct GeoPrediction: Codable, Identifiable {
    let scientificNameWithoutAuthor: String?
    let scientificNameAuthorship: String?
    let commonNames: [String]?
    let genus: GeoTaxonInfo?
    let family: GeoTaxonInfo?
    let gbif: GeoGBIF?
    let images: [GeoImage]?
    let score: Double?
    let observationCount: Int?

    var id: String { scientificNameWithoutAuthor ?? UUID().uuidString }

    var displayName: String {
        commonNames?.first ?? scientificNameWithoutAuthor ?? "Unknown"
    }

    var scientificName: String {
        scientificNameWithoutAuthor ?? "Unknown"
    }

    /// Best available image URL from the prediction
    var bestImageURL: String? {
        images?.first?.url?.m ?? images?.first?.url?.o
    }
}

struct GeoTaxonInfo: Codable {
    let scientificNameWithoutAuthor: String?
    let scientificName: String?
}

struct GeoGBIF: Codable {
    let id: Int?
}

struct GeoImage: Codable {
    let url: GeoImageURL?
    let organ: String?
}

struct GeoImageURL: Codable {
    let o: String?
    let m: String?
    let s: String?
}
