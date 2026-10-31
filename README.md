# AdaptiveSidebarLayout

An experiment in adaptive sidebar layouts that compose with native SwiftUI tabs and navigation stacks.

Native Demo uses native SwiftUI navigation with a scoped top-edge container fix, now enabled by default. The original inset behavior remains available as a debug-only comparison option.

**Custom layout:** the **Adaptive Demo** scheme runs a separate app with the same content, tabs and accessory. Its Library tab uses plain navigation stacks instead of `NavigationSplitView` and adapts to the width it gets: side by side when wide (with a collapsible sidebar), a slide-over sidebar at medium widths, and a single stack on iPhone, folded Duo and narrow windows. In paired cold launches, its toolbars stayed in place from the first reading, while Native Demo's moved 64 points every time. See [the custom layout notes](Examples/SidebarDemo/CustomLayout.md).

**Known stability failure:** subsequent manual testing found intermittent excessive top spacing on launch, sometimes persistent until resizing and sometimes briefly visible before correcting itself. The top-edge change addresses the measured background/dimming gap, but is **not a complete, validated layout solution**. See [the investigation record](Examples/SidebarDemo/BackgroundInvestigation.md#cold-launch-stability-failure-after-default-build).

## Run the native demo

1. Open `Examples/SidebarDemo/SidebarDemo.xcodeproj` in Xcode 26 or newer.
2. Select the **Native Demo** scheme and an iPad, iPhone, or iPhone Duo simulator available in your Xcode installation.
3. Run the app. No signing team is needed for the simulator; choose your own team to run on a physical device.

The example requires iOS/iPadOS 26 or newer to exercise the native `tabViewBottomAccessory` API. This is the example app's deployment target, not a decision about the future package's minimum supported OS.

All content is local and deterministic. Playback is simulated: no audio, account, network connection, or permissions are required.

### Default layout and cold launches

Native Demo now applies this modifier to the **Library split-view container**, in both Debug and Release builds:

```swift
.ignoresSafeArea(.container, edges: .top)
```

No launch flag is needed. Closing the app and reopening it from the Home Screen keeps the top-extended configuration; this does not guarantee correct initial toolbar positioning (see the known failure above). Tabs, Queue, the Library List, keyboard avoidance, and the bottom safe area do not receive this modifier. The normal app uses native automatic column visibility and includes the bottom accessory; it does not enable the mirrored background-extension effect or diagnostics.

For an unmodified-insets comparison in a Debug build, launch with `--system-split-insets`. Other optional investigation arguments are documented below. Do not leave comparison arguments enabled while testing the normal default build.

## What the native demo contains

- A native `TabView` with Library and Queue tabs.
- A native `NavigationSplitView` inside Library, with a searchable sidebar and a detail `NavigationStack`.
- A normal `NavigationStack` inside Queue.
- One native tab-view bottom accessory with simulated play/pause and next-track controls.
- Twenty-four sample collections, each containing eight tracks.
- Native column adaptation and sidebar controls, plus the scoped top-edge container fix above. No hard-coded inset compensation, layout-refresh tricks, or custom sidebar implementation.

## Compare these behaviors

These are observation scenarios, not claims that the native implementation is defective on every OS or device.

- **Cold launch:** inspect the sidebar toggle, tab bar, and detail toolbar before resizing anything.
- **Sidebar visibility:** open and close the sidebar using the system's controls; watch its background and content together.
- **Window resizing:** resize an iPad window from wide to narrow and back; compare initial and settled toolbar positions.
- **Tab switching:** select a collection, navigate to another collection using the detail links, then visit Queue and return to Library.
- **Search:** search for a collection or artist, open a result, and clear the query.
- **Compact navigation:** on iPhone or a narrow iPad window, select a collection and navigate back using the native controls.
- **Simulated playback:** tap a track, then use the bottom accessory and verify Queue reflects the same state.
- **Safe areas and keyboard:** check window controls, status bars, device cutouts, the home indicator, search focus, and keyboard dismissal in portrait and landscape.
- **iPad transitions:** check wide side-by-side columns, the intermediate overlay sidebar and its dimming/dismissal, compact stack navigation, and repeated resizing between them. Include floating, display-edge-touching, and full-screen windows.
- **Duo:** exercise the simulator's available fold states, postures, and rotations while retaining a selection and a deeper detail navigation path. This app still uses native adaptation only; no custom fold-geometry handling has been added or claimed as validated.

The **Reset demo** toolbar action restores the sample data and navigation state. It does not recreate the native view controllers; relaunch the app when checking cold-launch behavior.

## Safe Area Explorer

The **Safe Area Explorer** scheme runs a separate diagnostic app (`dev.adaptivesidebarlayout.demo.safearea`), leaving Native Demo unchanged. It has no tabs, navigation bars, split views, or bottom accessory.

- **Respect safe area:** a bright pink `Rectangle` uses the root's normal layout proposal.
- **Ignore safe area:** the same rectangle applies `.ignoresSafeArea(.container)` on all edges.
- A **cyan background** explicitly ignores container safe areas in both modes. It makes any region the pink rectangle does not cover easy to identify.
- An optional **yellow outline** marks the original safe-content bounds. The diagnostic controls always remain within those bounds.
- Live readings show the original SwiftUI root geometry, the pink rectangle's geometry, the actual scene's `UIWindow` bounds/insets, and its root view controller's frame/insets. The UIKit probe is read-only and updates on layout/safe-area changes, not a polling timer.

Compare both modes with the window **away from the display's top**, **touching the top**, and **full screen**, without changing its size between the two modes. Capture the top edge and the readings in each screenshot. All readings are in points, not screenshot pixels. The SwiftUI `.global` coordinate space is not a promise of physical screen coordinates.

For repeatable launch checks without UI automation, the explorer also accepts `--ignore-safe-area` as a launch argument to start in Ignore mode. Without it, the initial mode is Respect. The on-screen picker works in either case.

If a top strip is cyan in Respect mode and pink in Ignore mode, this bare app can draw into it; the inset is not inherently an undrawable part of the window. If neither color reaches it, compare window/root geometry and inspect the hierarchy before deciding that the region is system-owned. This experiment alone does not establish why a nested split view leaves a strip, nor prove a fix for it.

Safe areas are not only hardware cutouts: they also account for system and container UI. Extending a **background** into a safe area is different from putting interactive controls there. SwiftUI's `background(_:ignoresSafeAreaEdges:)` ignores all safe-area edges by default, so this experiment uses an explicit shape rather than relying on that background overload for the pink test view.

References: [UIKit safe-area insets](https://developer.apple.com/documentation/uikit/uiview/safeareainsets), [SwiftUI safe-area regions](https://developer.apple.com/documentation/swiftui/safearearegions), and [SwiftUI background defaults](https://developer.apple.com/documentation/swiftui/view/background(_:ignoressafeareaedges:)).

### Observations

On October 30, 2026, the iPad Air 13-inch (M4) simulator running iPadOS 27.0 produced these readings in a floating window away from the display's top. The two modes were launched separately, with the same restored window size and position:

| Reading | Respect mode | Ignore mode |
| --- | --- | --- |
| Root SwiftUI / UIWindow safe insets (T/L/B/R) | 10 / 0 / 10 / 0 | 10 / 0 / 10 / 0 |
| Pink rectangle safe insets (T/L/B/R) | 10 / 0 / 10 / 0 | 0 / 0 / 0 / 0 |
| Pink rectangle frame in SwiftUI global coordinates (x/y/w/h) | 0 / 10 / 772 / 1005 | 0 / 0 / 772 / 1025 |
| Color at the window's top and bottom edges | Cyan | Pink |

The bare app can therefore draw into the floating window's thin top strip. Ignoring the safe area for the rectangle does not remove or change the window's safe insets. This does **not** yet identify which part of the native Library composition controls its sidebar background, or establish the correct native styling change.

An earlier full-screen Respect-mode snapshot reported a **32-point top inset and 20-point bottom inset**, with cyan visible behind the top status strip and at the bottom. That was not a controlled window-position comparison. Repeat the paired comparison in full screen and with the floating window touching the display's top. All readings are observations, not constants to use in layout code.

## Split Only Demo: native split view without tabs

The **Split Only Demo** scheme runs a separate app (`dev.adaptivesidebarlayout.demo.splitonly`) that shows the **same `NativeLibraryView` directly as its root**. It reuses the original data, model, Library content, native navigation stacks, column widths, balanced split-view style, and indigo tint. It has no `TabView` or bottom accessory, and introduces no background styling or safe-area overrides. Native Demo remains a separate app so both can be installed and compared side by side.

Run the new scheme on the same iPad simulator. Split Only Demo explicitly keeps the original system-insets configuration rather than applying Native Demo's default top-edge fix. The optional debug arguments `--show-sidebar` and `--inspect-native-layout` work in both apps. To reproduce the original tab/split comparison, also pass `--system-split-insets` to Native Demo. Do **not** pass `--extend-split-background` to either app for this comparison.

Compare the apps with matched window sizes and positions: floating away from the display's edges, touching the display's top, and full screen. Inspect the actual top background and read-only hierarchy captures rather than relying on the appearance of the extension trial's darker band. Removing the tab-owned accessory also changes bottom-area behavior; that is an intentional difference, not an isolated test of only the tab bar.

The user has visually confirmed edge-to-edge sidebar backgrounds in both full-screen and floating-window versions of this control app. It is diagnostic only: the intended app navigation remains native Library/Queue tabs. The accessory-only control below further isolates the tab/split composition; these results are not a claim of a universal framework defect.

## Native background investigation

A real-window hierarchy capture of the original tabbed configuration confirmed that its hosting view reaches the window's top, but the split-view controller starts at the ten-point top inset. The now-default container fix makes the real split view and dimming layer fill the window while retaining their native safe insets. Column-only background configurations did not solve the strip. A whole-split background-extension effect filled it, but the user's screen recording showed undesirable blurred, mirrored rows beneath the playback accessory while scrolling. An earlier claim of artwork-symbol clipping was a mistaken screenshot reading and has been withdrawn. The mirrored effect remains available only as an explicit Debug trial with `--extend-split-background`; it is not combined with the default fix.

See [the investigation record](Examples/SidebarDemo/BackgroundInvestigation.md) for measurements, exact trial snippets, limitations, and the optional debug-only comparison arguments. The adopted change affects only the split container's top edge; no UIKit layout mutation or custom sidebar was adopted. Broader device and interaction testing is still in progress.

### Accessory-only control

To reproduce the original accessory-isolation test, launch **Native Demo** with `--system-split-insets --without-accessory --show-sidebar --inspect-native-layout`. This retains both tabs and the identical Library split view while omitting the `tabViewBottomAccessory` modifier entirely. It is a debug-only diagnostic option; the standard launch still has its accessory. Do not pass `--extend-split-background` during this test.

Compare with a second Native Demo launch using `--system-split-insets --show-sidebar --inspect-native-layout`, at the same window size and position. This isolates the accessory from the tab/split composition without introducing a different app window or changing tab behavior. Inspect the top edge and compare the captured window, tab-content, and split-controller frames/insets. The expected absence of the bottom accessory is not itself evidence that the top gap changes.

In the paired floating-window check, removing the accessory changed the tab content's bottom safe inset from `62` to `10` points, but the split-controller frame still began at `y = 10` in both launches and the top strip remained. The accessory is not the source of that reproduced top gap; see the investigation record for the full measurements.

### Tab-bar minimization control

The Debug-only `--without-tab-minimization` argument omits `.tabBarMinimizeBehavior(.onScrollDown)` entirely. It does **not** hide tabs, remove the player accessory, or disable opening/closing the sidebar. Without that explicit modifier, tab minimization is left to the system default; this flag is a layout-isolation control, not a new navigation policy.

Compare `--inspect-native-layout` with `--inspect-native-layout --without-tab-minimization`, leaving all other configuration unchanged. In three full-screen iPad launch pairs, both configurations produced the same early extra `64`-point top inset and the same later corrected inset. A separate `.never` comparison also showed no improvement. All measured launches had corrected by the later snapshot; the earlier persistent-until-resize failure did not recur during these runs. This is not a native stability fix. Normal Debug/Release launches still use `.onScrollDown`; this diagnostic must be explicitly supplied again after a fresh launch.

### Native container-bounds fix and comparison options

The top-edge container change is now Native Demo's default. The old `--extend-split-to-top` argument remains as a debug-only compatibility option but is no longer required. `--system-split-insets` restores the original behavior, and `--extend-split-background` selects the old mirrored-background trial instead of the fix. An explicit system-insets opt-out takes precedence over trial flags; the legacy top-edge flag otherwise takes precedence over the mirrored trial. Release builds ignore all these comparison flags and always use the fixed Native Demo configuration.

Compare `--system-split-insets --show-sidebar --inspect-native-layout` with `--show-sidebar --inspect-native-layout`, keeping the accessory present in both and not enabling `--extend-split-background`. A disappearing strip alone is insufficient: native navigation controls, search, dimming, dismissal, compact adaptation, and the accessory must still behave correctly with the real window safe areas.

The first paired check in a `749 × 899` floating window using the native overlay sidebar was promising: the split controller and dimming layer changed from `y = 10` to `y = 0`, while the split retained the real ten-point top safe inset. Both navigation bars, the search field, and the accessory kept their measured window positions. After positive manual review, the user requested this as the default for rigorous iPad, iPhone, and Duo testing. Subsequent testing **failed cold-launch layout stability**: excessive top spacing can remain until resizing. The configuration remains installed for investigation, not as a claim that native layout is now reliable.

## Project structure

```text
Examples/SidebarDemo/
  Shared/                 Sample data, state, app shell, and content views
  Native/                 Native app entry point, split-view implementation, and layout probe
  Adaptive/               Custom Library layout app (same shell and content)
  SplitOnly/              Diagnostic app entry point without tabs or accessory
  Diagnostics/            Independent Safe Area Explorer app and read-only probe
  Tests/                  Shared demo-model tests
  SidebarDemo.xcodeproj/   Checked-in Xcode project
  project.yml             XcodeGen project specification
```

The shared app shell accepts a Library view builder. Adaptive Demo reuses the same content, state, tabs, and bottom accessory while replacing only the Library layout. There is no package yet; that comes once the layout's behavior is settled.

## Tests and project maintenance

Run the **Native Demo** scheme's tests with Product → Test in Xcode. These tests cover the deterministic data, navigation/playback model, and default/debug layout-configuration selection; they do not verify native layout, scrolling, focus, or animation.

The Xcode project is checked in, so XcodeGen is not needed to run the demo. If you change the project specification, regenerate it from the repository root with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate --spec Examples/SidebarDemo/project.yml
```

Side-by-side recordings and README demos will follow once there is a custom implementation to compare against the baseline.
