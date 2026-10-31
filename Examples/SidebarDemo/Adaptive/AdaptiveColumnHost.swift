import SwiftUI
import UIKit

/// Hosts one column of the layout in its own UIKit view controller.
///
/// A navigation stack placed directly in the layout inherits safe-area insets
/// from the whole layout, even for edges the column doesn't touch. Hosting each
/// column in its own controller lets UIKit compute the column's safe area from
/// where it actually sits, and lets the layout add clearance (such as beside a
/// fold) as real safe area that navigation bars, search fields and lists all
/// respect. This is what the native split view does for its columns.
struct AdaptiveColumnHost<Content: View>: UIViewControllerRepresentable {
    /// Extra safe area inside the column's leading and trailing edges.
    var leadingClearance: CGFloat = 0
    var trailingClearance: CGFloat = 0
    /// Whether this column may use the system's vertical bar (the iPhone Duo's
    /// rail, iOS 27.1+). A navigation stack reserves the rail's width inside
    /// itself whenever the window has a rail, wherever the stack sits. A column
    /// that doesn't reach the rail should opt out, as a native split view's
    /// sidebar does.
    var allowsVerticalBar = true
    @ViewBuilder var content: Content

    func makeUIViewController(context: Context) -> AdaptiveColumnController<AdaptiveColumnRoot<Content>> {
        let controller = AdaptiveColumnController(rootView: root(context))
        controller.view.backgroundColor = .clear
        // The column is sized by the layout, not by its content.
        controller.sizingOptions = []
        controller.additionalSafeAreaInsets = insets(context)
        controller.allowsVerticalBar = allowsVerticalBar
        return controller
    }

    func updateUIViewController(_ controller: AdaptiveColumnController<AdaptiveColumnRoot<Content>>, context: Context) {
        controller.rootView = root(context)
        let insets = insets(context)
        if controller.additionalSafeAreaInsets != insets {
            controller.additionalSafeAreaInsets = insets
        }
        controller.allowsVerticalBar = allowsVerticalBar
    }

    private func root(_ context: Context) -> AdaptiveColumnRoot<Content> {
        AdaptiveColumnRoot(content: content, environment: context.environment)
    }

    private func insets(_ context: Context) -> UIEdgeInsets {
        let isRightToLeft = context.environment.layoutDirection == .rightToLeft
        return UIEdgeInsets(
            top: 0,
            left: isRightToLeft ? trailingClearance : leadingClearance,
            bottom: 0,
            right: isRightToLeft ? leadingClearance : trailingClearance
        )
    }
}

/// The hosting controller for one column.
final class AdaptiveColumnController<Root: View>: UIHostingController<Root> {
    var allowsVerticalBar = true {
        didSet {
            guard allowsVerticalBar != oldValue else { return }
            if #available(iOS 27.1, *) {
                setNeedsUpdateOfVerticalBarConfiguration()
            }
        }
    }

    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
        allowsVerticalBar ? .automatic : .disabled
    }
}

/// The hosted column's root: the column content with the surrounding SwiftUI
/// environment (tint, fonts, custom values and so on) carried across the
/// UIKit boundary.
struct AdaptiveColumnRoot<Content: View>: View {
    let content: Content
    let environment: EnvironmentValues

    var body: some View {
        content.environment(\.self, environment)
    }
}
