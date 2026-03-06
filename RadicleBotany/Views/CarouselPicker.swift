import SwiftUI

/// Centered carousel pill picker with smooth snap scrolling.
/// Pills are center-aligned with horizontal scrolling. Selected pill
/// has subtle amber glow. Unselected pills fade to muted gray.
struct CarouselPicker<T: Hashable & CustomStringConvertible>: View {
    let items: [T]
    @Binding var selection: T
    let spacing: CGFloat
    let onSelectionChanged: ((T) -> Void)?

    @Namespace private var namespace

    init(
        items: [T],
        selection: Binding<T>,
        spacing: CGFloat = 8,
        onSelectionChanged: ((T) -> Void)? = nil
    ) {
        self.items = items
        self._selection = selection
        self.spacing = spacing
        self.onSelectionChanged = onSelectionChanged
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    Spacer()
                        .frame(width: leadingSpace)

                    ForEach(items, id: \.self) { item in
                        pillButton(for: item)
                            .id(item)
                    }

                    Spacer()
                        .frame(width: trailingSpace)
                }
            }
            .onChange(of: selection) { newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }

    private func pillButton(for item: T) -> some View {
        let isSelected = selection == item

        return Button {
            HapticFeedback.tap()
            withAnimation(AppAnimation.interactiveSpring) {
                selection = item
            }
            onSelectionChanged?(item)
        } label: {
            Text(item.description)
                .font(AppTypography.inter(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: AppRadius.badge)
                                .fill(AppColors.cardElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.badge)
                                        .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: AppColors.primaryAmber.opacity(0.15), radius: 4, y: 2)
                                .matchedGeometryEffect(id: "pill", in: namespace)
                        } else {
                            RoundedRectangle(cornerRadius: AppRadius.badge)
                                .fill(AppColors.cardBackground.opacity(0.5))
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var leadingSpace: CGFloat {
        guard let firstItem = items.first else { return 0 }
        let screenWidth = UIScreen.main.bounds.width
        let pillWidth = estimatedPillWidth(for: firstItem)
        return (screenWidth / 2) - (pillWidth / 2)
    }

    private var trailingSpace: CGFloat {
        guard let lastItem = items.last else { return 0 }
        let screenWidth = UIScreen.main.bounds.width
        let pillWidth = estimatedPillWidth(for: lastItem)
        return (screenWidth / 2) - (pillWidth / 2)
    }

    private func estimatedPillWidth(for item: T) -> CGFloat {
        let baseWidth: CGFloat = 32
        let charWidth: CGFloat = 8.5
        return baseWidth + (CGFloat(item.description.count) * charWidth)
    }
}

// MARK: - Preset Styles

extension CarouselPicker {
    static func compact(items: [T], selection: Binding<T>, onSelectionChanged: ((T) -> Void)? = nil) -> Self {
        CarouselPicker(items: items, selection: selection, spacing: 4, onSelectionChanged: onSelectionChanged)
    }

    static func standard(items: [T], selection: Binding<T>, onSelectionChanged: ((T) -> Void)? = nil) -> Self {
        CarouselPicker(items: items, selection: selection, spacing: 8, onSelectionChanged: onSelectionChanged)
    }

    static func spacious(items: [T], selection: Binding<T>, onSelectionChanged: ((T) -> Void)? = nil) -> Self {
        CarouselPicker(items: items, selection: selection, spacing: 12, onSelectionChanged: onSelectionChanged)
    }
}
