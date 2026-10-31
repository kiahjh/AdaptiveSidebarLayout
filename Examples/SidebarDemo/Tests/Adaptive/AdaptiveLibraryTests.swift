@testable import AdaptiveDemo
import SwiftUI
import Testing
import UIKit

struct AdaptiveLibraryModeTests {
    let metrics = AdaptiveLibraryMetrics()

    @Test(arguments: [1366, 1024, 920] as [CGFloat])
    func wideRegularWidthsShowBothColumns(width: CGFloat) {
        #expect(metrics.mode(width: width, horizontalSizeClass: .regular) == .sideBySide)
    }

    @Test(arguments: [919, 817, 700, 520] as [CGFloat])
    func mediumRegularWidthsUseTheOverlay(width: CGFloat) {
        #expect(metrics.mode(width: width, horizontalSizeClass: .regular) == .overlay)
    }

    @Test(arguments: [519, 402, 320] as [CGFloat])
    func narrowWidthsUseOneStack(width: CGFloat) {
        #expect(metrics.mode(width: width, horizontalSizeClass: .regular) == .stack)
    }

    @Test
    func compactSizeClassAlwaysUsesOneStack() {
        // Follows the system even when the width alone would allow columns,
        // so the Library agrees with the tab bar's compact placement.
        #expect(metrics.mode(width: 1024, horizontalSizeClass: .compact) == .stack)
    }

    @Test
    func thresholdsFollowCustomMetrics() {
        let narrow = AdaptiveLibraryMetrics(sidebarWidth: 300, minimumDetailWidth: 400, minimumOverlayMargin: 80)
        #expect(narrow.mode(width: 700, horizontalSizeClass: .regular) == .sideBySide)
        #expect(narrow.mode(width: 699, horizontalSizeClass: .regular) == .overlay)
        #expect(narrow.mode(width: 379, horizontalSizeClass: .regular) == .stack)
    }

    @Test
    func debugOverrideNamesMatchEveryMode() {
        #expect(AdaptiveLibraryMode.allCases.map(\.rawValue) == ["side-by-side", "overlay", "stack"])
    }
}

struct AdaptiveLibraryEngineTests {
    @Test
    func phonesUseTheSystemSplitView() {
        #expect(AdaptiveLibraryEngine.resolve(idiom: .phone, arguments: []) == .system)
    }

    @Test(arguments: [UIUserInterfaceIdiom.pad, .mac, .unspecified])
    func otherDevicesUseTheCustomLayout(idiom: UIUserInterfaceIdiom) {
        #expect(AdaptiveLibraryEngine.resolve(idiom: idiom, arguments: []) == .custom)
    }

    #if DEBUG
        @Test
        func debugArgumentsCanForceEitherEngine() {
            #expect(AdaptiveLibraryEngine.resolve(idiom: .phone, arguments: ["--force-custom-layout"]) == .custom)
            #expect(AdaptiveLibraryEngine.resolve(idiom: .pad, arguments: ["--force-system-split"]) == .system)
        }
    #endif
}

@MainActor
struct AdaptiveLibraryStackPathTests {
    @Test
    func emptyWithoutASelection() {
        #expect(DemoModel().stackPath.isEmpty)
    }

    @Test
    func columnStateBecomesOneStack() {
        let model = DemoModel()
        model.selectCollection(3)
        model.detailPath = [5, 7]
        #expect(model.stackPath == [3, 5, 7])
    }

    @Test
    func pushingAndPoppingUpdatesTheColumnState() {
        let model = DemoModel()
        model.stackPath = [3]
        #expect(model.selectedCollectionID == 3)
        #expect(model.detailPath.isEmpty)

        model.stackPath = [3, 5]
        #expect(model.selectedCollectionID == 3)
        #expect(model.detailPath == [5])

        model.stackPath = [3]
        #expect(model.detailPath.isEmpty)
    }

    @Test
    func returningToTheListClearsTheSelection() {
        let model = DemoModel()
        model.stackPath = [3, 5]
        model.stackPath = []
        #expect(model.selectedCollectionID == nil)
        #expect(model.detailPath.isEmpty)
    }
}
