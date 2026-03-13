import SwiftUI

struct BotanizingScenarioView: View {
    let scenario: BotanizingScenario
    @Environment(\.dismiss) private var dismiss
    @AppStorage("botanizing_completed") private var completedIds: String = ""

    // MARK: - State

    @State private var currentNodeId: String
    @State private var pathSteps: [ScenarioPathStep] = []
    @State private var selectedChoice: BotanizingChoice? = nil
    @State private var showOutcome = false
    @State private var nodeTransitionId = UUID()

    init(scenario: BotanizingScenario) {
        self.scenario = scenario
        _currentNodeId = State(initialValue: scenario.startNodeId)
    }

    private var currentNode: BotanizingNode? {
        scenario.nodes[currentNodeId]
    }

    private var decisionCount: Int {
        scenario.nodes.values.filter { $0.choices != nil }.count
    }

    private var progress: Double {
        guard decisionCount > 0 else { return 0 }
        return Double(pathSteps.count) / Double(decisionCount)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            if let node = currentNode {
                if let outcome = node.outcome {
                    outcomeView(outcome)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    decisionView(node)
                        .id(nodeTransitionId)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.buttonText)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.cardBackground)
                        .clipShape(Circle())
                }
            }

            ToolbarItem(placement: .principal) {
                Text(scenario.title)
                    .font(.cormorant(size: 19, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Decision View

    private func decisionView(_ node: BotanizingNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Progress bar
                progressBar

                // Scene narrative
                if let narrative = node.narrative {
                    narrativeCard(narrative)
                }

                // Hint (if available)
                if let hint = node.hint {
                    hintRow(hint)
                }

                // Choice buttons
                if let choices = node.choices {
                    VStack(spacing: 10) {
                        ForEach(choices) { choice in
                            choiceButton(choice, allChoices: choices)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.cardBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.primaryAmber)
                        .frame(width: max(6, geo.size.width * progress), height: 6)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Decision \(pathSteps.count + 1)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: scenario.categoryType.icon)
                        .font(AppTypography.inter(size: 10))
                    Text(scenario.category)
                        .font(AppTypography.caption)
                }
                .foregroundStyle(AppColors.primaryAmber)
            }
        }
    }

    // MARK: - Narrative Card

    private func narrativeCard(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.bodyText)
            .foregroundStyle(AppColors.textPrimary)
            .lineSpacing(4)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.primaryAmber.opacity(0.2), lineWidth: 0.5)
            )
    }

    // MARK: - Hint Row

    private func hintRow(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.primaryAmber)

            Text(hint)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .italic()
        }
        .padding(14)
        .background(AppColors.primaryAmber.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }

    // MARK: - Choice Button

    private func choiceButton(_ choice: BotanizingChoice, allChoices: [BotanizingChoice]) -> some View {
        Button {
            guard selectedChoice == nil else { return }
            selectChoice(choice)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Letter indicator
                let index = allChoices.firstIndex(where: { $0.id == choice.id }) ?? 0
                let letter = ["A", "B", "C", "D"][min(index, 3)]

                Text(letter)
                    .font(AppTypography.chipText)
                    .foregroundStyle(selectedChoice?.id == choice.id ? AppColors.onAccent : AppColors.primaryAmber)
                    .frame(width: 28, height: 28)
                    .background(
                        selectedChoice?.id == choice.id
                            ? AppColors.primaryAmber
                            : AppColors.primaryAmber.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(choice.text)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(
                        selectedChoice != nil && selectedChoice?.id != choice.id
                            ? AppColors.textMuted
                            : AppColors.textPrimary
                    )
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedChoice?.id == choice.id
                    ? AppColors.primaryAmber.opacity(0.12)
                    : AppColors.cardBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(
                        selectedChoice?.id == choice.id
                            ? AppColors.primaryAmber.opacity(0.5)
                            : AppColors.border,
                        lineWidth: selectedChoice?.id == choice.id ? 1.5 : 0.5
                    )
            )
            .opacity(selectedChoice != nil && selectedChoice?.id != choice.id ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(selectedChoice != nil)
        .animation(.easeOut(duration: 0.2), value: selectedChoice?.id)
    }

    // MARK: - Selection Logic

    private func selectChoice(_ choice: BotanizingChoice) {
        withAnimation(.easeOut(duration: 0.2)) {
            selectedChoice = choice
        }

        pathSteps.append(ScenarioPathStep(
            nodeId: currentNodeId,
            choiceText: choice.text,
            quality: choice.qualityLevel
        ))

        // Transition to next node after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedChoice = nil
                currentNodeId = choice.nextNodeId
                nodeTransitionId = UUID()
            }
        }
    }

    // MARK: - Outcome View

    private func outcomeView(_ outcome: BotanizingOutcome) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // Grade icon + message
                gradeHeader(outcome)

                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    Text(outcome.title)
                        .font(AppTypography.headerTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(outcome.summary)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(outcome.gradeLevel.color.opacity(0.3), lineWidth: 0.5)
                )

                // Path summary
                if !pathSteps.isEmpty {
                    pathSummaryCard
                }

                // Key Lessons
                lessonsCard(outcome.keyLessons)

                // Related Terms
                if let terms = outcome.relatedTerms, !terms.isEmpty {
                    relatedTermsCard(terms)
                }

                // Action buttons
                actionButtons

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .onAppear {
            markCompleted()
        }
    }

    // MARK: - Grade Header

    private func gradeHeader(_ outcome: BotanizingOutcome) -> some View {
        VStack(spacing: 12) {
            // Grade ring
            ZStack {
                Circle()
                    .stroke(outcome.gradeLevel.color.opacity(0.15), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .stroke(outcome.gradeLevel.color, lineWidth: 6)
                    .frame(width: 80, height: 80)

                Image(systemName: outcome.gradeLevel.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(outcome.gradeLevel.color)
            }

            Text(outcome.gradeLevel.message)
                .font(AppTypography.displayMedium)
                .foregroundStyle(AppColors.textPrimary)

            Text(outcome.grade)
                .font(AppTypography.chipText)
                .foregroundStyle(outcome.gradeLevel.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(outcome.gradeLevel.color.opacity(0.12))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Path Summary

    private var pathSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR PATH")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)
                .tracking(1.2)

            ForEach(Array(pathSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    // Quality indicator
                    Image(systemName: qualityIcon(step.quality))
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(qualityColor(step.quality))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Decision \(index + 1)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                        Text(step.choiceText)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }

                if index < pathSteps.count - 1 {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(width: 1, height: 12)
                        .padding(.leading, 10)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func qualityIcon(_ quality: ChoiceQuality) -> String {
        switch quality {
        case .optimal: return "checkmark.circle.fill"
        case .acceptable: return "circle.fill"
        case .poor: return "exclamationmark.circle.fill"
        case .dangerous: return "xmark.circle.fill"
        }
    }

    private func qualityColor(_ quality: ChoiceQuality) -> Color {
        switch quality {
        case .optimal: return AppColors.success
        case .acceptable: return AppColors.primaryAmber
        case .poor: return AppColors.warning
        case .dangerous: return AppColors.error
        }
    }

    // MARK: - Lessons Card

    private func lessonsCard(_ lessons: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY LESSONS")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)
                .tracking(1.2)

            ForEach(lessons, id: \.self) { lesson in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(AppTypography.inter(size: 12))
                        .foregroundStyle(AppColors.primaryAmber)
                        .frame(width: 16)
                        .padding(.top, 2)

                    Text(lesson)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Related Terms

    private func relatedTermsCard(_ terms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RELATED TERMS")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)
                .tracking(1.2)

            FlowLayout(spacing: 8) {
                ForEach(terms, id: \.self) { term in
                    Text(term)
                        .font(AppTypography.chipText)
                        .foregroundStyle(AppColors.primaryAmber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.primaryAmber.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.primaryAmber.opacity(0.25), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Try Again
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentNodeId = scenario.startNodeId
                    pathSteps = []
                    selectedChoice = nil
                    nodeTransitionId = UUID()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Try Again")
                }
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.primaryAmber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.primaryAmber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 1)
                )
            }

            // Back to scenarios
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                    Text("Done")
                }
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.primaryAmber)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
        }
    }

    // MARK: - Helpers

    private func markCompleted() {
        var ids = Set(completedIds.split(separator: ",").map(String.init))
        ids.insert(scenario.id)
        completedIds = ids.sorted().joined(separator: ",")
    }
}

// FlowLayout is defined in ObservationDetailView.swift and shared project-wide

#Preview {
    NavigationStack {
        BotanizingScenarioView(
            scenario: BotanizingDataLoader.shared.loadScenarios().first ?? BotanizingScenario(
                id: "preview",
                title: "Preview",
                subtitle: "Test",
                category: "Identification",
                difficulty: "Beginner",
                estimatedMinutes: 3,
                icon: "leaf.fill",
                startNodeId: "start",
                nodes: [:]
            )
        )
    }
    .preferredColorScheme(.dark)
}
