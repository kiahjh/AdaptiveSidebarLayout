import SwiftUI
import UIKit

/// Hides the split view's launch-time toolbar jump on iPad behind a plain
/// cover that matches the launch screen, then fades the cover out once the
/// layout has settled. The app still lays out normally underneath; nothing
/// about the layout itself changes.
///
/// On iPad, `NavigationSplitView` inside a `TabView` first lays out its
/// toolbars one tab-bar height too low and corrects them about 0.1 s later.
/// iPhone (including iPhone Duo) doesn't, so it gets no cover.
///
/// Debug options:
/// - `--launch-cover=0.3`: lift after a fixed number of seconds instead.
/// - `--no-launch-cover`: no cover, for comparison.
/// - `--force-launch-cover`: cover on any device.
enum NativeLaunchCoverMode: Equatable {
    case untilSettled
    case fixed(seconds: Double)

    static func resolve(idiom: UIUserInterfaceIdiom, arguments: [String]) -> Self? {
        var isWanted = idiom == .pad
        #if DEBUG
            if arguments.contains("--no-launch-cover") { return nil }
            if arguments.contains("--force-launch-cover") { isWanted = true }
            let prefix = "--launch-cover="
            if let argument = arguments.first(where: { $0.hasPrefix(prefix) }),
               let seconds = Double(argument.dropFirst(prefix.count))
            {
                return .fixed(seconds: seconds)
            }
        #endif
        return isWanted ? .untilSettled : nil
    }
}

struct NativeLaunchCover: ViewModifier {
    let mode: NativeLaunchCoverMode?
    @State private var isCovered = true

    func body(content: Content) -> some View {
        content
            .overlay {
                if let mode, isCovered {
                    // `UILaunchScreen` with no keys is a plain screen in
                    // the system background color.
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .background {
                            if mode == .untilSettled {
                                LayoutSettleWatcher(onSettle: reveal)
                                    .frame(width: 0, height: 0)
                            }
                        }
                        .transition(.opacity)
                }
            }
            .task {
                guard case let .fixed(seconds) = mode else { return }
                try? await Task.sleep(for: .seconds(seconds))
                reveal()
            }
    }

    private func reveal() {
        guard isCovered else { return }
        #if DEBUG
            // Read by the launch checks to confirm the cover lifts after
            // the last layout change.
            NativeLayoutProbe.ProbeView.record(
                "cover lifted at t=\(NativeLayoutProbe.ProbeView.elapsed())s",
                to: "launch-cover.txt"
            )
        #endif
        withAnimation(.easeOut(duration: 0.15)) { isCovered = false }
    }
}

/// Reads the window's navigation bar frames and the selected tab's top
/// safe inset every frame, and reports once they've held still for a
/// short time. Read-only: it never changes or lays out the hierarchy.
private struct LayoutSettleWatcher: UIViewRepresentable {
    let onSettle: @MainActor () -> Void

    func makeUIView(context _: Context) -> WatcherView {
        let view = WatcherView()
        view.isUserInteractionEnabled = false
        view.onSettle = onSettle
        return view
    }

    func updateUIView(_ view: WatcherView, context _: Context) {
        view.onSettle = onSettle
    }

    final class WatcherView: UIView {
        /// How long the layout must hold still.
        private static let quietPeriod: Double = 0.15
        /// Lift the cover anyway after this long.
        private static let limit: Double = 1

        var onSettle: (@MainActor () -> Void)?
        private var link: CADisplayLink?
        private var startTime: CFTimeInterval = 0
        private var lastChange: CFTimeInterval = 0
        private var lastSignature = ""

        override func didMoveToWindow() {
            super.didMoveToWindow()
            link?.invalidate()
            link = nil
            guard window != nil else { return }
            startTime = CACurrentMediaTime()
            lastChange = startTime
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        @objc private func tick() {
            guard let window else { return }
            let now = CACurrentMediaTime()
            let signature = Self.signature(of: window)
            if signature != lastSignature {
                lastSignature = signature
                lastChange = now
            }
            let hasBars = signature.contains("bar")
            let isQuiet = hasBars && now - lastChange >= Self.quietPeriod
            if isQuiet || now - startTime >= Self.limit {
                link?.invalidate()
                link = nil
                onSettle?()
            }
        }

        private static func signature(of window: UIWindow) -> String {
            var parts: [String] = []
            func collect(in view: UIView) {
                guard !view.isHidden else { return }
                if let bar = view as? UINavigationBar {
                    parts.append("bar\(bar.convert(bar.bounds, to: window))")
                }
                view.subviews.forEach(collect)
            }
            collect(in: window)
            if let content = firstTabBarController(in: window.rootViewController)?
                .selectedViewController?.viewIfLoaded
            {
                parts.append("tab\(content.safeAreaInsets.top)")
            }
            return parts.joined(separator: " ")
        }

        private static func firstTabBarController(in controller: UIViewController?) -> UITabBarController? {
            guard let controller else { return nil }
            if let tabs = controller as? UITabBarController { return tabs }
            for child in controller.children {
                if let tabs = firstTabBarController(in: child) { return tabs }
            }
            return nil
        }
    }
}
