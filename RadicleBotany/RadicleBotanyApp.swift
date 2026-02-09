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

        // Use in-memory storage to bypass filesystem/permissions issues on MacInCloud
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[RadicleBotanyApp] ✅ ModelContainer created (in-memory)")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
