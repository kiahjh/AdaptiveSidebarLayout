import SwiftUI

@main
struct NativeDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoRootView { model in
                NativeLibraryView(model: model)
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

#Preview("Native baseline") {
    DemoRootView { model in
        NativeLibraryView(model: model)
    }
}
