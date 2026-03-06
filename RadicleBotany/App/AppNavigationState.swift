import Foundation

/// Shared navigation state for coordinating global search, profile,
/// chatbot, and deep links across all tabs.
/// Injected as an EnvironmentObject from RadicleBotanyApp.
class AppNavigationState: ObservableObject {
    @Published var showSearch = false
    @Published var showProfile = false
    @Published var showChatbot = false
    @Published var chatbotContext: BotanyContext?
}
