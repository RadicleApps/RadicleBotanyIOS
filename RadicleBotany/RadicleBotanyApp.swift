import SwiftUI
import SwiftData

@main
struct RadicleBotanyApp: App {
    @StateObject private var storeManager = StoreManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var dataLoaded = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Plant.self,
            Family.self,
            BotanyTerm.self,
            PlantObservation.self,
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
                if !dataLoaded {
                    // Show loading while data imports
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
            .environmentObject(storeManager)
            .preferredColorScheme(.dark)
            .onAppear {
                let context = sharedModelContainer.mainContext
                DataLoader.shared.loadAllDataIfNeeded(modelContext: context)
                dataLoaded = true
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
