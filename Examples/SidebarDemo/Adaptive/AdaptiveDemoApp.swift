import SwiftUI

@main
struct AdaptiveDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoRootView { model in
                AdaptiveLibraryView(model: model)
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
