import SwiftUI

/// A plant image view that prioritizes full-size cached images, then loads from network.
/// Detects bundled small images (240px, 15-40KB) and upgrades to full-size on network load.
///
/// Priority:
///   1. Full-size `plant.cachedImageData` (>50KB) → instant, sharp
///   2. `plant.bestImageURL` → network fetch, upgrades to full-size in SwiftData
///   3. Bundled small image fallback (if no URL available)
///   4. Placeholder (app icon on surfaceElevated background)
struct CachedPlantImage: View {
    let plant: Plant
    var contentMode: ContentMode = .fill

    var body: some View {
        // Single @externalStorage read via cachedImageInfo
        let info = plant.cachedImageInfo
        if let info, info.isFullSize {
            // Full-size cached image — instant, sharp
            Image(uiImage: info.image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if let imageURL = plant.largeImageURL, let url = URL(string: imageURL) {
            // Load large (~1024px) from network for Retina sharpness
            ThrottledAsyncImage(url: url, contentMode: contentMode, onLoad: { image in
                upgradeToFullSize(image)
            }) {
                plantImagePlaceholder
            }
        } else {
            plantImagePlaceholder
        }
    }

    private var plantImagePlaceholder: some View {
        AppColors.cardElevated
            .overlay {
                Image("AppIconDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .opacity(0.3)
            }
    }

    /// Replaces thumbnail with large image in SwiftData.
    private func upgradeToFullSize(_ image: UIImage) {
        guard let compressed = image.jpegData(compressionQuality: 0.85) else { return }
        plant.cachedImageData = compressed
    }
}

/// Grid-specific version that fills a square frame with clipping.
/// Loads medium-resolution images (~500px) for sharp Retina display.
/// Shows bundled 240px image as instant placeholder while loading.
/// Throttled to max 8 concurrent via ThrottledImageLoader.
///
/// PERFORMANCE: Does NOT write to SwiftData on load. Writing cachedImageData
/// during scroll triggers @Query re-renders of the entire parent grid (cascade
/// effect with 8 concurrent loads = 8 full re-renders). Instead, images persist
/// via ThrottledImageLoader's URLCache (disk) + NSCache (memory). SwiftData
/// caching only happens from PlantDetailView for offline access.
struct CachedPlantGridImage: View {
    let plant: Plant
    let size: CGFloat

    var body: some View {
        // Single read of @externalStorage via cachedImageInfo — avoids double file I/O
        let info = plant.cachedImageInfo

        if let info, info.isFullSize {
            // Full-size cached image — instant, sharp
            Image(uiImage: info.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
        } else if let urlString = plant.bestImageURL, let url = URL(string: urlString) {
            // Load medium (~500px) from network
            // No onLoad/SwiftData write — avoids cascade @Query re-renders during scroll
            ThrottledAsyncImage(url: url, contentMode: .fill) {
                // Show thumbnail as blurred placeholder if available, otherwise grey
                if let info {
                    Image(uiImage: info.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                        .blur(radius: 4)
                } else {
                    gridPlaceholder
                }
            }
            .frame(width: size, height: size)
            .clipped()
        } else if let info {
            // No URL but has thumbnail — show what we have
            Image(uiImage: info.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
        } else {
            gridPlaceholder
        }
    }

    private var gridPlaceholder: some View {
        AppColors.cardElevated
            .frame(width: size, height: size)
            .overlay {
                Image("AppIconDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .opacity(0.3)
            }
    }
}

/// Hero-style version for PlantDetailView — uses .fit content mode with gradient fallback.
/// Loads large-resolution (~1024px) images for Retina-sharp hero display.
/// Shows bundled small image (240px) as instant placeholder while upgrading.
/// Upgrades cachedImageData on success.
struct CachedPlantHeroImage: View {
    let plant: Plant
    var height: CGFloat = 200

    var body: some View {
        // Single @externalStorage read via cachedImageInfo
        let info = plant.cachedImageInfo
        if let info, info.isFullSize {
            // Full-size cached image (>50KB) — instant, sharp
            Image(uiImage: info.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        } else if let imageURL = plant.largeImageURL, let url = URL(string: imageURL) {
            // Load large (~1024px) from network for Retina sharpness
            ThrottledAsyncImage(url: url, contentMode: .fit, onLoad: { image in
                upgradeToFullSize(image)
            }) {
                // Show bundled small image as instant placeholder while loading
                if let info {
                    Image(uiImage: info.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .overlay(
                            ProgressView()
                                .tint(AppColors.textMuted)
                        )
                } else {
                    heroGradientPlaceholder
                        .overlay(ProgressView().tint(AppColors.textMuted))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        } else if let info {
            // No URL but has bundled image — show what we have
            Image(uiImage: info.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        } else {
            heroGradientPlaceholder
        }
    }

    private var heroGradientPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.success.opacity(0.15),
                    AppColors.success.opacity(0.05),
                    AppColors.appBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image("AppIconDark")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .opacity(0.15)
        }
        .frame(height: height)
    }

    /// Replaces bundled small/medium with large image in SwiftData.
    private func upgradeToFullSize(_ image: UIImage) {
        guard let compressed = image.jpegData(compressionQuality: 0.85) else { return }
        plant.cachedImageData = compressed
    }
}
