import ImageIO
import SwiftUI
import UIKit

/// The playbook's figures (R3): each diagram the website shows in a play, as the PNG tools/build_figures.mjs renders from
/// the published page, bundled in the figures folder, in the reader's appearance (R4: dark, or light from figures/light).
/// On the page it is drawn at most twice the screen's width in pixels, so a tall diagram does not hold its full size in
/// memory; a tap opens it full screen at full size, to zoom. The six small ones the app draws itself (NativeFigures.swift).
/// VoiceOver reads each figure's name and its description.
struct FigureView: View {
    let figure: LibraryBlock.Figure
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?
    @State private var zoomed = false

    var body: some View {
        Group {
            if figure.native {
                NativeFigure(figure: figure)
            } else {
                drawn
            }
        }
        .id("figure-\(figure.id)")
    }

    private var drawn: some View {
        ZStack {
            Palette.bg2
            // drawn in a canvas, which accessibility never exposes: the figure's one element below carries its name and
            // description (an image view here showed VoiceOver a second, unnamed element)
            if let cg = image?.cgImage {
                Canvas { ctx, size in ctx.draw(Image(decorative: cg, scale: 1), in: CGRect(origin: .zero, size: size)) }
            }
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
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { zoomed = true }
        // one element for VoiceOver: the figure's name, its description, an image that opens full screen
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(figure.alt)
        .accessibilityValue(figure.description)
        .accessibilityAddTraits([.isImage, .isButton])
        .accessibilityAction { zoomed = true }
        .accessibilityHint("Opens the figure full screen, to zoom")
        .accessibilityIdentifier("figure-\(figure.id)")
        .task(id: "\(figure.id)-\(scheme)") { image = Figures.image(figure.id, light: scheme == .light, maxWidth: 2 * 360) }
        .fullScreenCover(isPresented: $zoomed) { FigureZoom(figure: figure) }
    }
}

enum Figures {
    /// The figure's PNG: the dark render, or the light one under figures/light.
    static func url(_ id: String, light: Bool = false) -> URL? {
        Bundle.main.url(forResource: id, withExtension: "png", subdirectory: light ? "figures/light" : "figures")
    }

    /// The figure at most this many pixels wide (its own width when smaller), decoded at that size.
    static func image(_ id: String, light: Bool = false, maxWidth: Int? = nil) -> UIImage? {
        guard let url = url(id, light: light), let source = CGImageSourceCreateWithURL(url as CFURL, nil),
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.bg.ignoresSafeArea()
            ZoomingImage(image: Figures.image(figure.id, light: scheme == .light))
                .id(scheme)
                .ignoresSafeArea(edges: .bottom)
                .accessibilityLabel(figure.alt)
                .accessibilityValue(figure.description)
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
