import SwiftUI
import SwiftData

@main
struct RadicleBotanyApp: App {
    init() {
        // Configure generous URL cache for plant images across 2,311 species.
        // AsyncImage uses URLSession.shared which respects URLCache.shared,
        // so images persist on disk across app launches without needing to
        // bulk-download everything on first launch.
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,  // 100 MB in-memory
            diskCapacity: 500 * 1024 * 1024      // 500 MB on-disk
        )

        // Register Inter 18pt fonts from asset catalog
        FontRegistration.registerInter()

        let palette = ThemeManager.shared.palette
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = palette.uiAppBackground
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont(name: "Inter18pt-SemiBold", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont(name: "Inter18pt-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = palette.uiCardBackground
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    @StateObject private var storeManager: StoreManager = {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return StoreManager(preview: true)
        }
        return StoreManager()
    }()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var navigationState = AppNavigationState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Plant.self,
            Family.self,
            BotanyTerm.self,
            PlantObservation.self,
            Achievement.self,
            UserSettings.self,
            FlashcardProgress.self,
            JournalNote.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[RadicleBotanyApp] ✅ ModelContainer created (persistent)")
            return container
        } catch {
            // If the persistent store is corrupted or has a schema mismatch,
            // delete it and try again with a fresh store.
            print("[RadicleBotanyApp] ⚠️ ModelContainer failed: \(error)")
            print("[RadicleBotanyApp] Attempting to delete and recreate store...")

            // Delete existing store files from default location
            let storeURL = modelConfiguration.url
            let fileManager = FileManager.default
            let storePath = storeURL.path()
            for suffix in ["", "-shm", "-wal"] {
                let fullPath = storePath + suffix
                try? fileManager.removeItem(atPath: fullPath)
            }
            print("[RadicleBotanyApp] Deleted old store files at: \(storePath)")

            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("[RadicleBotanyApp] ✅ ModelContainer recreated successfully")
                return container
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(storeManager)
                .environmentObject(navigationState)
                .preferredColorScheme(.dark)
                .tint(AppColors.primaryAmber)
                .environmentObject(themeManager)
                .onAppear {
                    storeManager.becomeShared()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// Separate view so @Environment(\.modelContext) is available from .modelContainer.
// Data is loaded here using the environment modelContext (container.mainContext),
// which is the SAME context that @Query in all child views observes.
//
// Key fix: We gate the entire UI behind `isDataReady`. The child views
// (MainTabView → LearnView) are NOT created until data has been inserted
// into the context and saved. This guarantees @Query sees data immediately.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: StoreManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isDataReady = false

    var body: some View {
        Group {
            if isDataReady {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                // Splash / loading state — matches app background so it's seamless
                AppColors.appBackground
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                            ProgressView()
                                .tint(AppColors.textMuted)
                        }
                    }
            }
        }
        .task {
            // Load data into the environment's modelContext BEFORE showing any UI.
            // This is the same context that @Query in all child views observes.
            DataLoader.shared.loadAllDataIfNeeded(modelContext: modelContext)

            // Verify data was loaded
            let plantCount = (try? modelContext.fetchCount(FetchDescriptor<Plant>())) ?? 0
            let termCount = (try? modelContext.fetchCount(FetchDescriptor<BotanyTerm>())) ?? 0
            let familyCount = (try? modelContext.fetchCount(FetchDescriptor<Family>())) ?? 0
            print("[RootView] Data ready — Plants: \(plantCount), Families: \(familyCount), Terms: \(termCount)")

            // Now show the real UI — @Query in child views will see the data
            isDataReady = true

            // Background enrichment: IUCN status, common names, GBIF IDs.
            // Fire and forget — doesn't block the UI or image loading.
            // Runs incrementally so partial results are available quickly.
            Task {
                await DataLoader.shared.loadSpeciesEnrichment(modelContext: modelContext)
            }

            // Image URLs are pre-baked in Plants.json from iNaturalist.
            // AsyncImage loads them on-demand with URLCache (500MB disk) for persistence.
            // Only fetch images for the rare species not covered by the pre-baked data.
            await DataLoader.shared.loadPlantImages(modelContext: modelContext)

            // NOTE: cacheAllPlantImages() removed from launch sequence.
            // Images are cached lazily: URLCache persists AsyncImage downloads,
            // and PlantDetailView caches individual plants to SwiftData for offline.
        }
    }
}
