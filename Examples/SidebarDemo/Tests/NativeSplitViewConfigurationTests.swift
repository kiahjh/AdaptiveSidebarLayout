@testable import NativeDemo
import Testing

struct NativeSplitViewConfigurationTests {
    @Test
    @MainActor
    func normalLaunchUsesTheTopEdgeFix() {
        let library = NativeLibraryView(model: DemoModel())
        #expect(NativeSplitViewConfiguration.resolve(
            extendsContainerToTop: library.extendsContainerToTop,
            arguments: []
        ) == .topExtended)
    }

    @Test
    @MainActor
    func nativeLibraryDefaultsToTheSplitViewSidebarPlacement() {
        #expect(DemoLibraryBrowser(model: DemoModel()).placement == .splitViewSidebar)
    }

    @Test
    func standaloneControlCanKeepSystemInsets() {
        #expect(NativeSplitViewConfiguration.resolve(
            extendsContainerToTop: false,
            arguments: []
        ) == .system)
    }

    #if DEBUG
        @Test
        func originalInsetsOptionTakesPrecedenceOverTrialOptions() {
            #expect(NativeSplitViewConfiguration.resolve(
                extendsContainerToTop: true,
                arguments: ["--system-split-insets", "--extend-split-to-top", "--extend-split-background"]
            ) == .system)
        }

        @Test
        func mirroredBackgroundRemainsAnExplicitSeparateTrial() {
            #expect(NativeSplitViewConfiguration.resolve(
                extendsContainerToTop: true,
                arguments: ["--extend-split-background"]
            ) == .mirroredBackground)
        }

        @Test
        func legacyTopEdgeOptionStillOverridesTheBackgroundTrial() {
            #expect(NativeSplitViewConfiguration.resolve(
                extendsContainerToTop: false,
                arguments: ["--extend-split-to-top", "--extend-split-background"]
            ) == .topExtended)
        }
    #endif
}
