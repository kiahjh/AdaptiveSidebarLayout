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
            .modifier(NativeLaunchCover(mode: .resolve(
                idiom: UIDevice.current.userInterfaceIdiom,
                arguments: ProcessInfo.processInfo.arguments
            )))
        }
    }
}

#Preview("Native baseline") {
    DemoRootView { model in
        NativeLibraryView(model: model)
    }
}
