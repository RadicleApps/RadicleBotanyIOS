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
            Observation.self,
            Achievement.self,
            UserSettings.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(storeManager)
            .preferredColorScheme(.dark)
            .onAppear {
                loadDataIfNeeded()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func loadDataIfNeeded() {
        let context = sharedModelContainer.mainContext
        DataLoader.shared.loadAllDataIfNeeded(modelContext: context)
    }
}
