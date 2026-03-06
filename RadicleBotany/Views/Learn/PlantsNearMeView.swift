import SwiftUI
import SwiftData
import CoreLocation

struct PlantsNearMeView: View {
    @EnvironmentObject var storeManager: StoreManager
    @ObservedObject private var locationManager = LocationManager.shared
    @Query(sort: \Plant.scientificName) private var plants: [Plant]

    @State private var predictions: [GeoPrediction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasFetched = false
    @State private var showMap = false
    @State private var dataSource: DataSource = .predictions

    private enum DataSource {
        case predictions
        case bloom
        case suggested
    }

    private let columns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5)
    ]

    // MARK: - Bloom Fallback (Tier 2)

    private var bloomingPlants: [Plant] {
        let currentMonth = Calendar.current.component(.month, from: Date())
        return plants.filter { plant in
            guard let months = plant.bloomMonths, !months.isEmpty else { return false }
            let monthArray = months.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return monthArray.contains(currentMonth)
        }
    }

    // MARK: - Suggested Fallback (Tier 3)

    private var suggestedPlants: [Plant] {
        // Free species first (most common/recognizable), then alphabetical
        let free = plants.filter { $0.isFree }.prefix(12)
        return Array(free)
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    var body: some View {
        Group {
            if showMap && !predictions.isEmpty, let bbox = locationManager.boundingBox(radiusKm: 25) {
                RegionMapView(
                    boundingBox: bbox,
                    predictionCount: predictions.count,
                    databaseMatchCount: predictions.filter { matchedPlant(for: $0) != nil }.count,
                    topSpecies: predictions.prefix(5).map { $0.scientificName }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !isAuthorized {
                            locationPermissionCard
                                .padding(.horizontal, 16)
                        } else if isLoading || (!hasFetched && predictions.isEmpty) {
                            loadingView
                        } else if let error = errorMessage, predictions.isEmpty {
                            errorView(error)
                        } else if !predictions.isEmpty {
                            dataSourcePill("Predicted Species", color: .orangePrimary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            statsBar
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            predictionGrid
                        } else if !bloomingPlants.isEmpty {
                            dataSourcePill("In Bloom — \(currentMonthName)", color: .orangePrimary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            bloomSection
                        } else if !suggestedPlants.isEmpty {
                            dataSourcePill("Suggested Species", color: .orangePrimary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            suggestedSection
                        } else {
                            emptyView
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Plants Near Me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                InfoButton(guide: .plantsNearMe, style: .toolbar)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !predictions.isEmpty {
                    Button {
                        withAnimation { showMap.toggle() }
                    } label: {
                        Image(systemName: showMap ? "square.grid.2x2" : "map")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.primaryAmber)
                    }
                }
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if newLocation != nil && !hasFetched {
                Task { await fetchPredictions() }
            }
        }
        .task {
            if !hasFetched {
                locationManager.requestLocation()
            }
        }
    }

    private var isAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        let inDB = predictions.filter { matchedPlant(for: $0) != nil }.count
        return HStack(spacing: 12) {
            statPill(icon: "leaf.fill", text: "\(predictions.count) predicted", color: .orangePrimary)
            statPill(icon: "checkmark.circle.fill", text: "\(inDB) in database", color: .orangePrimary)
        }
    }

    private func statPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 10))
            Text(text)
                .font(AppTypography.tagText)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Prediction Grid

    private var predictionGrid: some View {
        LazyVGrid(columns: columns, spacing: 1.5) {
            // Database matches first, then others — both sorted by score
            let sorted = predictions.sorted { a, b in
                let aInDB = matchedPlant(for: a) != nil
                let bInDB = matchedPlant(for: b) != nil
                if aInDB != bInDB { return aInDB }
                return (a.score ?? 0) > (b.score ?? 0)
            }

            ForEach(sorted) { prediction in
                predictionCard(prediction)
            }
        }
    }

    private func predictionCard(_ prediction: GeoPrediction) -> some View {
        let localPlant = matchedPlant(for: prediction)

        return Group {
            if let plant = localPlant {
                NavigationLink(destination: PlantDetailView(plant: plant)) {
                    predictionCardContent(prediction, isInDatabase: true, plant: plant)
                }
                .buttonStyle(NearMeCellButtonStyle())
            } else {
                predictionCardContent(prediction, isInDatabase: false, plant: nil)
            }
        }
    }

    private func predictionCardContent(_ prediction: GeoPrediction, isInDatabase: Bool, plant: Plant?) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if let plant = plant, let cachedImage = plant.cachedImage {
                    // Priority 1: Persistent cached image from matched database plant
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else if let imageURL = plant?.bestImageURL ?? prediction.bestImageURL,
                          let url = URL(string: imageURL) {
                    // Priority 2: URL-based image
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.width)
                                .clipped()
                        default:
                            gridCellPlaceholder(size: geo.size.width)
                        }
                    }
                } else {
                    gridCellPlaceholder(size: geo.size.width)
                }

                // Bottom label overlay
                VStack(spacing: 2) {
                    Text(prediction.displayName)
                        .font(AppTypography.tagText)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(prediction.scientificName)
                        .font(.system(size: 10, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    if isInDatabase {
                        Text("IN DATABASE")
                            .font(AppTypography.inter(size: 8, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .padding(.top, 1)
                    }
                }
                .frame(width: geo.size.width, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
    }

    private func gridCellPlaceholder(size: CGFloat) -> some View {
        AppColors.cardElevated
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "location.fill")
                    .font(AppTypography.inter(size: 28))
                    .foregroundStyle(AppColors.success.opacity(0.2))
            }
    }

    // MARK: - Permission Card

    private var locationPermissionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle.fill")
                .font(AppTypography.inter(size: 48))
                .foregroundStyle(AppColors.success)

            Text("Enable Location")
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            Text("Allow location access to discover plant species predicted to grow in your area based on environmental data.")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                locationManager.requestLocationPermission()
            } label: {
                Text("Allow Location Access")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.success)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppColors.success)
            Text("Finding plants near you...")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppTypography.displayLarge)
                .foregroundStyle(AppColors.warning)

            Text(message)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await fetchPredictions() }
            }
            .font(AppTypography.sectionHeader)
            .foregroundStyle(AppColors.success)
        }
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.circle")
                .font(AppTypography.inter(size: 40))
                .foregroundStyle(AppColors.textMuted)

            Text("No species data available")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data Source Pill

    private func dataSourcePill(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(AppTypography.tagText)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Bloom Section (Tier 2)

    private var bloomSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plants that may be blooming near you this month")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 1.5) {
                ForEach(bloomingPlants) { plant in
                    localPlantCell(plant, showBloom: true)
                }
            }
        }
    }

    // MARK: - Suggested Section (Tier 3)

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Common species to explore in the field")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 1.5) {
                ForEach(suggestedPlants) { plant in
                    localPlantCell(plant, showBloom: false)
                }
            }
        }
    }

    // MARK: - Local Plant Cell (Tier 2/3)

    private func localPlantCell(_ plant: Plant, showBloom: Bool) -> some View {
        NavigationLink(destination: PlantDetailView(plant: plant)) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Cached first, then URL fallback
                    CachedPlantGridImage(plant: plant, size: geo.size.width)

                    // Bottom label overlay
                    VStack(spacing: 2) {
                        Text(plant.commonName)
                            .font(AppTypography.tagText)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(plant.scientificName)
                            .font(.system(size: 10, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)

                        if showBloom {
                            Text("BLOOMING NOW")
                                .font(AppTypography.inter(size: 8, weight: .bold))
                                .foregroundStyle(AppColors.success)
                                .padding(.top, 1)
                        }
                    }
                    .frame(width: geo.size.width, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(width: geo.size.width, height: geo.size.width)
            }
            .aspectRatio(1.0, contentMode: .fit)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(NearMeCellButtonStyle())
    }

    // MARK: - Logic

    private func fetchPredictions() async {
        guard let bbox = locationManager.boundingBox(radiusKm: 25) else {
            errorMessage = "Unable to determine your location."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let results = try await PlantNetGeoService.shared.fetchPredictedSpecies(
                minLat: bbox.minLat,
                maxLat: bbox.maxLat,
                minLon: bbox.minLon,
                maxLon: bbox.maxLon
            )
            predictions = results
            hasFetched = true
        } catch {
            errorMessage = "Failed to load predictions: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func matchedPlant(for prediction: GeoPrediction) -> Plant? {
        plants.first { $0.scientificName.lowercased() == prediction.scientificName.lowercased() }
    }
}

// MARK: - Cell Press Style

private struct NearMeCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
