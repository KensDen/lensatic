import Foundation

/// The three outside addresses the app links to besides the documents cited in Sources: the privacy policy (App Store
/// guideline 5.1.1 asks for it inside the app), the support page, and the source repository. The battery holds the
/// Swift sources to these three.
enum Site {
    static let privacy = URL(string: "https://kensden.github.io/lensatic/privacy.html")!
    static let support = URL(string: "https://kensden.github.io/lensatic/support.html")!
    static let source = URL(string: "https://github.com/KensDen/lensatic")!
}
