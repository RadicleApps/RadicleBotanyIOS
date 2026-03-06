import Foundation

/// Result of fetching images for a plant species.
struct PlantImageResult {
    /// Best general image URL (first available from any source)
    var generalImageURL: String?
    /// Organ-specific image URLs keyed by PlantOrgan
    var organImages: [PlantOrgan: String] = [:]
    /// Which tier provided the images (for logging)
    var source: String = ""

    /// Returns true if at least one image was found
    var hasAnyImage: Bool {
        generalImageURL != nil || !organImages.isEmpty
    }
}

/// Fetches plant image URLs using a 3-tier strategy:
///   Tier 1: iNaturalist (community photos, free, no key)
///   Tier 2: GBIF (research-grade specimens + field photos, free, no key)
///   Tier 3: Wikipedia (general image only, last resort)
final class PlantImageService {
    static let shared = PlantImageService()
    private init() {}

    // MARK: - Tier 1: iNaturalist (Primary)

    /// Fetches images from iNaturalist's taxa endpoint.
    /// Returns up to 10 photos per species, with multiple size options.
    /// No API key required. Rate limit: ~100 requests/minute (be polite).
    private func fetchFromINaturalist(scientificName: String) async -> PlantImageResult {
        var result = PlantImageResult()

        // Search for the taxon by exact scientific name
        var components = URLComponents(string: "https://api.inaturalist.org/v1/taxa")!
        components.queryItems = [
            URLQueryItem(name: "q", value: scientificName),
            URLQueryItem(name: "rank", value: "species"),
            URLQueryItem(name: "per_page", value: "1"),
            URLQueryItem(name: "locale", value: "en")
        ]

        guard let searchURL = components.url else { return result }

        do {
            // Step 1: Search for the taxon to get its ID
            let (searchData, searchResponse) = try await URLSession.shared.data(from: searchURL)

            guard let httpResponse = searchResponse as? HTTPURLResponse else {
                print("[PlantImageService] ❌ No HTTP response for iNaturalist search: \(scientificName)")
                return result
            }

            guard httpResponse.statusCode == 200 else {
                print("[PlantImageService] ❌ iNaturalist search HTTP \(httpResponse.statusCode) for \(scientificName)")
                return result
            }

            let searchResult = try JSONDecoder().decode(INatTaxaResponse.self, from: searchData)

            guard let taxon = searchResult.results.first,
                  taxon.name.lowercased() == scientificName.lowercased() else {
                print("[PlantImageService] ⚠️ iNaturalist: no exact match for \(scientificName)")
                return result
            }

            // Check if the search result already has a default photo
            if let defaultPhoto = taxon.default_photo,
               let mediumURL = defaultPhoto.medium_url ?? defaultPhoto.square_url {
                // Convert square URL to medium if needed
                let url = mediumURL.replacingOccurrences(of: "/square.", with: "/medium.")
                result.generalImageURL = url
            }

            // Step 2: Fetch full taxon detail to get taxon_photos array
            guard let detailURL = URL(string: "https://api.inaturalist.org/v1/taxa/\(taxon.id)") else {
                return result
            }

            let (detailData, detailResponse) = try await URLSession.shared.data(from: detailURL)

            guard let detailHTTP = detailResponse as? HTTPURLResponse,
                  detailHTTP.statusCode == 200 else {
                // Still have the default photo from search, return that
                if result.hasAnyImage {
                    result.source = "iNaturalist"
                    print("[PlantImageService] ✅ iNaturalist default photo for \(scientificName)")
                }
                return result
            }

            let detailResult = try JSONDecoder().decode(INatTaxaResponse.self, from: detailData)

            guard let fullTaxon = detailResult.results.first,
                  let taxonPhotos = fullTaxon.taxon_photos, !taxonPhotos.isEmpty else {
                if result.hasAnyImage {
                    result.source = "iNaturalist"
                    print("[PlantImageService] ✅ iNaturalist default photo for \(scientificName)")
                }
                return result
            }

            // Use the first photo as general image (highest quality/most voted)
            if let firstPhoto = taxonPhotos.first?.photo,
               let url = firstPhoto.medium_url ?? firstPhoto.square_url {
                result.generalImageURL = url.replacingOccurrences(of: "/square.", with: "/medium.")
            }

            // iNaturalist doesn't tag photos by organ, but we can assign
            // additional photos to organ slots to populate the detail view.
            // Assign photos 2-7 to organ categories for visual variety.
            let organMapping: [PlantOrgan] = [.flower, .leaf, .fruit, .bark, .habit, .stem]
            for (index, organType) in organMapping.enumerated() {
                let photoIndex = index + 1 // Skip first (already used as general)
                guard photoIndex < taxonPhotos.count else { break }

                if let photo = taxonPhotos[photoIndex].photo,
                   let url = photo.medium_url ?? photo.square_url {
                    result.organImages[organType] = url.replacingOccurrences(of: "/square.", with: "/medium.")
                }
            }

            result.source = "iNaturalist"
            print("[PlantImageService] ✅ iNaturalist images for \(scientificName): general=\(result.generalImageURL != nil), extras=\(result.organImages.count)")
            return result

        } catch {
            print("[PlantImageService] ❌ iNaturalist failed for \(scientificName): \(error.localizedDescription)")
            return result
        }
    }

    // MARK: - Tier 2: GBIF (Research-Grade)

    /// Fetches images from GBIF's occurrence search endpoint using the species' GBIF taxon key.
    /// Returns research-grade specimen photos and field observations.
    /// No API key required. Free and open.
    private func fetchFromGBIF(gbifId: Int, scientificName: String) async -> PlantImageResult {
        var result = PlantImageResult()

        var components = URLComponents(string: "https://api.gbif.org/v1/occurrence/search")!
        components.queryItems = [
            URLQueryItem(name: "taxonKey", value: String(gbifId)),
            URLQueryItem(name: "mediaType", value: "StillImage"),
            URLQueryItem(name: "limit", value: "10")
        ]

        guard let url = components.url else { return result }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[PlantImageService] ❌ GBIF HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) for \(scientificName)")
                return result
            }

            let gbifResult = try JSONDecoder().decode(GBIFOccurrenceResponse.self, from: data)

            // Collect all image URLs from occurrences
            var imageURLs: [String] = []
            for occurrence in gbifResult.results {
                guard let media = occurrence.media else { continue }
                for item in media {
                    if item.type == "StillImage",
                       let identifier = item.identifier,
                       !identifier.isEmpty {
                        imageURLs.append(identifier)
                        if imageURLs.count >= 7 { break }
                    }
                }
                if imageURLs.count >= 7 { break }
            }

            guard !imageURLs.isEmpty else {
                print("[PlantImageService] ⚠️ GBIF: no images found for \(scientificName)")
                return result
            }

            // First image as general
            result.generalImageURL = imageURLs[0]

            // Assign additional images to organ slots (for visual variety)
            let organMapping: [PlantOrgan] = [.flower, .leaf, .fruit, .bark, .habit, .stem]
            for (index, organType) in organMapping.enumerated() {
                let imageIndex = index + 1
                guard imageIndex < imageURLs.count else { break }
                result.organImages[organType] = imageURLs[imageIndex]
            }

            result.source = "GBIF"
            print("[PlantImageService] ✅ GBIF images for \(scientificName): general=\(result.generalImageURL != nil), extras=\(result.organImages.count)")
            return result

        } catch {
            print("[PlantImageService] ❌ GBIF failed for \(scientificName): \(error.localizedDescription)")
            return result
        }
    }

    // MARK: - Tier 3: Wikipedia (Last Resort)

    private let wikipediaBaseURL = "https://en.wikipedia.org/api/rest_v1/page/summary/"
    private let userAgent = "RadicleBotany/1.0 (iOS; educational botany app)"

    /// Fetches a thumbnail image URL from Wikipedia for a given scientific name.
    /// Used as last-resort fallback — returns only a general image, never organ-specific.
    private func fetchFromWikipedia(scientificName: String) async -> String? {
        let wikiName = scientificName.replacingOccurrences(of: " ", with: "_")

        guard let encoded = wikiName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: wikipediaBaseURL + encoded) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let summary = try JSONDecoder().decode(WikipediaSummary.self, from: data)
            let imageURL = summary.thumbnail?.source ?? summary.originalimage?.source
            if imageURL != nil {
                print("[PlantImageService] 📖 Wikipedia fallback image for \(scientificName)")
            }
            return imageURL
        } catch {
            return nil
        }
    }

    // MARK: - Public API

    /// Fetches all available image URLs for a plant species using a 3-tier strategy:
    ///   Tier 1: iNaturalist (community photos, best diversity)
    ///   Tier 2: GBIF (research-grade specimens, requires gbifId)
    ///   Tier 3: Wikipedia (general image only, last resort)
    func fetchAllImages(for scientificName: String, gbifId: Int? = nil) async -> PlantImageResult {
        // Tier 1: iNaturalist (best community photos, multiple per species)
        let inatResult = await fetchFromINaturalist(scientificName: scientificName)
        if inatResult.hasAnyImage { return inatResult }

        // Tier 2: GBIF (research-grade specimens + field photos)
        if let gbifId {
            let gbifResult = await fetchFromGBIF(gbifId: gbifId, scientificName: scientificName)
            if gbifResult.hasAnyImage { return gbifResult }
        }

        // Tier 3: Wikipedia (general image only, last resort)
        var fallback = PlantImageResult()
        if let wikiURL = await fetchFromWikipedia(scientificName: scientificName) {
            fallback.generalImageURL = wikiURL
            fallback.source = "Wikipedia"
        }
        return fallback
    }

    /// Fetches just the general (best available) image URL for a plant species.
    func fetchImageURL(for scientificName: String, gbifId: Int? = nil) async -> String? {
        let result = await fetchAllImages(for: scientificName, gbifId: gbifId)
        return result.generalImageURL ?? result.organImages.values.first
    }
}

// MARK: - iNaturalist Response Models

private struct INatTaxaResponse: Codable {
    let total_results: Int
    let results: [INatTaxon]
}

private struct INatTaxon: Codable {
    let id: Int
    let name: String
    let preferred_common_name: String?
    let default_photo: INatPhoto?
    let taxon_photos: [INatTaxonPhoto]?
}

private struct INatTaxonPhoto: Codable {
    let photo: INatPhoto?
}

private struct INatPhoto: Codable {
    let id: Int?
    let license_code: String?
    let attribution: String?
    let square_url: String?
    let small_url: String?
    let medium_url: String?
    let large_url: String?
    let original_url: String?
}

// MARK: - GBIF Response Models

private struct GBIFOccurrenceResponse: Codable {
    let results: [GBIFOccurrence]
}

private struct GBIFOccurrence: Codable {
    let media: [GBIFMedia]?
}

private struct GBIFMedia: Codable {
    let type: String?
    let identifier: String?
    let format: String?
}

// MARK: - Wikipedia Response Models

private struct WikipediaSummary: Codable {
    let thumbnail: WikipediaImage?
    let originalimage: WikipediaImage?
}

private struct WikipediaImage: Codable {
    let source: String
    let width: Int?
    let height: Int?
}
