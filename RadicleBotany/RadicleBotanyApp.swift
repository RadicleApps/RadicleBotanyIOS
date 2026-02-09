import SwiftUI
import SwiftData

@main
struct RadicleBotanyApp: App {
    @StateObject private var storeManager = StoreManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Plant.self,
            Family.self,
            BotanyTerm.self,
            PlantObservation.self,
            Achievement.self,
            UserSettings.self
        ])

        // Ensure the Application Support directory exists before SwiftData tries to write
        let fileManager = FileManager.default
        let appSupportURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let appSupportURL = appSupportURLs.first {
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                do {
                    try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
                    print("[RadicleBotanyApp] Created Application Support directory at: \(appSupportURL.path)")
                } catch {
                    print("[RadicleBotanyApp] ⚠️ Failed to create Application Support dir: \(error)")
                }
            } else {
                print("[RadicleBotanyApp] Application Support directory exists at: \(appSupportURL.path)")
            }
        }

        // Also try the Documents directory as a fallback store location
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeURL = docsURL.appending(path: "RadicleBotany.store")
        print("[RadicleBotanyApp] Store URL: \(storeURL.path)")

        // Ensure Documents directory exists too
        if !fileManager.fileExists(atPath: docsURL.path) {
            try? fileManager.createDirectory(at: docsURL, withIntermediateDirectories: true)
            print("[RadicleBotanyApp] Created Documents directory")
        }

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[RadicleBotanyApp] ✅ ModelContainer created successfully")
            return container
        } catch {
            // If schema migration fails, delete the old store and retry
            print("[RadicleBotanyApp] ❌ ModelContainer failed: \(error). Deleting old store...")
            try? fileManager.removeItem(at: storeURL)
            // Also remove WAL/SHM files
            try? fileManager.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? fileManager.removeItem(at: storeURL.appendingPathExtension("shm"))
            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("[RadicleBotanyApp] ✅ ModelContainer created after reset")
                return container
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(storeManager)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

// Separate view so @Environment(\.modelContext) is available from .modelContainer
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: StoreManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var dataLoaded = false

    var body: some View {
        Group {
            if !dataLoaded {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("Loading RadicleBotany...")
                            .foregroundStyle(.white)
                        ProgressView()
                            .tint(.orange)
                    }
                }
            } else if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            print("[RootView] onAppear fired, loading data...")
            DataLoader.shared.loadAllDataIfNeeded(modelContext: modelContext)
            dataLoaded = true
            print("[RootView] dataLoaded set to true")
        }
    }
}
