import SwiftUI

/// A plant image view that prioritizes locally cached image data, then falls back to AsyncImage URL loading.
/// Ensures every plant ALWAYS displays an image — either from persistent cache or network.
///
/// Priority:
///   1. `plant.cachedImageData` → instant, offline-safe
///   2. `plant.bestImageURL` → AsyncImage network fetch
///   3. Placeholder (leaf icon on surfaceElevated background)
struct CachedPlantImage: View {
    let plant: Plant
    var contentMode: ContentMode = .fill

    var body: some View {
        if let cachedImage = plant.cachedImage {
            // Tier 1: Persistent cached image — instant, always available
            Image(uiImage: cachedImage)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
            // Tier 2: Network fetch via AsyncImage
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .empty:
                    plantImagePlaceholder
                        .overlay {
                            ProgressView()
                                .tint(AppColors.textMuted)
                        }
                case .failure:
                    plantImagePlaceholder
                @unknown default:
                    plantImagePlaceholder
                }
            }
        } else {
            // Tier 3: No image at all — show placeholder
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
}

/// Grid-specific version that fills a square frame with clipping.
/// Drop-in replacement for the SpeciesGridView, BloomCalendarView, ConservationView patterns.
struct CachedPlantGridImage: View {
    let plant: Plant
    let size: CGFloat

    var body: some View {
        if let cachedImage = plant.cachedImage {
            Image(uiImage: cachedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
        } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                default:
                    gridPlaceholder
                }
            }
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
struct CachedPlantHeroImage: View {
    let plant: Plant
    var height: CGFloat = 200

    var body: some View {
        if let cachedImage = plant.cachedImage {
            Image(uiImage: cachedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    heroGradientPlaceholder
                        .overlay(ProgressView().tint(AppColors.textMuted))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                case .failure:
                    heroGradientPlaceholder
                @unknown default:
                    heroGradientPlaceholder
                }
            }
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
}
