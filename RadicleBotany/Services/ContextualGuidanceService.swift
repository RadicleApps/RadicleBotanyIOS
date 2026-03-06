import SwiftUI
import Combine

/// Monitors user navigation patterns and provides contextual hints
/// via subtle typewriter animations. Makes the app feel alive and anticipatory.
final class ContextualGuidanceService: ObservableObject {
    static let shared = ContextualGuidanceService()

    @Published private(set) var currentHint: ContextualHint?
    @Published private(set) var shouldShowHint = false

    // MARK: - Intelligence Strip State

    /// The active message shown in the Intelligence Strip.
    @Published private(set) var activeStripMessage: StripMessage?
    /// Whether the strip should be visible.
    @Published private(set) var shouldShowStrip = false

    /// Priority message queue — highest priority wins.
    private var stripQueue: [StripMessage] = []
    private var stripDismissWorkItem: DispatchWorkItem?

    // User pattern tracking
    private var visitCounts: [String: Int] = [:]
    private var lastVisitTimes: [String: Date] = [:]
    private var navigationSequence: [String] = []
    private var idleTimer: Timer?
    private var currentScreen: String?
    private var hintShowWorkItem: DispatchWorkItem?
    private var hintDismissWorkItem: DispatchWorkItem?

    private let storageKeyVisits = "radiclebotany_screen_visits"
    private let storageKeyLastVisit = "radiclebotany_last_visits"

    private init() {
        loadPatterns()
    }

    // MARK: - Public API

    func trackNavigation(to screen: String, context: NavigationContext = .normal) {
        currentScreen = screen
        visitCounts[screen, default: 0] += 1
        lastVisitTimes[screen] = Date()
        navigationSequence.append(screen)

        if navigationSequence.count > 10 {
            navigationSequence.removeFirst()
        }

        savePatterns()
        evaluateHint(for: screen, context: context)
        startIdleTimer()
    }

    func dismissCurrentHint() {
        hintShowWorkItem?.cancel()
        hintDismissWorkItem?.cancel()

        withAnimation(.easeOut(duration: 0.3)) {
            shouldShowHint = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentHint = nil
        }
    }

    func pause() {
        idleTimer?.invalidate()
    }

    func resume() {
        if currentScreen != nil {
            startIdleTimer()
        }
    }

    // MARK: - Intelligence Strip Public API

    /// Post a status message (loading, syncing, refreshing).
    func postStatus(_ message: String, color: HintColor = .action) {
        enqueueStripMessage(StripMessage(text: message, priority: .status, semanticColor: color, duration: 3.0))
    }

    /// Post a notification message (new content available).
    func postNotification(_ message: String, color: HintColor = .insight) {
        enqueueStripMessage(StripMessage(text: message, priority: .notification, semanticColor: color, duration: 4.0))
    }

    /// Post an urgent message.
    func postUrgent(_ message: String) {
        enqueueStripMessage(StripMessage(text: message, priority: .urgent, semanticColor: .success, duration: 5.0))
    }

    /// Dismiss the Intelligence Strip.
    func dismissStrip() {
        stripDismissWorkItem?.cancel()

        withAnimation(.easeOut(duration: 0.3)) {
            shouldShowStrip = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.activeStripMessage = nil
            self.advanceStripQueue()
        }
    }

    // MARK: - Strip Queue Management

    private func enqueueStripMessage(_ message: StripMessage) {
        // If higher priority than current, interrupt
        if let current = activeStripMessage {
            if message.priority > current.priority {
                stripDismissWorkItem?.cancel()
                stripQueue.insert(message, at: 0)
                showNextStripMessage()
                return
            }
        }

        // If nothing active, show immediately
        if activeStripMessage == nil || !shouldShowStrip {
            stripQueue.insert(message, at: 0)
            showNextStripMessage()
            return
        }

        // Otherwise queue it (sorted by priority descending)
        stripQueue.append(message)
        stripQueue.sort { $0.priority > $1.priority }
    }

    private func showNextStripMessage() {
        guard let message = stripQueue.first else {
            withAnimation(.easeOut(duration: 0.3)) {
                shouldShowStrip = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.activeStripMessage = nil
            }
            return
        }

        stripQueue.removeFirst()
        activeStripMessage = message

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            shouldShowStrip = true
        }

        // Schedule auto-dismiss
        stripDismissWorkItem?.cancel()
        let dismissWork = DispatchWorkItem { [weak self] in
            self?.dismissStrip()
        }
        stripDismissWorkItem = dismissWork
        DispatchQueue.main.asyncAfter(deadline: .now() + message.duration, execute: dismissWork)
    }

    private func advanceStripQueue() {
        if !stripQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showNextStripMessage()
            }
        }
    }

    // MARK: - Pattern Detection

    private func evaluateHint(for screen: String, context: NavigationContext) {
        let visitCount = visitCounts[screen] ?? 0
        let hint: ContextualHint?

        if visitCount == 1 {
            hint = firstVisitHint(for: screen)
        } else if context == .returned {
            hint = returningVisitHint(for: screen)
        } else if detectPattern() {
            hint = patternBasedHint(for: screen)
        } else {
            hint = nil
        }

        if let hint = hint {
            showHint(hint)
        }
    }

    private func firstVisitHint(for screen: String) -> ContextualHint? {
        switch screen {
        case "Journal":
            return ContextualHint(
                message: randomVariation([
                    "Your field journal. Every observation lives here.",
                    "Your botanical record. Browse and search.",
                    "Document, review, learn."
                ]),
                style: .subtle,
                delay: 0.8,
                color: .insight
            )
        case "Botanize":
            return ContextualHint(
                message: randomVariation([
                    "Point. Capture. Identify.",
                    "Three modes. One goal: identification.",
                    "Choose your approach."
                ]),
                style: .standard,
                delay: 0.5,
                color: .action
            )
        case "Learn":
            return ContextualHint(
                message: randomVariation([
                    "Botany at every level. Start anywhere.",
                    "Species, families, terminology.",
                    "Your botanical education center."
                ]),
                style: .subtle,
                delay: 0.6,
                color: .insight
            )
        case "FlashCards":
            return ContextualHint(
                message: randomVariation([
                    "Swipe right if you know it. Left to review.",
                    "Learn one card at a time.",
                    "Visual recall, rapid fire."
                ]),
                style: .standard,
                delay: 0.5,
                color: .action
            )
        case "BloomCalendar":
            return ContextualHint(
                message: randomVariation([
                    "Peak bloom seasons at a glance.",
                    "Plan your field excursions.",
                    "When to find what."
                ]),
                style: .subtle,
                delay: 0.7,
                color: .insight
            )
        case "Conservation":
            return ContextualHint(
                message: randomVariation([
                    "Species that need attention.",
                    "Conservation status matters.",
                    "Know what's at risk."
                ]),
                style: .subtle,
                delay: 0.7,
                color: .insight
            )
        case "PlantsNearMe":
            return ContextualHint(
                message: randomVariation([
                    "Local species based on your coordinates.",
                    "What grows around you.",
                    "Regional biodiversity."
                ]),
                style: .subtle,
                delay: 0.8,
                color: .insight
            )
        default:
            return nil
        }
    }

    private func randomVariation(_ messages: [String]) -> String {
        messages.randomElement() ?? messages.first ?? ""
    }

    private func returningVisitHint(for screen: String) -> ContextualHint? {
        guard let lastVisit = lastVisitTimes[screen] else { return nil }
        let hoursSince = Date().timeIntervalSince(lastVisit) / 3600

        if hoursSince > 24 {
            switch screen {
            case "Learn":
                return ContextualHint(
                    message: randomVariation([
                        "Ready when you are.",
                        "Pick up where you left off.",
                        "New study session."
                    ]),
                    style: .subtle,
                    delay: 1.0,
                    color: .insight
                )
            case "Journal":
                return ContextualHint(
                    message: randomVariation([
                        "Your collection awaits.",
                        "Review recent observations.",
                        "Field notes updated."
                    ]),
                    style: .subtle,
                    delay: 0.8,
                    color: .action
                )
            default:
                return nil
            }
        }
        return nil
    }

    private func patternBasedHint(for screen: String) -> ContextualHint? {
        // Repeated learning — suggest flash cards
        if navigationSequence.suffix(5).filter({ $0 == "Learn" || $0 == "Species" }).count >= 4 {
            return ContextualHint(
                message: randomVariation([
                    "Flash cards reinforce what you're studying.",
                    "Practice retention with quick review.",
                    "Turn study into recall."
                ]),
                style: .standard,
                delay: 1.2,
                color: .action
            )
        }

        return nil
    }

    private func detectPattern() -> Bool {
        guard navigationSequence.count >= 3 else { return false }
        let last3 = navigationSequence.suffix(3)
        return Set(last3).count == 1
    }

    // MARK: - Idle Detection

    private func startIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.handleIdle()
        }
    }

    private func handleIdle() {
        guard let screen = currentScreen else { return }

        let idleHint: ContextualHint?
        switch screen {
        case "Learn":
            idleHint = ContextualHint(
                message: randomVariation([
                    "Select any section to begin.",
                    "Tap to explore.",
                    "Start with what interests you."
                ]),
                style: .subtle,
                delay: 0.5,
                color: .action
            )
        case "Botanize":
            idleHint = ContextualHint(
                message: randomVariation([
                    "Choose a mode to begin.",
                    "Observe, Capture, or Both.",
                    "Ready to identify."
                ]),
                style: .subtle,
                delay: 0.5,
                color: .action
            )
        default:
            idleHint = nil
        }

        if let hint = idleHint {
            showHint(hint)
        }
    }

    // MARK: - Hint Display

    private func showHint(_ hint: ContextualHint) {
        hintShowWorkItem?.cancel()
        hintDismissWorkItem?.cancel()

        currentHint = hint

        let showWork = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.4)) {
                self?.shouldShowHint = true
            }
        }
        hintShowWorkItem = showWork
        DispatchQueue.main.asyncAfter(deadline: .now() + hint.delay, execute: showWork)

        let dismissWork = DispatchWorkItem {
            self.dismissCurrentHint()
        }
        hintDismissWorkItem = dismissWork
        DispatchQueue.main.asyncAfter(deadline: .now() + hint.delay + hint.holdDuration, execute: dismissWork)
    }

    // MARK: - Persistence

    private func savePatterns() {
        if let visitsData = try? JSONEncoder().encode(visitCounts) {
            UserDefaults.standard.set(visitsData, forKey: storageKeyVisits)
        }
        if let lastVisitData = try? JSONEncoder().encode(lastVisitTimes) {
            UserDefaults.standard.set(lastVisitData, forKey: storageKeyLastVisit)
        }
    }

    private func loadPatterns() {
        if let visitsData = UserDefaults.standard.data(forKey: storageKeyVisits),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: visitsData) {
            visitCounts = decoded
        }
        if let lastVisitData = UserDefaults.standard.data(forKey: storageKeyLastVisit),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: lastVisitData) {
            lastVisitTimes = decoded
        }
    }
}

// MARK: - Supporting Types

struct ContextualHint {
    let message: String
    let style: TypewriterStyle
    let delay: TimeInterval
    let holdDuration: TimeInterval
    let semanticColor: HintColor

    init(message: String, style: TypewriterStyle, delay: TimeInterval, holdDuration: TimeInterval = 4.0, color: HintColor = .insight) {
        self.message = message
        self.style = style
        self.delay = delay
        self.holdDuration = holdDuration
        self.semanticColor = color
    }
}

/// Semantic color system — users learn patterns through consistent color usage
enum HintColor {
    case action      // Orange — "do this next"
    case insight     // Purple — "here's why/how"
    case success     // Green — "you've achieved something"

    var color: Color {
        switch self {
        case .action: return AppColors.primaryAmber
        case .insight: return AppColors.brandPurple
        case .success: return AppColors.success
        }
    }
}

enum NavigationContext {
    case normal
    case returned
    case urgent
}

// MARK: - Intelligence Strip Types

enum StripMessagePriority: Int, Comparable {
    case ambient = 0       // Idle hints, returning-visit messages
    case contextual = 1    // First-visit hints, pattern-based suggestions
    case status = 2        // Loading, syncing, refreshing
    case notification = 3  // New content available
    case urgent = 4        // Critical alerts

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct StripMessage: Identifiable {
    let id = UUID()
    let text: String
    let priority: StripMessagePriority
    let semanticColor: HintColor
    let duration: TimeInterval
}
