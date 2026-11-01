@testable import NativeDemo
import Testing
import UIKit

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

struct NativeLaunchCoverTests {
    @Test
    func iPadGetsTheCoverUntilTheLayoutSettles() {
        #expect(NativeLaunchCoverMode.resolve(idiom: .pad, arguments: []) == .untilSettled)
    }

    @Test(arguments: [UIUserInterfaceIdiom.phone, .mac, .unspecified])
    func otherDevicesGetNoCover(idiom: UIUserInterfaceIdiom) {
        #expect(NativeLaunchCoverMode.resolve(idiom: idiom, arguments: []) == nil)
    }

    #if DEBUG
        @Test
        func debugArgumentsOverrideTheDefault() {
            #expect(NativeLaunchCoverMode.resolve(idiom: .pad, arguments: ["--no-launch-cover"]) == nil)
            #expect(NativeLaunchCoverMode.resolve(idiom: .phone, arguments: ["--force-launch-cover"]) == .untilSettled)
            #expect(NativeLaunchCoverMode.resolve(idiom: .phone, arguments: ["--launch-cover=0.3"]) == .fixed(seconds: 0.3))
        }
    #endif
}
