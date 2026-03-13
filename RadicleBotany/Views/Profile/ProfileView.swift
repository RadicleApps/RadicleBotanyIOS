import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: StoreManager

    @Query private var observations: [PlantObservation]
    @Query private var achievements: [Achievement]
    @Query private var userSettingsResults: [UserSettings]
    @Query private var allPlants: [Plant]
    @Query private var allFamilies: [Family]
    @Query private var allTerms: [BotanyTerm]
    @Query private var flashcardProgress: [FlashcardProgress]

    @ObservedObject private var locationManager = LocationManager.shared

    @State private var showEditProfile = false
    @State private var showShareSheet = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var animateRings = false

    private var userSettings: UserSettings? {
        userSettingsResults.first
    }

    private var uniqueSpeciesCount: Int {
        Set(observations.compactMap { $0.plantScientificName }).count
    }

    private var uniqueFamiliesCount: Int {
        let observedNames = Set(observations.compactMap { $0.plantScientificName })
        let families = allPlants
            .filter { observedNames.contains($0.scientificName) }
            .map { $0.familyLatin }
        return Set(families).count
    }

    private var streakCount: Int {
        userSettings?.streakCount ?? 0
    }

    private var studyStreak: Int {
        userSettings?.safeStudyStreak ?? 0
    }

    private var totalXP: Int {
        userSettings?.safeTotalXP ?? 0
    }

    private var flashcardMasteryPercent: Int {
        guard !flashcardProgress.isEmpty else { return 0 }
        let mastered = flashcardProgress.filter { $0.status == "known" }.count
        return Int(Double(mastered) / Double(flashcardProgress.count) * 100)
    }

    private var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }
    }

    private var lockedAchievements: [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }

    private var nextAchievement: Achievement? {
        lockedAchievements.first
    }

    private var profileDisplayName: String {
        if let name = userSettings?.profileName, !name.isEmpty {
            return name
        }
        return "Botanist"
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeader
                statsSection
                    .padding(.top, 24)
                quickActions
                    .padding(.top, 20)
                achievementsSection
                    .padding(.top, 24)
            }
            .padding(.bottom, 100)
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                InfoButton(guide: .profile, style: .toolbar)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.primaryAmber)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            editProfileSheet
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [
                "Hey check out this awesome plant ID app! https://apps.apple.com/us/app/radiclebotany/id6759073523"
            ])
            .presentationDetents([.medium])
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animateRings = true
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Botanical illustration backdrop
            Image("Actinomorphic (symmetry) color")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .opacity(0.08)

            // Gradient fade
            LinearGradient(
                colors: [AppColors.appBackground.opacity(0), AppColors.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .offset(y: 40)

            // Profile content
            VStack(spacing: 14) {
                // Avatar with ring
                ZStack {
                    // Animated ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    AppColors.primaryAmber,
                                    AppColors.success,
                                    AppColors.brandPurple,
                                    AppColors.primaryAmber
                                ],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 92, height: 92)
                        .opacity(animateRings ? 0.8 : 0.2)

                    // Avatar
                    ZStack(alignment: .bottomTrailing) {
                        if let photoData = userSettings?.profilePhotoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 84, height: 84)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.primaryAmber.opacity(0.2), AppColors.primaryAmber.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 84, height: 84)

                                Image(systemName: "person.fill")
                                    .font(AppTypography.inter(size: 32, weight: .light))
                                    .foregroundStyle(AppColors.primaryAmber.opacity(0.7))
                            }
                        }

                        // Edit badge
                        Button {
                            editName = profileDisplayName == "Botanist" ? "" : profileDisplayName
                            editEmail = userSettings?.profileEmail ?? ""
                            showEditProfile = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppColors.cardBackground)
                                    .frame(width: 28, height: 28)

                                Circle()
                                    .fill(AppColors.primaryAmber)
                                    .frame(width: 24, height: 24)

                                Image(systemName: "pencil")
                                    .font(AppTypography.inter(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .offset(x: 2, y: 2)
                    }
                }

                // Name
                Text(profileDisplayName)
                    .font(.cormorant(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                // Tier pill + streak
                HStack(spacing: 10) {
                    CategoryPill(
                        text: storeManager.userTier.displayName,
                        color: tierColor(for: storeManager.userTier)
                    )

                    if streakCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(AppTypography.inter(size: 10))
                                .foregroundStyle(Color.orangePrimary)
                            Text("\(streakCount) day streak")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .frame(height: 260)
        .clipped()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 16) {
            // Progress rings row
            HStack(spacing: 0) {
                progressRing(
                    current: uniqueSpeciesCount,
                    total: allPlants.count,
                    label: "Species",
                    icon: "leaf.fill",
                    color: .orangePrimary
                )

                // Center divider with XP
                VStack(spacing: 6) {
                    Text(formatXP(totalXP))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("XP")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.textMuted)
                        .kerning(2)
                }
                .frame(maxWidth: .infinity)

                progressRing(
                    current: uniqueFamiliesCount,
                    total: allFamilies.count,
                    label: "Families",
                    icon: "leaf.circle.fill",
                    color: .orangePrimary
                )
            }
            .padding(.horizontal, 16)

            // Stat chips row
            HStack(spacing: 8) {
                statChip(
                    value: "\(observations.count)",
                    label: "Observations",
                    icon: "camera.fill",
                    color: .orangePrimary
                )

                statChip(
                    value: "\(studyStreak)",
                    label: "Study Streak",
                    icon: "flame.fill",
                    color: .orangePrimary
                )

                statChip(
                    value: "\(flashcardMasteryPercent)%",
                    label: "Mastery",
                    icon: "chart.bar.fill",
                    color: .orangePrimary
                )

                statChip(
                    value: "\(unlockedAchievements.count)/\(achievements.count)",
                    label: "Milestones",
                    icon: "trophy.fill",
                    color: .purpleLight
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private func progressRing(current: Int, total: Int, label: String, icon: String, color: Color) -> some View {
        let percentage = total > 0 ? Double(current) / Double(total) : 0

        return VStack(spacing: 8) {
            ZStack {
                // Track
                Circle()
                    .stroke(color.opacity(0.1), lineWidth: 6)
                    .frame(width: 72, height: 72)

                // Progress
                Circle()
                    .trim(from: 0, to: animateRings ? percentage : 0)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 1) {
                    Text("\(current)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(color)
                }
            }

            VStack(spacing: 2) {
                Text(label)
                    .font(AppTypography.inter(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Text("of \(total)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statChip(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 11))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(AppTypography.inter(size: 8, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 8) {
            // Plan + Upgrade
            planRow

            // Location
            locationRow

            // Navigation actions
            VStack(spacing: 8) {
                NavigationLink {
                    SettingsView()
                } label: {
                    actionCardLabel(
                        icon: "gearshape.fill",
                        label: "Settings",
                        color: AppColors.textSecondary
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showShareSheet = true
                } label: {
                    actionCardLabel(
                        icon: "square.and.arrow.up.fill",
                        label: "Share App",
                        color: AppColors.success
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func actionCardLabel(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(color)

            Text(label)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.inter(size: 10))
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // Plan row with upgrade CTA
    private var planRow: some View {
        HStack(spacing: 12) {
            // Tier icon
            ZStack {
                Circle()
                    .fill(tierColor(for: storeManager.userTier).opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: tierIcon(for: storeManager.userTier))
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(tierColor(for: storeManager.userTier))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(storeManager.userTier.displayName)
                    .font(AppTypography.buttonText)
                    .foregroundStyle(AppColors.textPrimary)

                Text(planDescription)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()

            if storeManager.userTier != .free {
                Image(systemName: "checkmark.seal.fill")
                    .font(AppTypography.inter(size: 16))
                    .foregroundStyle(tierColor(for: storeManager.userTier))
            }
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(tierColor(for: storeManager.userTier).opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Location Row

    private var locationRow: some View {
        Button {
            handleLocationTap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(locationStatusColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: locationStatusIcon)
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(locationStatusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Location")
                        .font(AppTypography.buttonText)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(locationStatusText)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                }

                Spacer()

                if locationManager.authorizationStatus == .authorizedWhenInUse ||
                   locationManager.authorizationStatus == .authorizedAlways {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.inter(size: 16))
                        .foregroundStyle(AppColors.success)
                } else {
                    Text(locationActionText)
                        .font(AppTypography.inter(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.primaryAmber)
                }
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(locationStatusColor.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var locationStatusIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash.fill"
        default:
            return "location.circle"
        }
    }

    private var locationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return AppColors.success
        case .denied, .restricted:
            return AppColors.error
        default:
            return AppColors.primaryAmber
        }
    }

    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Enabled — used for Plants Near Me"
        case .denied:
            return "Denied — tap to open Settings"
        case .restricted:
            return "Restricted by device policy"
        default:
            return "Not set — needed for Plants Near Me"
        }
    }

    private var locationActionText: String {
        switch locationManager.authorizationStatus {
        case .denied:
            return "Settings"
        default:
            return "Enable"
        }
    }

    private func handleLocationTap() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Already enabled — refresh location
            locationManager.requestLocation()
        case .denied, .restricted:
            // Open iOS Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            // Request permission
            locationManager.requestLocationPermission()
        }
    }

    private var planDescription: String {
        switch storeManager.userTier {
        case .free:
            return "Limited access to species and features"
        case .annual:
            return "Full access to all species and tools"
        }
    }

    private func tierIcon(for tier: UserTier) -> String {
        switch tier {
        case .free: return "leaf"
        case .annual: return "star.fill"
        }
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text("ACHIEVEMENTS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.primaryAmber)
                    .kerning(2)

                Spacer()

                Text("\(unlockedAchievements.count) of \(achievements.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.horizontal, 16)

            // Next milestone teaser
            if let next = nextAchievement {
                nextMilestoneCard(next)
                    .padding(.horizontal, 16)
            }

            // Achievement grid
            if achievements.isEmpty {
                emptyAchievements
                    .padding(.horizontal, 16)
            } else {
                // Horizontal scrollable achievement showcase
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(unlockedAchievements) { achievement in
                            achievementBadge(achievement, isUnlocked: true)
                        }
                        ForEach(lockedAchievements) { achievement in
                            achievementBadge(achievement, isUnlocked: false)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func nextMilestoneCard(_ achievement: Achievement) -> some View {
        let color = achievementColor(for: achievement.category)

        return HStack(spacing: 12) {
            // Pulsing icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
                    .frame(width: 44, height: 44)

                Image(systemName: achievementIcon(for: achievement.category))
                    .font(AppTypography.inter(size: 18))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("NEXT MILESTONE")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
                    .kerning(1.5)

                Text(achievement.name)
                    .font(AppTypography.inter(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(achievement.achievementDescription)
                    .font(AppTypography.inter(size: 11, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.clear)
    }

    private func achievementBadge(_ achievement: Achievement, isUnlocked: Bool) -> some View {
        let color = achievementColor(for: achievement.category)

        return VStack(spacing: 8) {
            ZStack {
                if isUnlocked {
                    // Glow ring
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 52, height: 52)

                    Image(systemName: achievementIcon(for: achievement.category))
                        .font(AppTypography.inter(size: 20, weight: .medium))
                        .foregroundStyle(color)
                } else {
                    Circle()
                        .fill(AppColors.cardElevated)
                        .frame(width: 52, height: 52)

                    Image(systemName: "lock.fill")
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.textMuted.opacity(0.5))
                }
            }

            Text(achievement.name)
                .font(AppTypography.inter(size: 10, weight: .medium))
                .foregroundStyle(isUnlocked ? AppColors.textPrimary : AppColors.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 72)

            if isUnlocked, let date = achievement.unlockedDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .frame(width: 80)
    }

    private var emptyAchievements: some View {
        VStack(spacing: 10) {
            Image("Sequential Morphology of Emergence")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 70)
                .opacity(0.4)

            Text("Achievements appear as you explore")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Edit Profile Sheet

    private var editProfileSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Photo picker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        if let photoData = userSettings?.profilePhotoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primaryAmber.opacity(0.15))
                                    .frame(width: 88, height: 88)

                                Image(systemName: "person.fill")
                                    .font(AppTypography.inter(size: 32))
                                    .foregroundStyle(AppColors.primaryAmber)
                            }
                        }

                        ZStack {
                            Circle()
                                .fill(AppColors.primaryAmber)
                                .frame(width: 28, height: 28)

                            Image(systemName: "camera.fill")
                                .font(AppTypography.inter(size: 12))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    loadPhoto(from: newItem)
                }

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.primaryAmber)
                        .kerning(1.5)

                    TextField("Enter your name", text: $editName)
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppColors.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .stroke(AppColors.border, lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, 16)

                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("EMAIL")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.primaryAmber)
                        .kerning(1.5)

                    TextField("Enter your email", text: $editEmail)
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textPrimary)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppColors.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .stroke(AppColors.border, lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, 16)

                // Remove photo button
                if userSettings?.profilePhotoData != nil {
                    Button {
                        userSettings?.profilePhotoData = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(AppTypography.inter(size: 12))
                            Text("Remove Photo")
                                .font(AppTypography.tagText)
                        }
                        .foregroundStyle(AppColors.error)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.top, 24)
            .background(AppColors.appBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showEditProfile = false
                    }
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        showEditProfile = false
                    }
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func saveProfile() {
        guard let settings = userSettings else {
            let newSettings = UserSettings(
                profileName: editName.isEmpty ? nil : editName,
                profileEmail: editEmail.isEmpty ? nil : editEmail
            )
            modelContext.insert(newSettings)
            return
        }
        settings.profileName = editName.isEmpty ? nil : editName
        settings.profileEmail = editEmail.isEmpty ? nil : editEmail
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    let compressed = uiImage.jpegData(compressionQuality: 0.6)
                    await MainActor.run {
                        userSettings?.profilePhotoData = compressed
                    }
                }
            }
        }
    }

    private func achievementIcon(for category: String) -> String {
        switch category.lowercased() {
        case "observation", "observations", "observe":
            return "camera.fill"
        case "identification", "species":
            return "leaf.fill"
        case "streak":
            return "flame.fill"
        case "collection", "collections", "journal":
            return "folder.fill"
        case "learning", "terms", "learn":
            return "book.fill"
        case "family", "families":
            return "leaf.circle.fill"
        case "capture":
            return "camera.viewfinder"
        case "flashcard":
            return "rectangle.on.rectangle.angled"
        default:
            return "trophy.fill"
        }
    }

    private func achievementColor(for category: String) -> Color {
        return .orangePrimary
    }

    private func tierColor(for tier: UserTier) -> Color {
        switch tier {
        case .free: return AppColors.textMuted
        case .annual: return .orangePrimary
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(StoreManager(preview: true))
            .modelContainer(for: [PlantObservation.self, Achievement.self, UserSettings.self, Plant.self, Family.self, BotanyTerm.self, FlashcardProgress.self], inMemory: true)
    }
}
