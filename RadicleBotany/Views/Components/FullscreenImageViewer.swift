import SwiftUI

// MARK: - Image Source

/// Unified image source for the fullscreen viewer.
enum ImageSource: Identifiable {
    case url(String)
    case uiImage(UIImage)

    var id: String {
        switch self {
        case .url(let urlString): return urlString
        case .uiImage(let img): return "uiimage-\(ObjectIdentifier(img).hashValue)"
        }
    }
}

// MARK: - Fullscreen Image Viewer

/// Fullscreen image viewer with pinch-to-zoom, double-tap zoom, drag-to-dismiss.
struct FullscreenImageViewer: View {
    let source: ImageSource
    var caption: String? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGFloat = 0

    private let dismissThreshold: CGFloat = 150

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            makeZoomableImage()
            makeControlsOverlay()
        }
        .statusBarHidden()
    }

    // MARK: - Subviews

    @ViewBuilder
    private func makeZoomableImage() -> some View {
        imageContent
            .scaleEffect(scale)
            .offset(y: dragOffset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = min(max(newScale, 1.0), 5.0)
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if scale <= 1.01 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { _ in
                        if scale <= 1.01 && abs(dragOffset) > dismissThreshold {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                    } else {
                        scale = 3.0
                        lastScale = 3.0
                    }
                }
            }
    }

    @ViewBuilder
    private func makeControlsOverlay() -> some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.inter(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            Spacer()
            if let caption = caption {
                Text(caption)
                    .font(AppTypography.tagText)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Image Content

    @ViewBuilder
    private var imageContent: some View {
        switch source {
        case .uiImage(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)

        case .url(let urlString):
            if let url = URL(string: urlString) {
                ThrottledAsyncImage(url: url, contentMode: .fit) {
                    imagePlaceholder
                }
            } else {
                imagePlaceholder
            }
        }
    }

    private var imagePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(AppTypography.inter(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Image unavailable")
                .font(AppTypography.tagText)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
