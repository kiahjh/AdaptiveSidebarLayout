import SwiftUI

struct NativeLibraryView: View {
    @Bindable var model: DemoModel
    var extendsContainerToTop = true
    @State private var columnVisibility: NavigationSplitViewVisibility = {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--show-sidebar") {
                return .all
            }
        #endif
        return .automatic
    }()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DemoLibraryBrowser(model: model)
                .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 600)
        } detail: {
            DemoDetailColumn(model: model)
        }
        .navigationSplitViewStyle(.balanced)
        .modifier(NativeSplitViewContainerStyle(configuration: containerConfiguration))
    }

    private var containerConfiguration: NativeSplitViewConfiguration {
        .resolve(
            extendsContainerToTop: extendsContainerToTop,
            arguments: ProcessInfo.processInfo.arguments
        )
    }
}

enum NativeSplitViewConfiguration: Equatable {
    case system
    case topExtended
    case mirroredBackground

    static func resolve(extendsContainerToTop: Bool, arguments: [String]) -> Self {
        #if DEBUG
            if arguments.contains("--system-split-insets") { return .system }
            if arguments.contains("--extend-split-to-top") { return .topExtended }
            if arguments.contains("--extend-split-background") { return .mirroredBackground }
        #endif
        return extendsContainerToTop ? .topExtended : .system
    }
}

private struct NativeSplitViewContainerStyle: ViewModifier {
    let configuration: NativeSplitViewConfiguration

    func body(content: Content) -> some View {
        switch configuration {
        case .system:
            content
        case .topExtended:
            content.ignoresSafeArea(.container, edges: .top)
        case .mirroredBackground:
            content.backgroundExtensionEffect()
        }
    }
}
