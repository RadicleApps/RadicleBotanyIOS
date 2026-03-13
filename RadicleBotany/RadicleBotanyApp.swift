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

        // Register Inter 18pt fonts (UI / body) and Cormorant Garamond (display / titles)
        FontRegistration.registerInter()
        FontRegistration.registerCormorant()

        let palette = ThemeManager.shared.palette
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = palette.uiAppBackground
        // Inline navigation title — Cormorant Garamond Bold (used by destination screens)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont(name: "CormorantGaramond-Bold", size: 20)
                ?? UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        // Large title — Cormorant Garamond Bold (used when largeTitle display mode is active)
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont(name: "CormorantGaramond-Bold", size: 38)
                ?? UIFont.systemFont(ofSize: 34, weight: .bold)
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

            // Show the UI IMMEDIATELY — don't block on anything else.
            isDataReady = true

            // ALL background work below uses a SEPARATE modelContext so saves
            // don't trigger @Query re-evaluations and UI hitching on the main thread.
            let container = modelContext.container

            // Load pre-bundled plant images (240px) on a BACKGROUND context (not main thread).
            // This avoids blocking the UI with synchronous file I/O for 2,327 images.
            // Images upgrade from thumbnails (75px) to small (240px) bundled images.
            Task.detached(priority: .utility) {
                let bgContext = ModelContext(container)
                bgContext.autosaveEnabled = false
                DataLoader.shared.loadBundledPlantImages(modelContext: bgContext)
            }

            // AFTER UI is visible: warm up NSCache with images already on disk (URLCache).
            // Only warm the first 50 images — enough for the initial grid screen.
            let warmUpDescriptor = FetchDescriptor<Plant>(
                sortBy: [SortDescriptor(\Plant.scientificName)]
            )
            let warmUpPlants = (try? modelContext.fetch(warmUpDescriptor)) ?? []
            let warmUpURLs = warmUpPlants
                .prefix(50)
                .compactMap { $0.bestImageURL }
                .compactMap { URL(string: $0) }

            Task.detached(priority: .utility) {
                await ThrottledImageLoader.shared.warmUpCache(urls: warmUpURLs)
            }

            // DISABLED: loadSpeciesEnrichment was making individual PlantNet API calls
            // for every unenriched species (~2,327 calls in batches of 5). This hammers
            // the network at launch and slows everything down. IUCN status, GBIF IDs,
            // and alt common names should be pre-baked into Plants.json at build time
            // (like we did for image URLs) rather than fetched at runtime.
            // Task.detached(priority: .background) {
            //     let bgContext = ModelContext(container)
            //     bgContext.autosaveEnabled = false
            //     await DataLoader.shared.loadSpeciesEnrichment(modelContext: bgContext)
            // }

            // DISABLED: loadPlantImages was fetching image URLs from iNaturalist/GBIF/Wikipedia
            // for ~59 species missing pre-baked URLs. Now redundant because all 2,268 species
            // have bundled 240px images in PlantImages/ loaded by loadBundledPlantImages above.
            // Task.detached(priority: .background) {
            //     let bgContext = ModelContext(container)
            //     bgContext.autosaveEnabled = false
            //     await DataLoader.shared.loadPlantImages(modelContext: bgContext)
            // }

            // DISABLED: cacheAllPlantImages was downloading ALL 2,327 images to SwiftData
            // in the background. Even with batch limits, the SwiftData writes cause
            // cross-context change notifications that trigger @Query re-evaluations,
            // freezing the UI during scrolling. Images are already cached in URLCache
            // (500MB disk) via ThrottledImageLoader — no need for SwiftData duplication.
        }
    }
}
