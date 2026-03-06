import SwiftUI

/// Word-by-word text reveal with punctuation cadence.
///
/// Use sparingly:
///   - Onboarding (first impression only)
///   - System status lines (loading, initialization)
///   - NOT on forms, NOT on repeated views, NOT on functional screens

struct TypewriterText: View {
    let fullText: String
    let style: TypewriterStyle

    @State private var visibleWordCount = 0
    @State private var opacity: Double = 0
    @State private var isComplete = false

    var onComplete: (() -> Void)?

    private var words: [WordUnit] {
        parseWords(fullText)
    }

    init(
        _ text: String,
        style: TypewriterStyle = .standard,
        onComplete: (() -> Void)? = nil
    ) {
        self.fullText = text
        self.style = style
        self.onComplete = onComplete
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<words.count, id: \.self) { index in
                Text(words[index].text)
                    .font(style.font)
                    .foregroundColor(style.color)
                    .opacity(index < visibleWordCount ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: visibleWordCount)
            }

            // Block cursor — fades on completion
            Text("\u{2588}")
                .font(style.font)
                .foregroundColor(style.cursorColor)
                .opacity(isComplete ? 0 : 0.8)
                .animation(.easeOut(duration: 0.4), value: isComplete)
        }
        .lineSpacing(style.lineSpacing)
        .opacity(opacity)
    }

    func startTyping() -> some View {
        self.onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                opacity = 1
            }
            revealNextWord()
        }
    }

    private func revealNextWord() {
        guard visibleWordCount < words.count else {
            isComplete = true
            onComplete?()
            return
        }

        let word = words[visibleWordCount]
        visibleWordCount += 1

        let delay = delayForWord(word)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            revealNextWord()
        }
    }

    private func delayForWord(_ word: WordUnit) -> TimeInterval {
        let base = style.baseSpeed

        guard let lastChar = word.text.trimmingCharacters(in: .whitespaces).last else {
            return base
        }

        switch lastChar {
        case ".":
            return base * 3.5
        case "!":
            return base * 3.0
        case "?":
            return base * 4.0
        case ",":
            return base * 2.0
        case ":":
            return base * 2.5
        case ";":
            return base * 2.2
        case "\u{2014}", "\u{2013}": // em dash, en dash
            return base * 4.5
        default:
            return base
        }
    }
}

// MARK: - Word Parsing

private struct WordUnit {
    let text: String
}

private func parseWords(_ text: String) -> [WordUnit] {
    var units: [WordUnit] = []
    var current = ""

    for char in text {
        current += String(char)
        if char == " " || char == "\n" {
            units.append(WordUnit(text: current))
            current = ""
        }
    }
    if !current.isEmpty {
        units.append(WordUnit(text: current))
    }

    return units
}

// MARK: - Typewriter Styles

enum TypewriterStyle {
    case standard       // Body text — steady, authoritative
    case heroTitle      // Large display — slightly slower for weight
    case systemMessage  // Monospaced — machine precision
    case subtle         // Small text — quick and light

    var font: Font {
        switch self {
        case .standard: return AppTypography.bodyText
        case .heroTitle: return AppTypography.displayLarge
        case .systemMessage: return AppTypography.dataValue
        case .subtle: return AppTypography.fieldLabel
        }
    }

    var color: Color {
        switch self {
        case .standard: return AppColors.textPrimary
        case .heroTitle: return AppColors.textPrimary
        case .systemMessage: return AppColors.primaryAmber
        case .subtle: return AppColors.textSecondary
        }
    }

    var cursorColor: Color {
        switch self {
        case .standard: return AppColors.primaryAmber
        case .heroTitle: return AppColors.primaryAmber
        case .systemMessage: return AppColors.primaryAmber.opacity(0.6)
        case .subtle: return AppColors.textMuted
        }
    }

    var baseSpeed: TimeInterval {
        switch self {
        case .standard: return 0.08
        case .heroTitle: return 0.12
        case .systemMessage: return 0.05
        case .subtle: return 0.06
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .standard: return 4
        case .heroTitle: return 6
        case .systemMessage: return 3
        case .subtle: return 2
        }
    }
}

// MARK: - Convenience

extension TypewriterText {
    func animated() -> some View {
        self.startTyping()
    }
}

// MARK: - Agentic Status Line

struct AgenticStatusLine: View {
    let messages: [String]
    var onComplete: (() -> Void)?

    @State private var currentMessageIndex = 0
    @State private var displayedText = ""
    @State private var messageOpacity: Double = 0
    @State private var isTyping = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppColors.primaryAmber)
                .frame(width: 6, height: 6)
                .opacity(isTyping ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isTyping)

            Text(displayedText)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .opacity(messageOpacity)

            Spacer()
        }
        .onAppear {
            startSequence()
        }
    }

    private func startSequence() {
        guard !messages.isEmpty else { return }
        isTyping = true
        showMessage(at: 0)
    }

    private func showMessage(at index: Int) {
        guard index < messages.count else {
            isTyping = false
            onComplete?()
            return
        }

        withAnimation(.easeOut(duration: 0.15)) {
            messageOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            displayedText = messages[index]
            withAnimation(.easeIn(duration: 0.2)) {
                messageOpacity = 1
            }

            let holdDuration = max(1.0, Double(messages[index].count) * 0.03)
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                currentMessageIndex = index + 1
                showMessage(at: currentMessageIndex)
            }
        }
    }
}
