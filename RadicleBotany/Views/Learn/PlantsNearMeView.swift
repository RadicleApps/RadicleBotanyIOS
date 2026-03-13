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
        GridItem(.flexible())
    ]

    // MARK: - Cached Fallback Data (computed once)

    @State private var cachedBloomingPlants: [Plant] = []
    @State private var cachedSuggestedPlants: [Plant] = []
    @State private var cachedMonthName: String = ""

    private func recomputeFallbackData() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        cachedBloomingPlants = plants.filter { $0.bloomMonthArray.contains(currentMonth) }
        cachedSuggestedPlants = Array(plants.shuffled().prefix(12))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        cachedMonthName = formatter.string(from: Date())
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
                        } else if isLoading || (!hasFetched && predictions.isEmpty && errorMessage == nil) {
                            loadingView
                        } else if !predictions.isEmpty {
                            dataSourcePill("Predicted Species", color: .orangePrimary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            statsBar
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            predictionGrid
                        } else if let msg = errorMessage {
                            // API error — show actual error and retry option
                            errorView(msg)
                                .padding(.horizontal, 24)
                        } else if hasFetched {
                            // API returned zero predictions — show informative empty state
                            noPredictionsView
                        } else if !cachedSuggestedPlants.isEmpty {
                            dataSourcePill("Suggested Species", color: .orangePrimary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            suggestedSection
                        } else {
                            emptyView
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
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
        .onAppear { if cachedBloomingPlants.isEmpty && !plants.isEmpty { recomputeFallbackData() } }
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
        LazyVGrid(columns: columns, spacing: 8) {
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

    /// All database-matched plants from predictions, sorted by score (for pager navigation).
    private var matchedPredictionPlants: [Plant] {
        let sorted = predictions.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        return sorted.compactMap { matchedPlant(for: $0) }
    }

    private func predictionCard(_ prediction: GeoPrediction) -> some View {
        let localPlant = matchedPlant(for: prediction)

        return Group {
            if let plant = localPlant {
                let matched = matchedPredictionPlants
                let index = matched.firstIndex(where: { $0.id == plant.id }) ?? 0
                NavigationLink(destination: CollectionPagerView(items: matched, startIndex: index) { p in
                    PlantDetailView(plant: p)
                }) {
                    predictionCardContent(prediction, isInDatabase: true, plant: plant)
                }
                .buttonStyle(NearMeCellButtonStyle())
            } else {
                predictionCardContent(prediction, isInDatabase: false, plant: nil)
            }
        }
    }

    private func predictionCardContent(_ prediction: GeoPrediction, isInDatabase: Bool, plant: Plant?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Common name
            Text(prediction.displayName.titleCased)
                .font(AppTypography.bodyText)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            // Scientific name
            Text(prediction.scientificName)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)

            // Bottom row: score
            HStack(spacing: 0) {
                if isInDatabase {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.inter(size: 9))
                        .foregroundStyle(AppColors.success)
                }

                Spacer(minLength: 4)

                if let score = prediction.score {
                    Text("\(Int(score * 100))%")
                        .font(AppTypography.inter(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(isInDatabase ? AppColors.success.opacity(0.3) : AppColors.border, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
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

    private var noPredictionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle")
                .font(AppTypography.inter(size: 48))
                .foregroundStyle(AppColors.textMuted)

            Text("No Predictions Available")
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            Text("Species prediction data isn't available for your current area. Try again later or explore plants using Observe or Capture mode.")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                hasFetched = false
                Task { await fetchPredictions() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(AppTypography.inter(size: 12))
                    Text("Retry")
                        .font(AppTypography.sectionHeader)
                }
                .foregroundStyle(AppColors.success)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
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

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cachedBloomingPlants) { plant in
                    localPlantCell(plant, showBloom: true)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Suggested Section (Tier 3)

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Common species to explore in the field")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cachedSuggestedPlants) { plant in
                    localPlantCell(plant, showBloom: false)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Local Plant Cell (Tier 2/3)

    private func localPlantCell(_ plant: Plant, showBloom: Bool, collection: [Plant]? = nil) -> some View {
        let items = collection ?? (showBloom ? cachedBloomingPlants : cachedSuggestedPlants)
        let index = items.firstIndex(where: { $0.id == plant.id }) ?? 0
        return NavigationLink(destination: CollectionPagerView(items: items, startIndex: index) { p in
            PlantDetailView(plant: p)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Common name
                Text(plant.titleCasedCommonName)
                    .font(AppTypography.bodyText)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                // Scientific name
                Text(plant.scientificName)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                // Bottom row
                HStack(spacing: 0) {
                    Text(plant.familyLatin)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if showBloom {
                        Text("BLOOMING")
                            .font(AppTypography.inter(size: 8, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.success.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
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
        } catch let geoError as PlantNetGeoError {
            errorMessage = geoError.errorDescription ?? "Could not load predictions."
            print("[PlantsNearMeView] geo error: \(geoError)")
        } catch {
            errorMessage = "Could not load predictions: \(error.localizedDescription)"
            print("[PlantsNearMeView] fetch error: \(error)")
        }

        hasFetched = true
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
