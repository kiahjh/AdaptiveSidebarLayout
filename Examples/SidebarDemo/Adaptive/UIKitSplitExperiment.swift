#if DEBUG
    import SwiftUI
    import UIKit

    /// Experiment (Debug only, `--uikit-split`): the Library built on UIKit's
    /// `UISplitViewController` directly, with our own SwiftUI navigation stacks
    /// in its columns, instead of SwiftUI's `NavigationSplitView` wrapper.
    ///
    /// Questions it answers: does UIKit's split view give the sidebar column the
    /// right insets on iPhone Duo (no rail gap, fold clearance), and does the
    /// launch-time toolbar jump seen with `NavigationSplitView` come back?
    struct UIKitSplitExperimentView: UIViewControllerRepresentable {
        let model: DemoModel

        func makeUIViewController(context: Context) -> UISplitViewController {
            let split = UISplitViewController(style: .doubleColumn)
            split.preferredDisplayMode = .oneBesideSecondary
            split.preferredSplitBehavior = .tile
            split.presentsWithGesture = true
            split.setViewController(UIHostingController(rootView: sidebar(context)), for: .primary)
            split.setViewController(UIHostingController(rootView: detail(context)), for: .secondary)
            split.setViewController(UIHostingController(rootView: compact(context)), for: .compact)
            for column in [UISplitViewController.Column.primary, .secondary, .compact] {
                guard let hosting = split.viewController(for: column) else { continue }
                hosting.view.backgroundColor = .clear
                // The split view wraps each column in its own navigation
                // controller. Our SwiftUI stacks draw the bars, so hide its bar.
                hosting.navigationController?.setNavigationBarHidden(true, animated: false)
            }
            return split
        }

        func updateUIViewController(_ split: UISplitViewController, context: Context) {
            (split.viewController(for: .primary) as? UIHostingController<SidebarRoot>)?.rootView = sidebar(context)
            (split.viewController(for: .secondary) as? UIHostingController<DetailRoot>)?.rootView = detail(context)
            (split.viewController(for: .compact) as? UIHostingController<CompactRoot>)?.rootView = compact(context)
        }

        typealias SidebarRoot = AdaptiveColumnRoot<NavigationStack<NavigationPath, DemoLibraryBrowser>>
        typealias DetailRoot = AdaptiveColumnRoot<DemoDetailColumn>
        typealias CompactRoot = AdaptiveColumnRoot<DemoLibraryBrowser>

        private func sidebar(_ context: Context) -> SidebarRoot {
            AdaptiveColumnRoot(
                content: NavigationStack { DemoLibraryBrowser(model: model, placement: .navigationStack) },
                environment: context.environment
            )
        }

        private func detail(_ context: Context) -> DetailRoot {
            AdaptiveColumnRoot(content: DemoDetailColumn(model: model), environment: context.environment)
        }

        // Compact behavior isn't part of this experiment; a placeholder keeps the
        // split view from collapsing the regular columns into one stack.
        private func compact(_ context: Context) -> CompactRoot {
            AdaptiveColumnRoot(
                content: DemoLibraryBrowser(model: model, placement: .compactStack),
                environment: context.environment
            )
        }
    }
#endif
