import SwiftUI
import Combine

/// A global image loader that limits concurrent downloads to avoid
/// flooding the network when grid views display hundreds of plant cells.
///
/// Three-tier caching:
///   1. NSCache (in-memory) — zero-cost, instant, no JPEG decoding
///   2. URLCache (disk) — decode on background thread, store in NSCache
///   3. Network download — throttled to max 6 concurrent, cached on success
///
/// All JPEG decoding happens off the main thread via Task.detached to prevent
/// UI stuttering during fast scrolling. Images are pre-rendered with
/// prepareForDisplay() for zero-cost GPU rendering on first frame.
@MainActor
final class ThrottledImageLoader: ObservableObject {
    static let shared = ThrottledImageLoader()

    /// Max concurrent image downloads — 6 balances speed vs. CPU/battery impact.
    /// Higher values (15-20) cause UI freezing when combined with JPEG decoding.
    private let maxConcurrent = 6
    private var activeCount = 0
    private var waitingQueue: [(url: URL, continuation: CheckedContinuation<UIImage?, Never>)] = []

    /// In-memory cache of decoded UIImages. Prevents repeated JPEG decoding
    /// from URLCache on every view render. Auto-evicts under memory pressure.
    /// totalCostLimit caps memory usage (~150MB for grid-sized images).
    let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        cache.totalCostLimit = 150 * 1024 * 1024 // 150 MB max
        return cache
    }()

    /// Synchronous cache check — returns image instantly if in NSCache.
    /// Call from view body to avoid 1-frame blurry placeholder flash.
    func cachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url.absoluteString as NSString)
    }

    /// Pre-warms NSCache by decoding images already in URLCache (disk).
    /// Call after UI is visible with a small batch (~50 URLs).
    /// Uses small batches of 4 with yields between to avoid CPU spikes.
    nonisolated func warmUpCache(urls: [URL]) async {
        let startTime = Date()
        var warmedCount = 0

        // Small batches of 4 with yield — avoids CPU spikes that cause UI freezing
        let batchSize = 4
        for batchStart in stride(from: 0, to: urls.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, urls.count)
            let batch = Array(urls[batchStart..<batchEnd])

            let results = await withTaskGroup(of: (NSString, UIImage?).self, returning: [(NSString, UIImage)].self) { group in
                for url in batch {
                    let key = url.absoluteString as NSString

                    group.addTask {
                        let request = URLRequest(url: url)
                        guard let cachedData = URLCache.shared.cachedResponse(for: request)?.data else {
                            return (key, nil)
                        }
                        let image = await Self.decodeImageInBackground(cachedData)
                        return (key, image)
                    }
                }

                var decoded: [(NSString, UIImage)] = []
                for await (key, image) in group {
                    if let image {
                        decoded.append((key, image))
                    }
                }
                return decoded
            }

            // Write to NSCache on MainActor in one batch
            await MainActor.run {
                for (key, image) in results {
                    memoryCache.setObject(image, forKey: key)
                    warmedCount += 1
                }
            }

            // Yield between batches so UI rendering gets CPU time
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("[ThrottledImageLoader] Warmed \(warmedCount)/\(urls.count) images in \(String(format: "%.2f", elapsed))s")
    }

    func loadImage(from url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString

        // Tier 1: In-memory cache — instant, no decode needed
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // Tier 2: URLCache (disk) — decode on BACKGROUND THREAD (not main)
        let request = URLRequest(url: url)
        if let cachedData = URLCache.shared.cachedResponse(for: request)?.data {
            if let image = await Self.decodeImageInBackground(cachedData) {
                memoryCache.setObject(image, forKey: key)
                return image
            }
        }

        // Tier 3: Network download — throttled
        if activeCount >= maxConcurrent {
            return await withCheckedContinuation { continuation in
                waitingQueue.append((url: url, continuation: continuation))
            }
        }

        return await performDownload(url: url, request: request)
    }

    private func performDownload(url: URL, request: URLRequest) async -> UIImage? {
        activeCount += 1
        defer {
            activeCount -= 1
            dequeueNext()
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            // Store in URLCache for disk persistence
            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: request)

            // Decode on BACKGROUND THREAD — never blocks main thread during scroll
            guard let image = await Self.decodeImageInBackground(data) else { return nil }
            let key = url.absoluteString as NSString
            memoryCache.setObject(image, forKey: key)
            return image
        } catch {
            return nil
        }
    }

    private func dequeueNext() {
        guard !waitingQueue.isEmpty else { return }
        let next = waitingQueue.removeFirst()
        Task {
            let image = await performDownload(url: next.url, request: URLRequest(url: next.url))
            next.continuation.resume(returning: image)
        }
    }

    /// Decodes JPEG/PNG data on a background thread to avoid blocking the main thread.
    /// Calls prepareForDisplay() to pre-render at display resolution, preventing
    /// GPU decompression stalls on the first frame render.
    private nonisolated static func decodeImageInBackground(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let image = UIImage(data: data) else { return nil }
            // Pre-render for current display scale — avoids lazy GPU decompression
            // when Core Animation first composites the layer on the main thread.
            let prepared = await withCheckedContinuation { continuation in
                image.prepareForDisplay { result in
                    continuation.resume(returning: result)
                }
            }
            return prepared ?? image
        }.value
    }
}

/// A drop-in SwiftUI view that uses ThrottledImageLoader instead of raw AsyncImage.
/// Shows placeholder immediately, loads image with concurrency throttling.
/// Optional `onLoad` callback provides the loaded UIImage for write-through caching.
///
/// Key performance features:
/// - Cancels downloads when scrolled off screen (frees throttle slot)
/// - Keeps loaded images in @State so they survive re-renders
/// - ThrottledImageLoader's NSCache means re-appearing cells get instant hits
struct ThrottledAsyncImage<Placeholder: View>: View {
    let url: URL?
    let contentMode: ContentMode
    var onLoad: ((UIImage) -> Void)?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var hasLoaded = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let url, let cached = ThrottledImageLoader.shared.cachedImage(for: url) {
                // Synchronous NSCache hit — instant sharp image, no placeholder flash
                Image(uiImage: cached)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .onAppear { image = cached; hasLoaded = true }
            } else {
                placeholder()
            }
        }
        .onAppear {
            guard image == nil, !hasLoaded, let url else { return }
            // One more sync check before going async
            if let cached = ThrottledImageLoader.shared.cachedImage(for: url) {
                self.image = cached
                self.hasLoaded = true
                return
            }
            loadTask = Task {
                let loaded = await ThrottledImageLoader.shared.loadImage(from: url)
                if !Task.isCancelled, let loaded {
                    self.image = loaded
                    self.hasLoaded = true
                    onLoad?(loaded)
                }
            }
        }
        .onDisappear {
            // Cancel pending download if cell scrolled off screen — frees up a throttle slot.
            // If image already loaded, keep it in @State for instant re-display.
            if image == nil {
                loadTask?.cancel()
                loadTask = nil
            }
        }
    }
}
