import SafariServices
import SwiftUI
import UIKit

/// The in-app reader (R3): every outside address (a source, a guide's or a play's link, the policy and support pages)
/// opens in Safari's viewer over the app, never in the system browser. Safari loads the page in its own process; the app
/// makes no network call and cannot see the page or what the reader does on it, so "Data Not Collected" stays true. It
/// is presented over whatever is on top, a sheet included, and closes with Done.
@MainActor
enum Reader {
    static func open(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http", let top = topController() else { return }
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.dismissButtonStyle = .done
        safari.preferredControlTintColor = UIColor(named: "link")
        safari.preferredBarTintColor = UIColor(named: "bg")
        safari.modalPresentationStyle = .pageSheet
        top.present(safari, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}
