import Foundation
import CoreLocation

// MARK: - Response Models

struct GBIFOccurrenceCoordinate: Identifiable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let year: Int?
    let basisOfRecord: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - GBIF Occurrence Service

final class GBIFOccurrenceService {
    static let shared = GBIFOccurrenceService()
    private init() {}

    private var cache: [Int: CachedOccurrences] = [:]
    private let lock = NSLock()
    private let cacheTTL: TimeInterval = 86400 // 24 hours
    private let maxCacheEntries = 50

    private struct CachedOccurrences {
        let occurrences: [GBIFOccurrenceCoordinate]
        let totalCount: Int
        let fetchDate: Date
        var isExpired: Bool { Date().timeIntervalSince(fetchDate) > 86400 }
    }

    // MARK: - Public API

    /// Fetches up to 300 geolocated occurrences for a species from GBIF.
    /// Returns cached data if available and not expired.
    func fetchOccurrences(gbifId: Int) async -> (occurrences: [GBIFOccurrenceCoordinate], totalCount: Int) {
        // Check cache
        lock.lock()
        if let cached = cache[gbifId], !cached.isExpired {
            lock.unlock()
            return (cached.occurrences, cached.totalCount)
        }
        lock.unlock()

        // Fetch from GBIF
        let urlString = "https://api.gbif.org/v1/occurrence/search?speciesKey=\(gbifId)&hasCoordinate=true&limit=300"
        guard let url = URL(string: urlString) else {
            print("[GBIFOccurrenceService] Invalid URL for gbifId \(gbifId)")
            return ([], 0)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[GBIFOccurrenceService] Non-200 response for gbifId \(gbifId)")
                return ([], 0)
            }

            let decoded = try JSONDecoder().decode(GBIFSearchResponse.self, from: data)

            let occurrences: [GBIFOccurrenceCoordinate] = decoded.results.compactMap { record in
                guard let lat = record.decimalLatitude,
                      let lon = record.decimalLongitude else { return nil }
                return GBIFOccurrenceCoordinate(
                    id: "\(record.key ?? 0)",
                    latitude: lat,
                    longitude: lon,
                    country: record.country,
                    year: record.year,
                    basisOfRecord: record.basisOfRecord
                )
            }

            let totalCount = decoded.count

            // Store in cache
            lock.lock()
            if cache.count >= maxCacheEntries {
                // Evict oldest entry
                if let oldestKey = cache.min(by: { $0.value.fetchDate < $1.value.fetchDate })?.key {
                    cache.removeValue(forKey: oldestKey)
                }
            }
            cache[gbifId] = CachedOccurrences(
                occurrences: occurrences,
                totalCount: totalCount,
                fetchDate: Date()
            )
            lock.unlock()

            print("[GBIFOccurrenceService] Fetched \(occurrences.count) occurrences for gbifId \(gbifId) (total: \(totalCount))")
            return (occurrences, totalCount)

        } catch {
            print("[GBIFOccurrenceService] Error fetching gbifId \(gbifId): \(error.localizedDescription)")
            return ([], 0)
        }
    }

    // MARK: - Species Name Resolution

    /// Resolves a scientific name to a GBIF species key using the Species Match API.
    /// This is a lightweight call (~200ms) that returns the usageKey for occurrence lookups.
    func resolveSpeciesKey(scientificName: String) async -> Int? {
        let encoded = scientificName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scientificName
        let urlString = "https://api.gbif.org/v1/species/match?name=\(encoded)&strict=false"

        guard let url = URL(string: urlString) else {
            print("[GBIFOccurrenceService] Invalid species match URL for: \(scientificName)")
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[GBIFOccurrenceService] Non-200 species match response for: \(scientificName)")
                return nil
            }

            let decoded = try JSONDecoder().decode(GBIFSpeciesMatchResponse.self, from: data)

            // Only use high-confidence matches (EXACT or FUZZY with high confidence)
            guard decoded.matchType != "NONE",
                  let usageKey = decoded.usageKey else {
                print("[GBIFOccurrenceService] No GBIF match for: \(scientificName) (matchType: \(decoded.matchType ?? "nil"))")
                return nil
            }

            print("[GBIFOccurrenceService] Resolved \(scientificName) → gbifId \(usageKey) (match: \(decoded.matchType ?? "unknown"))")
            return usageKey

        } catch {
            print("[GBIFOccurrenceService] Species match error for \(scientificName): \(error.localizedDescription)")
            return nil
        }
    }

    /// Clears the cache for a specific species or all species.
    func clearCache(gbifId: Int? = nil) {
        lock.lock()
        if let id = gbifId {
            cache.removeValue(forKey: id)
        } else {
            cache.removeAll()
        }
        lock.unlock()
    }
}

// MARK: - Private GBIF API Response Models

private struct GBIFSpeciesMatchResponse: Codable {
    let usageKey: Int?
    let scientificName: String?
    let matchType: String?
    let confidence: Int?
    let rank: String?
}

private struct GBIFSearchResponse: Codable {
    let offset: Int
    let limit: Int
    let count: Int
    let results: [GBIFOccurrenceRecord]
}

private struct GBIFOccurrenceRecord: Codable {
    let key: Int?
    let decimalLatitude: Double?
    let decimalLongitude: Double?
    let country: String?
    let year: Int?
    let basisOfRecord: String?
}
