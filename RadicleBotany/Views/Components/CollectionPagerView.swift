import SwiftUI

/// A generic horizontal pager that wraps detail views, enabling swipe left/right
/// to navigate between items in a collection without returning to the list.
///
/// Usage:
/// ```
/// CollectionPagerView(items: plants, startIndex: tappedIndex) { plant in
///     PlantDetailView(plant: plant)
/// }
/// ```
struct CollectionPagerView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let startIndex: Int
    @ViewBuilder let content: (Item) -> Content

    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(items: [Item], startIndex: Int, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.startIndex = startIndex
        self.content = content
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("\(currentIndex + 1) of \(items.count)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
    }
}
