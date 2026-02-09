import SwiftUI
import SwiftData

struct JourneyView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @State private var observations: [PlantObservation] = []
    @State private var userSettingsResults: [UserSettings] = []

    @State private var showPaywall = false

    private var userSettings: UserSettings? {
        userSettingsResults.first
    }

    private var streakCount: Int {
        userSettings?.streakCount ?? 0
    }

    private var mostRecentObservation: PlantObservation? {
        observations.first
    }

    private var earlierObservations: [PlantObservation] {
        Array(observations.dropFirst().prefix(10))
    }

    var body: some View {
        ScrollView {
            if storeManager.userTier == .free {
                freeUserTeaser
            } else {
                paidUserContent
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Journey")
        .navigationDestination(for: PlantObservation.self) { observation in
            ObservationDetailView(observation: observation)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeManager)
        }
        .onAppear { loadData() }
    }

    // MARK: - Free User Teaser

    private var freeUserTeaser: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.orangePrimary.opacity(0.15))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.orangePrimary.opacity(0.08))
                    .frame(width: 160, height: 160)

                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.orangePrimary)
            }

            VStack(spacing: 8) {
                Text("Your Botanical Journey")
                    .font(AppFont.title())
                    .foregroundStyle(Color.textPrimary)

                Text("Track observations, build collections, and watch your botanical knowledge grow over time.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                journeyFeatureRow(icon: "camera.fill", text: "Log plant observations with photos")
                journeyFeatureRow(icon: "folder.fill", text: "Organize into custom collections")
                journeyFeatureRow(icon: "flame.fill", text: "Build learning streaks")
                journeyFeatureRow(icon: "trophy.fill", text: "Earn achievements as you explore")
            }
            .padding(.horizontal, 24)

            Button {
                showPaywall = true
            } label: {
                Text("Unlock with Lifetime")
            }
            .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
            .padding(.horizontal, 24)

            Button {
                showPaywall = true
            } label: {
                Text("View All Plans")
            }
            .buttonStyle(GhostButtonStyle(color: .textSecondary))

            Spacer()
                .frame(height: 40)
        }
    }

    private func journeyFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.orangePrimary)
                .frame(width: 28, height: 28)
                .background(Color.orangePrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)

            Spacer()
        }
    }

    // MARK: - Paid User Content

    private var paidUserContent: some View {
        VStack(spacing: 20) {
            statsHeader
            heroObservationCard
            earlierObservationsSection
            collectionsSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if streakCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.orangePrimary)
                        Text("\(streakCount) day streak")
                            .font(AppFont.sectionHeader())
                            .foregroundStyle(Color.textPrimary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.orangePrimary)
                        Text("Start your journey")
                            .font(AppFont.sectionHeader())
                            .foregroundStyle(Color.textPrimary)
                    }
                }

                Text("\(observations.count) observation\(observations.count == 1 ? "" : "s") total")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Hero Observation Card

    @ViewBuilder
    private var heroObservationCard: some View {
        if let observation = mostRecentObservation {
            VStack(alignment: .leading, spacing: 0) {
                Text("LATEST OBSERVATION")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
                    .padding(.bottom, 10)

                NavigationLink(value: observation) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let photoData = observation.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 12,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 12
                                    )
                                )
                        } else {
                            ZStack {
                                Color.surfaceElevated
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 12,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 12
                                )
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(observation.plantScientificName ?? "Unidentified")
                                .font(AppFont.sectionHeader(16))
                                .foregroundStyle(Color.textPrimary)
                                .italic(observation.plantScientificName != nil)

                            Text(observation.date.formatted(date: .abbreviated, time: .shortened))
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)

                            if let lat = observation.latitude, let lon = observation.longitude {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 10))
                                    Text(String(format: "%.4f, %.4f", lat, lon))
                                        .font(AppFont.caption())
                                }
                                .foregroundStyle(Color.textMuted)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surface)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 12,
                                bottomTrailingRadius: 12,
                                topTrailingRadius: 0
                            )
                        )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.borderSubtle, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.textMuted)

                Text("No observations yet")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textSecondary)

                Text("Head to Botanize to capture your first plant observation.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .cardStyle()
        }
    }

    // MARK: - Earlier Observations

    @ViewBuilder
    private var earlierObservationsSection: some View {
        if earlierObservations.count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Earlier Observations")
                        .font(AppFont.sectionHeader())
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    NavigationLink {
                        ObservationsListView()
                    } label: {
                        Text("See All")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.orangePrimary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(earlierObservations) { observation in
                            NavigationLink(value: observation) {
                                earlierObservationCard(observation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func earlierObservationCard(_ observation: PlantObservation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let photoData = observation.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 100)
                    .clipped()
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 10,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 10
                        )
                    )
            } else {
                ZStack {
                    Color.surfaceElevated
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.textMuted)
                }
                .frame(width: 140, height: 100)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 10,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 10
                    )
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(observation.plantScientificName ?? "Unidentified")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(observation.date.formatted(date: .abbreviated, time: .omitted))
                    .font(AppFont.caption(10))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(8)
            .frame(width: 140, alignment: .leading)
            .background(Color.surface)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 10,
                    topTrailingRadius: 0
                )
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Collections Section

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collections")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 8) {
                collectionRow(icon: "heart.fill", name: "Favorites", color: .errorRed)
                collectionRow(icon: "leaf.fill", name: "By Family", color: .greenSecondary)
                collectionRow(icon: "folder.fill", name: "Custom", color: .purpleSecondary)
            }

            Button {
                // Placeholder for new collection creation
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("New Collection")
                        .font(AppFont.sectionHeader())
                }
            }
            .buttonStyle(SecondaryButtonStyle(color: .purpleSecondary))
        }
    }

    private func collectionRow(icon: String, name: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(name)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.textMuted)
        }
        .cardStyle(padding: 12)
    }

    private func loadData() {
        observations = (try? modelContext.fetch(FetchDescriptor<PlantObservation>(sortBy: [SortDescriptor(\PlantObservation.date, order: .reverse)]))) ?? []
        userSettingsResults = (try? modelContext.fetch(FetchDescriptor<UserSettings>())) ?? []
    }
}

#Preview {
    NavigationStack {
        JourneyView()
            .environmentObject(StoreManager())
            .modelContainer(for: [PlantObservation.self, UserSettings.self], inMemory: true)
    }
}
