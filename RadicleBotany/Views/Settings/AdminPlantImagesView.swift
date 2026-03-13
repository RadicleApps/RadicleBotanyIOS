import SwiftUI
import SwiftData

/// Admin screen for managing plant species images.
/// Shows all species with their organ-specific images and allows refreshing from PlantNet.
struct AdminPlantImagesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]

    @State private var searchText = ""
    @State private var filterMode: ImageFilterMode = .all
    @State private var isRefreshingAll = false
    @State private var refreshProgress = 0
    @State private var refreshTotal = 0

    private enum ImageFilterMode: String, CaseIterable {
        case all = "All"
        case withImages = "Has Images"
        case noImages = "No Images"
    }

    private var filteredPlants: [Plant] {
        var result = allPlants

        // Apply image filter
        switch filterMode {
        case .all: break
        case .withImages:
            result = result.filter { $0.bestImageURL != nil }
        case .noImages:
            result = result.filter { $0.bestImageURL == nil }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.scientificName.localizedCaseInsensitiveContains(searchText) ||
                $0.commonName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var imageStats: (total: Int, withImages: Int, withOrgans: Int, cached: Int) {
        let total = allPlants.count
        let withImages = allPlants.filter { $0.bestImageURL != nil }.count
        let withOrgans = allPlants.filter { !$0.organImages.isEmpty }.count
        let cached = allPlants.filter { $0.cachedImageData != nil }.count
        return (total, withImages, withOrgans, cached)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            statsBar

            // Search + filter
            searchAndFilter

            // Plant list
            if filteredPlants.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPlants) { plant in
                            NavigationLink(destination: AdminPlantImageDetailView(plant: plant)) {
                                plantImageRow(plant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Plant Images")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshAllImages() }
                } label: {
                    if isRefreshingAll {
                        ProgressView()
                            .tint(AppColors.textMuted)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.success)
                    }
                }
                .disabled(isRefreshingAll)
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        let stats = imageStats
        return HStack(spacing: 16) {
            statPill(label: "Total", value: "\(stats.total)", color: AppColors.textMuted)
            statPill(label: "With Images", value: "\(stats.withImages)", color: .greenSecondary)
            statPill(label: "Cached", value: "\(stats.cached)", color: .purpleSecondary)
            statPill(label: "Organs", value: "\(stats.withOrgans)", color: .orangePrimary)

            if isRefreshingAll {
                Spacer()
                Text("\(refreshProgress)/\(refreshTotal)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.success)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(AppTypography.sectionHeader)
                .foregroundStyle(color)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted)
        }
    }

    // MARK: - Search & Filter

    private var searchAndFilter: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(AppColors.textMuted)

                TextField("Search species...", text: $searchText)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )

            // Filter chips
            HStack(spacing: 8) {
                ForEach(ImageFilterMode.allCases, id: \.rawValue) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            filterMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(AppTypography.tagText)
                            .foregroundStyle(filterMode == mode ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                filterMode == mode ?
                                AppColors.success : AppColors.cardElevated
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("\(filteredPlants.count) species")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Plant Image Row

    private func plantImageRow(_ plant: Plant) -> some View {
        HStack(spacing: 12) {
            // Thumbnail — cached first, then URL
            if let cachedImage = plant.cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 56)
                    default:
                        thumbnailPlaceholder
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                .frame(width: 56, height: 56)
            } else {
                thumbnailPlaceholder
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(plant.scientificName)
                    .font(AppTypography.fieldLabel)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(plant.titleCasedCommonName)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                // Organ image indicators
                HStack(spacing: 4) {
                    ForEach(PlantOrgan.imageOrgans) { organ in
                        let hasImage = plant.imageURL(for: organ) != nil
                        Image(systemName: organ.icon)
                            .font(AppTypography.inter(size: 9))
                            .foregroundStyle(hasImage ? organ.color : AppColors.textMuted.opacity(0.3))
                    }
                }
            }

            Spacer()

            // Counts
            let organCount = plant.organImages.count
            VStack(alignment: .trailing, spacing: 2) {
                if organCount > 0 {
                    Text("\(organCount)/\(PlantOrgan.imageOrgans.count)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.success)
                } else {
                    Text("No images")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
            }

            Image(systemName: "chevron.right")
                .font(AppTypography.inter(size: 11))
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: AppRadius.button)
            .fill(AppColors.cardElevated)
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: "leaf.fill")
                    .font(AppTypography.inter(size: 18))
                    .foregroundStyle(AppColors.success.opacity(0.2))
            }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(AppTypography.inter(size: 40))
                .foregroundStyle(AppColors.textMuted.opacity(0.5))
            Text("No species found")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Refresh All

    private func refreshAllImages() async {
        isRefreshingAll = true

        let plantsToRefresh: [Plant]
        switch filterMode {
        case .noImages:
            plantsToRefresh = allPlants.filter { $0.bestImageURL == nil }
        default:
            plantsToRefresh = allPlants.filter { $0.imageURL == nil }
        }

        refreshTotal = plantsToRefresh.count
        refreshProgress = 0

        let batchSize = 3
        for batchStart in stride(from: 0, to: plantsToRefresh.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, plantsToRefresh.count)
            let batch = Array(plantsToRefresh[batchStart..<batchEnd])

            await withTaskGroup(of: (Int, PlantImageResult).self) { group in
                for (index, plant) in batch.enumerated() {
                    group.addTask {
                        let result = await PlantImageService.shared.fetchAllImages(for: plant.scientificName)
                        return (index, result)
                    }
                }

                for await (index, result) in group {
                    let plant = batch[index]
                    if result.hasAnyImage {
                        plant.imageURL = result.generalImageURL
                        for (organ, url) in result.organImages {
                            plant.setImageURL(url, for: organ)
                        }
                    }
                }
            }

            try? modelContext.save()
            refreshProgress = batchEnd
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        isRefreshingAll = false
    }
}

// MARK: - Admin Plant Image Detail View

/// Detail view for managing a single plant's images by organ.
struct AdminPlantImageDetailView: View {
    @Bindable var plant: Plant
    @Environment(\.modelContext) private var modelContext
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero — best image
                heroSection

                // General image URL
                imageURLSection(title: "General Image", urlString: plant.imageURL)

                // Organ-specific images
                ForEach(PlantOrgan.imageOrgans) { organ in
                    organSection(organ: organ)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(AppColors.appBackground)
        .navigationTitle(plant.titleCasedCommonName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshImages() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .tint(AppColors.textMuted)
                            .scaleEffect(0.8)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Refresh")
                                .font(AppTypography.tagText)
                        }
                        .foregroundStyle(AppColors.success)
                    }
                }
                .disabled(isRefreshing)
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cachedImage = plant.cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                    default:
                        heroPlaceholder
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            } else {
                heroPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plant.scientificName)
                    .font(AppTypography.headerTitle)
                    .italic()
                    .foregroundStyle(AppColors.textPrimary)
                Text(plant.familyLatin)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
    }

    private var heroPlaceholder: some View {
        RoundedRectangle(cornerRadius: AppRadius.card)
            .fill(
                LinearGradient(
                    colors: [AppColors.success.opacity(0.15), AppColors.cardBackground],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(height: 180)
            .overlay {
                Image(systemName: "leaf.fill")
                    .font(AppTypography.inter(size: 50))
                    .foregroundStyle(AppColors.success.opacity(0.1))
            }
    }

    // MARK: - URL Section

    @ViewBuilder
    private func imageURLSection(title: String, urlString: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)

            if let urlString = urlString, !urlString.isEmpty {
                Text(urlString)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            } else {
                Text("No image")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted.opacity(0.5))
                    .italic()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Organ Section

    private func organSection(organ: PlantOrgan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: organ.icon)
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(organ.color)
                    .frame(width: 28, height: 28)
                    .background(organ.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                Text(organ.displayName)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if plant.imageURL(for: organ) != nil {
                    Button {
                        plant.setImageURL(nil, for: organ)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash")
                            .font(AppTypography.inter(size: 12))
                            .foregroundStyle(AppColors.error.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let urlString = plant.imageURL(for: organ), let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                    default:
                        organPlaceholder(organ: organ)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                Text(urlString)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                organPlaceholder(organ: organ)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func organPlaceholder(organ: PlantOrgan) -> some View {
        RoundedRectangle(cornerRadius: AppRadius.button)
            .fill(organ.color.opacity(0.05))
            .frame(height: 80)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: organ.icon)
                        .font(.title3)
                        .foregroundStyle(organ.color.opacity(0.2))
                    Text("No \(organ.displayName.lowercased()) image")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted.opacity(0.5))
                }
            }
    }

    // MARK: - Refresh

    private func refreshImages() async {
        isRefreshing = true
        await DataLoader.shared.refreshPlantImages(plant: plant, modelContext: modelContext)
        isRefreshing = false
    }
}

#Preview {
    NavigationStack {
        AdminPlantImagesView()
    }
    .modelContainer(for: Plant.self, inMemory: true)
}
