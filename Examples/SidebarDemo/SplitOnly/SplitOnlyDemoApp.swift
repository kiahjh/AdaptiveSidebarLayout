import SwiftUI

@main
struct SplitOnlyDemoApp: App {
    var body: some Scene {
        WindowGroup {
            SplitOnlyRootView()
        }
    }
}

private struct SplitOnlyRootView: View {
    @State private var model = DemoModel()

    var body: some View {
        NativeLibraryView(model: model, extendsContainerToTop: false)
            .tint(.indigo)
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

#Preview("Split only") {
    SplitOnlyRootView()
}
