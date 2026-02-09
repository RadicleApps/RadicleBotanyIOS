import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager

    @Query private var observations: [PlantObservation]
    @Query private var achievements: [Achievement]
    @Query private var userSettingsResults: [UserSettings]

    @State private var showPaywall = false

    private var userSettings: UserSettings? {
        userSettingsResults.first
    }

    private var uniqueSpeciesCount: Int {
        Set(observations.compactMap { $0.plantScientificName }).count
    }

    private var uniqueFamiliesCount: Int {
        // Families explored derived from species - placeholder based on observation count
        // In a full implementation this would cross-reference Plant model
        Set(observations.compactMap { $0.plantScientificName }).count
    }

    private var streakCount: Int {
        userSettings?.streakCount ?? 0
    }

    private var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }
    }

    private var lockedAchievements: [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }

    private let achievementColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsCard
                currentPlanSection
                achievementsSection
                settingsNavigation
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.orangePrimary)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeManager)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orangePrimary.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.orangePrimary)
            }

            Text("Botanist")
                .font(AppFont.title(20))
                .foregroundStyle(Color.textPrimary)

            CategoryPill(
                text: storeManager.userTier.displayName,
                color: tierColor(for: storeManager.userTier)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                statItem(value: "\(uniqueSpeciesCount)", label: "Species\nObserved")
                dividerVertical
                statItem(value: "\(uniqueFamiliesCount)", label: "Families\nExplored")
                dividerVertical
                statItem(value: "\(streakCount)", label: "Day\nStreak")
            }

            Divider()
                .background(Color.borderSubtle)

            HStack(spacing: 0) {
                statItem(value: "\(observations.count)", label: "Total\nObservations")
                dividerVertical
                statItem(value: "\(unlockedAchievements.count)", label: "Milestones\nUnlocked")
            }
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.title(22))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(AppFont.caption(10))
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var dividerVertical: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(width: 0.5, height: 40)
    }

    // MARK: - Current Plan Section

    private var currentPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT PLAN")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(storeManager.userTier.displayName)
                        .font(AppFont.sectionHeader(16))
                        .foregroundStyle(Color.textPrimary)

                    Text(planDescription)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if storeManager.userTier != .pro {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Upgrade")
                            .font(AppFont.caption())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.orangePrimary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .cardStyle()
    }

    private var planDescription: String {
        switch storeManager.userTier {
        case .free:
            return "Limited access to species and features"
        case .lifetime:
            return "Full access to all species and journal"
        case .pro:
            return "Full access including capture and iCloud sync"
        }
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACHIEVEMENTS")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)

                Spacer()

                Text("\(unlockedAchievements.count)/\(achievements.count)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

            if achievements.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textMuted)
                    Text("Achievements will appear as you explore")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .cardStyle()
            } else {
                LazyVGrid(columns: achievementColumns, spacing: 12) {
                    ForEach(unlockedAchievements) { achievement in
                        achievementCard(achievement, isUnlocked: true)
                    }
                    ForEach(lockedAchievements) { achievement in
                        achievementCard(achievement, isUnlocked: false)
                    }
                }
            }
        }
    }

    private func achievementCard(_ achievement: Achievement, isUnlocked: Bool) -> some View {
        VStack(spacing: 8) {
            if isUnlocked {
                Image(systemName: achievementIcon(for: achievement.category))
                    .font(.system(size: 22))
                    .foregroundStyle(achievementColor(for: achievement.category))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textMuted)
            }

            Text(achievement.name)
                .font(AppFont.caption())
                .foregroundStyle(isUnlocked ? Color.textPrimary : Color.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if isUnlocked, let date = achievement.unlockedDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(AppFont.caption(9))
                    .foregroundStyle(Color.textMuted)
            } else {
                Text(achievement.achievementDescription)
                    .font(AppFont.caption(9))
                    .foregroundStyle(Color.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(isUnlocked ? achievementColor(for: achievement.category).opacity(0.08) : Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isUnlocked ? achievementColor(for: achievement.category).opacity(0.3) : Color.borderSubtle,
                    lineWidth: 0.5
                )
        )
    }

    private func achievementIcon(for category: String) -> String {
        switch category.lowercased() {
        case "observation", "observations":
            return "camera.fill"
        case "identification", "species":
            return "leaf.fill"
        case "streak":
            return "flame.fill"
        case "collection", "collections":
            return "folder.fill"
        case "learning", "terms":
            return "book.fill"
        case "family", "families":
            return "tree.fill"
        default:
            return "trophy.fill"
        }
    }

    private func achievementColor(for category: String) -> Color {
        switch category.lowercased() {
        case "observation", "observations":
            return .orangePrimary
        case "identification", "species":
            return .greenSecondary
        case "streak":
            return .orangeLight
        case "collection", "collections":
            return .purpleSecondary
        case "learning", "terms":
            return .purpleLight
        case "family", "families":
            return .greenLight
        default:
            return .orangePrimary
        }
    }

    private func tierColor(for tier: UserTier) -> Color {
        switch tier {
        case .free: return .textMuted
        case .lifetime: return .orangePrimary
        case .pro: return .greenSecondary
        }
    }

    // MARK: - Settings Navigation

    private var settingsNavigation: some View {
        NavigationLink {
            SettingsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)

                Text("Settings")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(StoreManager())
            .modelContainer(for: [PlantObservation.self, Achievement.self, UserSettings.self], inMemory: true)
    }
}
