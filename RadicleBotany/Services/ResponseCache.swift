import Foundation

/// Response Cache — Reduces API costs by caching intelligence backend responses.
///
/// Two TTL tiers:
/// - General queries: 1 hour (contextual questions)
/// - Botanical content: 24 hours (taxonomy, morphology — stable content)
///
/// Cache key: hash of (query + screen)

final class ResponseCache {
    static let shared = ResponseCache()

    private var cache: [String: CachedResponse] = [:]
    private let lock = NSLock()
    private let maxEntries = 200

    private init() {
        loadFromDisk()
    }

    // MARK: - Cache Entry

    struct CachedResponse: Codable {
        let response: String
        let timestamp: Date
        let ttlSeconds: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttlSeconds
        }
    }

    // MARK: - TTL Categories

    enum CacheTTL {
        case general         // 1 hour
        case botanicalContent // 24 hours

        var seconds: TimeInterval {
            switch self {
            case .general: return 3600
            case .botanicalContent: return 86400
            }
        }
    }

    // MARK: - Public API

    func get(query: String, screen: String) -> String? {
        let key = cacheKey(query: query, screen: screen)

        lock.lock()
        defer { lock.unlock() }

        guard let entry = cache[key], !entry.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry.response
    }

    func set(query: String, screen: String, response: String, ttl: CacheTTL) {
        let key = cacheKey(query: query, screen: screen)

        lock.lock()

        if cache.count >= maxEntries {
            evictOldest()
        }

        cache[key] = CachedResponse(
            response: response,
            timestamp: Date(),
            ttlSeconds: ttl.seconds
        )

        lock.unlock()

        saveToDisk()
    }

    /// Determine the appropriate TTL for a query
    static func ttlFor(query: String) -> CacheTTL {
        let lowered = query.lowercased()

        let botanicalKeywords = [
            "morphology", "taxonomy", "species", "family", "genus", "bloom",
            "conservation", "photosynthesis", "venation", "inflorescence",
            "pinnate", "palmate", "compound", "simple", "alternate", "opposite",
            "dicot", "monocot", "angiosperm", "gymnosperm", "fern", "moss",
            "stamen", "pistil", "sepal", "petal", "carpel", "ovary",
            "pollination", "germination", "dormancy", "deciduous", "evergreen",
            "iucn", "endangered", "threatened", "biogeography", "introduced",
            "habitat", "biome", "ecosystem", "cultivar", "hybrid"
        ]

        if botanicalKeywords.contains(where: { lowered.contains($0) }) {
            return .botanicalContent
        }

        return .general
    }

    func clearAll() {
        lock.lock()
        cache.removeAll()
        lock.unlock()

        UserDefaults.standard.removeObject(forKey: "radiclebotany_response_cache")
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    // MARK: - Internal

    private func cacheKey(query: String, screen: String) -> String {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let components = "\(normalized)|\(screen)"

        var hash: UInt64 = 5381
        for byte in components.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    private func evictOldest() {
        let expired = cache.filter { $0.value.isExpired }
        for key in expired.keys {
            cache.removeValue(forKey: key)
        }

        if cache.count >= maxEntries {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(cache.count - maxEntries + 10)
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: "radiclebotany_response_cache")
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: "radiclebotany_response_cache"),
              let decoded = try? JSONDecoder().decode([String: CachedResponse].self, from: data) else {
            return
        }
        cache = decoded.filter { !$0.value.isExpired }
    }
}
