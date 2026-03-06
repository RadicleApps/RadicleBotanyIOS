import SwiftUI

/// RadicleBotany Chatbot — Botanical conversational assistant.
///
/// Design: Open, clean, no card boxes on messages.
/// - User messages: Right-aligned, amber pill
/// - Assistant messages: Left-aligned, no background — clean text on dark canvas
/// - Quick actions: Subtle bordered chips
/// - Mode indicator: Monospaced status line

struct ChatView: View {
    @ObservedObject private var chatbotService = ChatbotService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    let context: BotanyContext?

    init(context: BotanyContext? = nil) {
        self.context = context
    }

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Welcome area
                            if chatbotService.messages.isEmpty {
                                welcomeArea
                            }

                            // Chat messages
                            ForEach(chatbotService.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            // Processing indicator
                            if chatbotService.isProcessing {
                                processingIndicator
                            }

                            // Quick actions
                            if !isInputFocused && !chatbotService.isProcessing {
                                quickActionsRow
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: chatbotService.messages.count) { _ in
                        scrollToLatestMessage()
                    }
                }

                // Input bar
                inputBar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Mode indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(chatbotService.currentMode.isAIPowered ? AppColors.success : AppColors.primaryAmber)
                            .frame(width: 6, height: 6)

                        Text(modeLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.textMuted)
                    }

                    // Clear button
                    if !chatbotService.messages.isEmpty {
                        Button {
                            chatbotService.clearMessages()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(AppTypography.inter(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                }
            }
        }
        .onAppear {
            chatbotService.updateCapabilityMode()
        }
    }

    private var modeLabel: String {
        switch chatbotService.currentMode {
        case .aiPowered(let backend) where backend == "Enhanced":
            return "Enhanced"
        case .aiPowered(let backend):
            return backend
        case .localKnowledge:
            return "Local"
        }
    }

    // MARK: - Welcome Area

    private var welcomeArea: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            // Icon
            Image("Actinomorphic (symmetry) color")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
                .opacity(0.9)

            // Welcome text
            VStack(spacing: 8) {
                Text("Botanical Assistant")
                    .font(AppTypography.inter(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(getWelcomeSubtitle())
                    .font(AppTypography.inter(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Rate limit info for owner-backend users
            if chatbotService.currentMode.isAIPowered && IntelligenceBackendService.shared.isOwnerBackendActive {
                let remaining = RateLimitManager.shared.remainingQueries(tier: StoreManager.shared.userTier)
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(AppTypography.inter(size: 10))
                    Text("\(remaining) queries remaining today")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(AppColors.textMuted.opacity(0.5))
            }

            Spacer()
                .frame(height: 8)
        }
    }

    private func getWelcomeSubtitle() -> String {
        switch chatbotService.currentMode {
        case .aiPowered(let backend) where backend == "Enhanced":
            return "Powered by RadicleBotany. Ask anything about\nplant identification, morphology, or ecology."
        case .aiPowered:
            return "Enhanced responses active. Ask anything about\nplant identification, morphology, or ecology."
        case .localKnowledge:
            return "Pre-loaded with botanical knowledge.\nTap a question below or type your own."
        }
    }

    // MARK: - Processing Indicator

    private var processingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.textMuted.opacity(0.4))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if chatbotService.messages.isEmpty {
                Text("SUGGESTED")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.textMuted.opacity(0.5))
                    .kerning(1.5)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    let suggestions = chatbotService.getSuggestedActions(
                        for: context ?? ChatbotService.contextFor(screen: "Chat")
                    )

                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            sendQuickAction(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(AppTypography.inter(size: 13, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.chip)
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private func sendQuickAction(_ text: String) {
        messageText = text
        sendMessage()
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Subtle top separator
            Rectangle()
                .fill(AppColors.border.opacity(0.3))
                .frame(height: 0.5)

            HStack(spacing: 10) {
                // Text field
                TextField("Ask about plants...", text: $messageText)
                    .textFieldStyle(.plain)
                    .font(AppTypography.inter(size: 15, weight: .regular))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(AppColors.cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(AppTypography.inter(size: 14, weight: .semibold))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textMuted.opacity(0.3) : .white)
                        .frame(width: 34, height: 34)
                        .background(
                            messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AppColors.cardBackground.opacity(0.5)
                                : AppColors.primaryAmber
                        )
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.vertical, 10)
        }
        .background(AppColors.appBackground)
    }

    // MARK: - Actions

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 500 else { return }

        messageText = ""
        isInputFocused = false

        Task {
            await chatbotService.sendMessage(trimmed, context: context)
        }
    }

    private func scrollToLatestMessage() {
        guard let lastMessage = chatbotService.messages.last else { return }
        // For assistant responses, scroll to the TOP of the message so the user
        // can read from the beginning instead of being dropped at the bottom
        let anchor: UnitPoint = lastMessage.sender == .assistant ? .top : .bottom
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(lastMessage.id, anchor: anchor)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @State private var referencesExpanded = false

    private func attributedContent(from markdown: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        } catch {
            return AttributedString(markdown)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.sender == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 6) {
                if message.sender == .assistant {
                    // Assistant: clean text, no background
                    Text(attributedContent(from: message.content))
                        .font(AppTypography.inter(size: 14.5, weight: .regular))
                        .foregroundColor(AppColors.textPrimary)
                        .lineSpacing(4)
                        .textSelection(.enabled)

                    // References — source attribution
                    if !message.references.isEmpty {
                        referenceBar
                    }
                } else {
                    // User: amber pill
                    Text(message.content)
                        .font(AppTypography.inter(size: 14.5, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.primaryAmber)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                }

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppColors.textMuted.opacity(0.5))
            }
            .frame(
                maxWidth: UIScreen.main.bounds.width * 0.78,
                alignment: message.sender == .user ? .trailing : .leading
            )

            if message.sender == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Reference Bar

    /// Collapsible source attribution — tap to expand full reference list
    private var referenceBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    referencesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(AppTypography.inter(size: 9, weight: .semibold))

                    Text("SOURCES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .kerning(1.2)

                    Text("(\(message.references.count))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))

                    Spacer()

                    Image(systemName: referencesExpanded ? "chevron.up" : "chevron.down")
                        .font(AppTypography.inter(size: 8, weight: .semibold))
                }
                .foregroundColor(AppColors.textMuted.opacity(0.6))
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expanded reference list
            if referencesExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.references) { ref in
                        ReferenceChip(reference: ref)
                    }
                }
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Reference Chip

/// Individual source reference — icon + title, tappable if URL exists
struct ReferenceChip: View {
    let reference: ContentReference

    var body: some View {
        Group {
            if let urlString = reference.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    chipContent
                }
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        HStack(spacing: 6) {
            // Type icon
            Image(systemName: reference.icon)
                .font(AppTypography.inter(size: 9, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 14)

            // Title
            Text(reference.title)
                .font(AppTypography.inter(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)

            // Detail (citation number, etc.)
            if let detail = reference.detail {
                Text("· \(detail)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(AppColors.textMuted.opacity(0.5))
                    .lineLimit(1)
            }

            // Link indicator
            if reference.url != nil {
                Image(systemName: "arrow.up.right")
                    .font(AppTypography.inter(size: 7, weight: .bold))
                    .foregroundColor(AppColors.textMuted.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.cardBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }

    private var iconColor: Color {
        switch reference.type {
        case .species: return AppColors.success              // Green — species
        case .family: return AppColors.primaryAmber             // Primary — taxonomy
        case .term: return AppColors.primaryAmber              // Primary — terminology
        case .article: return AppColors.primaryAmber          // Amber — external
        case .faq: return AppColors.textMuted                 // Muted — local knowledge
        }
    }
}
