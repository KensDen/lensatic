import ImageIO
import SwiftUI
import UIKit

/// The playbook's figures (R3): each diagram the website shows in a play, as the PNG tools/build_figures.mjs renders from
/// the published page, bundled in the figures folder. On the page it is drawn at most twice the screen's width in pixels,
/// so a tall diagram does not hold its full size in memory; a tap opens it full screen at full size, to zoom.
struct FigureView: View {
    let figure: LibraryBlock.Figure
    @State private var image: UIImage?
    @State private var zoomed = false

    var body: some View {
        Button { zoomed = true } label: {
            ZStack {
                Palette.bg2
                if let image { Image(uiImage: image).resizable().scaledToFit() }
            }
            .aspectRatio(CGFloat(figure.width) / CGFloat(figure.height), contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
            // a tap opens it full screen: the corner says so
            .overlay(alignment: .topTrailing) {
                Icon(.expand, size: 16, color: Palette.fg)
                    .frame(width: 32, height: 32)
                    .background(Palette.bg3.opacity(0.9), in: Circle())
                    .overlay(Circle().strokeBorder(Palette.lineStrong))
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement()
        .accessibilityLabel(figure.alt)
        .accessibilityAddTraits(.isImage)
        .accessibilityHint("Opens the figure full screen, to zoom")
        .accessibilityIdentifier("figure-\(figure.id)")
        .task(id: figure.id) { image = Figures.image(figure.id, maxWidth: 2 * 360) }
        .fullScreenCover(isPresented: $zoomed) { FigureZoom(figure: figure) }
    }
}

enum Figures {
    static func url(_ id: String) -> URL? { Bundle.main.url(forResource: id, withExtension: "png", subdirectory: "figures") }

    /// The figure at most this many pixels wide (its own width when smaller), decoded at that size.
    static func image(_ id: String, maxWidth: Int? = nil) -> UIImage? {
        guard let url = url(id), let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let scale = maxWidth.map { min(1, Double($0) / Double(w)) } ?? 1
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceShouldCacheImmediately: true,
                                        kCGImageSourceThumbnailMaxPixelSize: Int((Double(max(w, h)) * scale).rounded())]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg, scale: 3, orientation: .up)
    }
}

/// A figure full screen: pinch or double-tap to zoom, Done to close.
struct FigureZoom: View {
    let figure: LibraryBlock.Figure
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.bg.ignoresSafeArea()
            ZoomingImage(image: Figures.image(figure.id))
                .ignoresSafeArea(edges: .bottom)
                .accessibilityLabel(figure.alt)
                .accessibilityAddTraits(.isImage)
            Button { dismiss() } label: {
                Text("Done").font(DS.button).foregroundStyle(Palette.link)
                    .padding(.horizontal, 16).frame(minHeight: 44)
                    .background(Palette.bg2, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityIdentifier("figure-done")
        }
    }
}

/// UIKit's zooming scroll view around one image: SwiftUI has none.
struct ZoomingImage: UIViewRepresentable {
    let image: UIImage?

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.backgroundColor = .clear
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            view.heightAnchor.constraint(equalTo: view.widthAnchor,
                                         multiplier: (image?.size.height ?? 1) / max(1, image?.size.width ?? 1)),
        ])
        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        double.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(double)
        context.coordinator.view = view
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var view: UIView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { view }

        @MainActor @objc func doubleTap(_ g: UITapGestureRecognizer) {
            guard let scroll = g.view as? UIScrollView else { return }
            scroll.setZoomScale(scroll.zoomScale > 1 ? 1 : 2.5, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }
}
