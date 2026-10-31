import SwiftUI

@main
struct AdaptiveDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoRootView { model in
                #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--uikit-split") {
                        // Fills the tab like the native split view, which
                        // manages its columns' safe areas itself.
                        UIKitSplitExperimentView(model: model)
                            .ignoresSafeArea(.container)
                    } else {
                        AdaptiveLibraryView(model: model)
                    }
                #else
                    AdaptiveLibraryView(model: model)
                #endif
            }
            .background {
                #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--inspect-native-layout") {
                        NativeLayoutProbe()
                            .frame(width: 0, height: 0)
                    }
                #endif
            }
        }
    }
}

#Preview("Custom layout, step 1") {
    DemoRootView { model in
        AdaptiveLibraryView(model: model)
    }
}
