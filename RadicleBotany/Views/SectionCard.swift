import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.componentGapMedium) {
            if let title = title {
                Text(title)
                    .sectionHeaderStyle()
            }
            content
        }
        .padding(AppSpacing.sectionPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct FieldRow: View {
    let label: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.fieldLabel)
                .foregroundColor(AppColors.textMuted)
            Text(value ?? "-")
                .font(AppTypography.fieldValue)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

struct FieldRowHorizontal: View {
    let label: String
    let value: String?

    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.fieldLabel)
                .foregroundColor(AppColors.textMuted)
            Spacer()
            Text(value ?? "-")
                .font(AppTypography.fieldValue)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}
