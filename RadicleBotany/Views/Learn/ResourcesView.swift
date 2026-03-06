import SwiftUI

// MARK: - Botanical Resource Model

struct BotanicalResource: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let category: String
    let url: String
    let isDirectory: Bool?
}

// MARK: - Resources View

struct ResourcesView: View {
    @State private var resources: [BotanicalResource] = []

    private let sectionOrder = [
        "Conservation Organizations",
        "Botanical Gardens & Sanctuaries",
        "Native Plant Societies"
    ]

    // MARK: - Computed Properties

    private var groupedResources: [(section: String, items: [BotanicalResource])] {
        sectionOrder.compactMap { section in
            let items = resources.filter { $0.category == section }
            return items.isEmpty ? nil : (section, items)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Intro copy
                Text("Learn more. Get involved. These organizations are advancing plant conservation at every level.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.bottom, 4)

                ForEach(groupedResources, id: \.section) { group in
                    resourceSection(title: group.section, items: group.items)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.resources)
        .onAppear {
            loadResources()
        }
    }

    // MARK: - Resource Section

    private func resourceSection(title: String, items: [BotanicalResource]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text(title)
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.bottom, 10)

            // Grouped card container
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, resource in
                    resourceRow(resource)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Resource Row

    private func resourceRow(_ resource: BotanicalResource) -> some View {
        let isDir = resource.isDirectory ?? false

        return Link(destination: URL(string: resource.url)!) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(resource.name)
                        .font(AppTypography.bodyText)
                        .foregroundStyle(isDir ? AppColors.brandPurple : AppColors.textPrimary)

                    Text(resource.description)
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(AppTypography.inter(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Load Resources

    private func loadResources() {
        guard resources.isEmpty else { return }

        guard let url = Bundle.main.url(forResource: "Resources", withExtension: "json") else {
            print("[ResourcesView] Resources.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            resources = try JSONDecoder().decode([BotanicalResource].self, from: data)
        } catch {
            print("[ResourcesView] Failed to load Resources.json: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ResourcesView()
    }
    .preferredColorScheme(.dark)
}
