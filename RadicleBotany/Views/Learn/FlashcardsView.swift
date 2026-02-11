import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var terms: [BotanyTerm] = []
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            if terms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.largeTitle)
                        .foregroundStyle(Color.textMuted)
                    Text("No terms available")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                VStack(spacing: 20) {
                    // Progress
                    HStack {
                        Text("\(currentIndex + 1) of \(terms.count)")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)

                        Spacer()

                        CategoryPill(text: terms[currentIndex].category, color: categoryColor(for: terms[currentIndex].category))
                    }
                    .padding(.horizontal, 24)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.borderSubtle)
                                .frame(height: 3)

                            Capsule()
                                .fill(Color.orangePrimary)
                                .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(terms.count), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 24)

                    Spacer()

                    // Flashcard
                    flashcard
                        .offset(x: offset.width)
                        .rotationEffect(.degrees(Double(offset.width / 40)))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                }
                                .onEnded { value in
                                    if abs(value.translation.width) > 100 {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            offset.width = value.translation.width > 0 ? 500 : -500
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            nextCard()
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            offset = .zero
                                        }
                                    }
                                }
                        )

                    Spacer()

                    // Hint
                    Text("Tap to flip · Swipe to continue")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.textMuted)

                    // Navigation buttons
                    HStack(spacing: 24) {
                        Button {
                            previousCard()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.title3)
                                .foregroundStyle(currentIndex > 0 ? Color.textPrimary : Color.textMuted)
                                .frame(width: 50, height: 50)
                                .background(Color.surface)
                                .clipShape(Circle())
                        }
                        .disabled(currentIndex == 0)

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isFlipped.toggle()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .foregroundStyle(Color.orangePrimary)
                                .frame(width: 60, height: 60)
                                .background(Color.orangePrimary.opacity(0.12))
                                .clipShape(Circle())
                        }

                        Button {
                            nextCard()
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundStyle(currentIndex < terms.count - 1 ? Color.textPrimary : Color.textMuted)
                                .frame(width: 50, height: 50)
                                .background(Color.surface)
                                .clipShape(Circle())
                        }
                        .disabled(currentIndex >= terms.count - 1)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    terms.shuffle()
                    currentIndex = 0
                    isFlipped = false
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .onAppear { loadTerms() }
    }

    // MARK: - Flashcard

    private var flashcard: some View {
        ZStack {
            if isFlipped {
                // Back: definition
                VStack(spacing: 16) {
                    Text(terms[currentIndex].term)
                        .font(AppFont.sectionHeader(16))
                        .foregroundStyle(Color.orangePrimary)

                    Divider()
                        .background(Color.borderSubtle)

                    let desc = terms[currentIndex].descriptionShort.isEmpty
                        ? terms[currentIndex].descriptionLong
                        : terms[currentIndex].descriptionShort

                    ScrollView {
                        Text(markdownToAttributed(desc.isEmpty ? "No definition available." : desc))
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: 340)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orangePrimary.opacity(0.3), lineWidth: 1)
                )
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                // Front: term name
                VStack(spacing: 16) {
                    Spacer()

                    Text(terms[currentIndex].term)
                        .font(AppFont.title(28))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Spacer()

                    Text("Tap to reveal")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: 340)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.borderSubtle, lineWidth: 0.5)
                )
            }
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .padding(.horizontal, 24)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFlipped.toggle()
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    // MARK: - Actions

    private func nextCard() {
        if currentIndex < terms.count - 1 {
            currentIndex += 1
            isFlipped = false
            offset = .zero
        }
    }

    private func previousCard() {
        if currentIndex > 0 {
            currentIndex -= 1
            isFlipped = false
            offset = .zero
        }
    }

    private func loadTerms() {
        let fetched = (try? modelContext.fetch(FetchDescriptor<BotanyTerm>())) ?? []
        terms = fetched.filter { $0.isFree || !$0.descriptionShort.isEmpty }.shuffled()
    }

    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case let c where c.contains("leaf") || c.contains("leaves"):
            return .greenSecondary
        case let c where c.contains("flower"):
            return .orangePrimary
        case let c where c.contains("fruit"):
            return .warningAmber
        case let c where c.contains("stem") || c.contains("bark"):
            return .orangeLight
        case let c where c.contains("root"):
            return .greenLight
        default:
            return .purpleSecondary
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardsView()
    }
    .modelContainer(for: BotanyTerm.self, inMemory: true)
    .preferredColorScheme(.dark)
}
