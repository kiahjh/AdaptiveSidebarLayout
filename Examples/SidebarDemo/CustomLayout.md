# Custom Library layout

The **Adaptive Demo** app (`dev.adaptivesidebarlayout.demo.adaptive`) uses the same data, model, tabs, playback accessory and Library content as Native Demo. Only the Library tab's layout differs. Native Demo stays the reference.

## Step 1: two plain navigation stacks

`AdaptiveLibraryView` places two ordinary `NavigationStack`s side by side in an `HStack`: a 420-point sidebar (the native sidebar's ideal width) and the shared detail column. There is no `NavigationSplitView`, no safe-area override, and no adaptation yet. It always shows both columns, so **it's for regular-width iPad windows only**; iPhone and narrow windows come in step 2.

Shared-content changes made for this step:

- `DemoLibraryBrowser` gained a `placement` setting. Native Demo keeps the default, `.splitViewSidebar`: `NavigationLink` rows, which `NavigationSplitView` turns into sidebar selection, and automatic search placement. The custom layout uses `.navigationStack`: the same row view, tagged and driven by the list's selection binding, and search placed explicitly with `.navigationBarDrawer(displayMode: .always)`. A test guards the native default.
- The detail stack moved into a shared `DemoDetailColumn`, used unchanged by both apps.

### Search placement fix

In a `NavigationSplitView` sidebar, automatic search placement puts the field under the title. In a plain stack on iPad, the same automatic placement puts it in the toolbar. In that toolbar mode, focusing the field also pushed the title against the column's left edge with no margin (reported by the user). The custom layout now asks for the under-title drawer explicitly, with `.always` so it doesn't start hidden. That removed the margin glitch. (A hidden-until-pulled trial was tried and reverted; see "Large title starts collapsed".)

Checked with the Debug-only `--present-search` argument, which opens search when the Library appears, so focused states can be captured without UI automation. Programmatic presentation may not match a real tap in every detail.

| State | Native sidebar | Custom sidebar |
| --- | --- | --- |
| Idle | Small title; search field at `y = 140`, under the toolbar row | Same arrangement; field at `y = 150` (the toolbars sit 10 points lower) |
| Search open | Title and buttons stay; field stays below them | Field moves up into the toolbar row; title and reset button hide |

The search-open difference is standard `NavigationStack` search behavior, and SwiftUI doesn't expose a setting to keep the title. In six further cold launches (three each), both apps showed the small title with the field below it. One custom launch, the first after a fresh install, showed a large title instead; that hasn't been investigated.

A two-pair rerun of the launch comparison after this change matched the original result: custom bars stayed in place from the first reading, while native moved 64 points.

### Launch comparison

The question was whether the native app's launch-time top offset also occurs without `NavigationSplitView`.

Four alternating pairs of cold launches on the iPad Air 13-inch (M4) simulator, iPadOS 27.0, full screen (`1024 × 1366`, window top inset `32`), with `--inspect-native-layout` only. Both apps were terminated before each launch, and the order alternated between pairs. The probe recorded a timestamped summary from its first reading, about 0.8 seconds after process start, through 8 seconds.

| App | Launches | First reading | Later readings |
| --- | --- | --- | --- |
| Native Demo | 4 | Tab content top inset `96`; detail bar at `y = 150` | Inset `32`; bar at `y = 86`, within `0.09`–`0.10` s, all 4 launches |
| Adaptive Demo | 4 | Tab content top inset `96`; both bars at `y = 96` | Unchanged through 8 s, all 4 launches |

**Result: the custom layout's toolbars were stable from the first reading in every launch; the native layout moved 64 points in every launch.** A 10 fps screen recording agrees. In these runs the native jump happened during the launch fade-in, so it was not visible at that frame rate. The earlier persistent-until-resize native failure did not recur in this batch.

The two layouts settle in different ways. In the native split view, the tab content's top inset drops from `96` to `32` once the split view takes over the tab-bar spacing. With plain stacks, the tab content keeps `96` (window inset plus the floating tab bar) and the navigation bars sit below the tab bar from the start. That is the system's normal tab-plus-stack layout, not an adjustment made by this demo.

Limits: this is one simulator and OS, one window state, sidebar column always visible, and no collection selected. The timeline starts at the probe's first reading. Anything rendered before then was not measured, although the recording shows nothing different.

### Large title starts collapsed

The user reported that the sidebar opens with the small, centered title and only shows the large title after the list is pulled down. Native Demo starts the same way. The probe's scroll readings show the list is **at its top** at launch (offset `-204` with a `204`-point top inset), so this isn't a scroll-position problem: the navigation bar itself starts collapsed. `.defaultScrollAnchor(.top, for: .initialOffset)` therefore made no difference and was removed. A fresh reinstall also started collapsed in 3 of 3 launches.

The trigger was the always-visible search drawer. As a trial, `.navigationBarDrawer(displayMode: .automatic)` (search hidden until the list is pulled down) plus a `magnifyingglass` toolbar button showed the large title from the first reading in 5 of 5 cold launches (sidebar bar height `106`, versus `108` for the collapsed title plus search).

**Decision:** after trying it, the user preferred the always-visible search field and accepted the small title at launch, matching Native Demo. The trial was reverted: the drawer is back to `.always` and the search button was removed.

### Step 2a: collapsible sidebar

The sidebar can now be hidden and shown:

- A `sidebar.left` button with native's ⌃⌘S shortcut. It sits in the sidebar's toolbar while the sidebar is shown and in the detail column's leading toolbar position while it's hidden, the same places native uses. It stays on pushed detail screens too.
- The sidebar slides out to the left over 0.35 seconds while the detail column widens.
- The hidden sidebar stays in the view hierarchy, offset off screen, so its scroll position and navigation state survive. It ignores touches and is hidden from accessibility while off screen.
- Debug-only `--hide-sidebar` starts with it hidden, for captures.

Both states were checked by screenshot. The animation itself hasn't been reviewed yet. Native Demo is unchanged: the new toggle parameters on the shared views default to `nil`.

### Step 2b: adapting to width

`AdaptiveLibraryView` reads the width it actually gets (a `GeometryReader`, so the mode is known in the first layout pass) and picks one of three modes. `AdaptiveLibraryMetrics.mode(width:horizontalSizeClass:)` holds the rules, with the defaults below:

| Mode | When | Behavior |
| --- | --- | --- |
| Side by side | width ≥ 920 (sidebar 420 + detail 500) | Step 2a's layout: both columns; the sidebar can be hidden and starts shown. |
| Overlay | 520 ≤ width < 920 | Detail fills the width. The sidebar starts hidden and slides over the detail with 20% dimming and a shadow. Tapping the dimming, the sidebar button, or choosing a collection hides it. VoiceOver gets a "Hide Sidebar" action on the dimming and an escape gesture on the sidebar. |
| Stack | compact size class, or width < 520 | One `NavigationStack`: the Library list, with the collection and deeper links pushed on top. |

- Side by side and overlay share one view structure, so moving between them keeps the sidebar's scroll position and the detail's navigation stack.
- The stack's path is derived from the shared model (`stackPath` = selected collection + detail path). A selection and deeper navigation carry over between widths. Going back to the list clears the selection, as the native split view does when collapsed.
- Stack-mode rows are push links with no list selection (new `.compactStack` placement), so a tap can't both select and push.
- A compact size class always uses the stack, so the Library agrees with the system's bottom tab bar.
- An overlay left open is closed when the window leaves overlay mode, so it doesn't reappear unexpectedly.

New tests (`AdaptiveDemoTests`, run with the Adaptive Demo scheme) cover the thresholds, the compact rule, custom metrics, and the stack path's push/pop/clear behavior. All pass, as do Native Demo's 14.

Checked by cold launch and screenshot, with the layout timeline (no navigation bar moved after the first reading in any launch, except the deliberate overlay close noted below):

- **iPad, floating 746-wide window:** overlay mode with the sidebar hidden, with and without a selected collection.
- **iPad, full screen 1024 (forced with the Debug `--library-layout=` flag):** overlay open and closed, side by side with the sidebar hidden, and stack with a pushed collection.
- **iPhone 18 Pro (402 wide):** stack, list and pushed collection; bottom tab bar and accessory.
- **iPhone Duo, folded (466 wide, iOS 27.1):** stack with a pushed collection. The Duo places the status bar, back button and tabs in a rail along the right edge; that's system layout. The unfolded state wasn't reachable from the command line.

Not yet checked: live resizing between modes and its animation, rotation, the unfolded Duo, and real taps on the dimming and sidebar button in overlay mode. Combining `--show-sidebar` with `--select-collection` closes the overlay right away, because choosing a collection is meant to.

### Step 3a: keeping the Library's place across modes

Previously the stack mode built its own Library list, so entering or leaving it scrolled the list back to the top. Now all three modes share one structure: the Library's navigation stack is the sidebar in the column modes and is widened to become the whole Library in the stack mode. Only the detail column is added or removed. The list's rows are also identical in both custom placements (the stack mode adds a chevron), so switching doesn't rebuild them. Tapping a row selects it; in the stack mode the selection itself pushes the collection, through the shared `stackPath`.

Checked on the iPad simulator with Debug-only `--scroll-library-to=12` and `--library-layout-schedule=stack,overlay,stack,side-by-side` (switches modes every 3 seconds): the list kept its place through every switch, apart from one row of movement on the first switch (Collection 12 at the top became Collection 11). That's probably because the jump straight to row 12 left the rows above unmeasured, so their heights were only estimates. Normal scrolling measures them; watch for any shift during manual testing. Before this change the list returned to the top.

Checked on iPhone 18 Pro with real taps through Xcode's device-interaction tools: tapping a row pushes the collection; Back returns to the list with no row left highlighted; tapping the same row again pushes again. Swipe-back wasn't exercised.

### Step 3b: iPhone Duo's vertical bar (rail)

The user found that on the unfolded Duo there was no sidebar and no button to open it. Unfolded in landscape, the window is 951 × 669 with an 84-point rail on the trailing edge, so the layout gets 867 points and uses the overlay mode, sidebar closed.

The rail is UIKit's **vertical bar** (iOS 27.1, `UIVerticalBarEdge`, `preferredVerticalBarBehavior`). Besides the status bar and tabs, it shows *one* navigation stack's toolbar items, and a full-width stack's horizontal bar collapses to zero height. Reproduced with Debug `--sidebar-schedule=show,hide`:

1. Fresh launch, sidebar closed: the detail's show-sidebar button appears in the rail.
2. Sidebar opened: the rail switches to the sidebar's items (reset and hide).
3. Sidebar closed again: the rail keeps showing the sidebar's items, minus the hide button. The detail's show-sidebar button never returns, so the sidebar can't be reopened.

Native's split view, by contrast, keeps its column toolbars horizontal (sidebar button at top left) and leaves the rail to the status bar and tabs.

**Fix:** toolbar items in the column modes use SwiftUI's new `axisBehavior(.horizontalOnly)` (iOS 27.1+, via a `keepsHorizontalBar(_:)` helper that does nothing on earlier versions). They stay in their own column's toolbar, as in native. Verified on the unfolded Duo across closed → open → closed → open: the sidebar button is at the top left when closed, the sidebar's buttons are in its own toolbar when open, and the rail holds only the status bar and tabs. The stack mode keeps automatic placement, so a full-width stack still uses the rail like any system stack.

For the package: the sidebar's *content* can add its own toolbar items, which would face the same problem unless they also opt out of the vertical bar. The layout may need to apply this to its columns automatically, or document it.

Taps on the Duo's inner display didn't register through Xcode's device-interaction tools (taps on iPhone did), so these checks used the schedule flag instead of real taps.

Also fixed: the overlay's dimming layer was exposed to VoiceOver as a "Hide Sidebar" button even with no overlay open. It now exists only while the overlay is showing. And toolbar buttons (sidebar, reset) use the primary color instead of the indigo accent, matching native's sidebar button (user request).

### Step 3c: unfolded Duo should split at the fold (in progress)

The user compared the apps on the unfolded Duo and found three differences that the step 3b check missed. That check only confirmed the sidebar button worked, against a native screenshot with the sidebar closed. From here on, every check compares native and custom in the same device and state, side by side.

Native, measured on the unfolded Duo (951 × 669 window, 84-point rail on the right):

- **Starts with the sidebar hidden**; when shown, the columns are **side by side, split at the fold**, not a slide-over. The sidebar is 475.7 points wide (half the window) and ignores the 420-point ideal width.
- **Fold clearance:** the sidebar's trailing safe inset is 20 and the detail's leading safe inset is 495.7 (fold + 20). The sidebar gets no rail inset.
- **Title and search:** the large title sits below the toolbar buttons and the search field starts hidden (zero height).

The fold comes from SwiftUI's new `GeometryProxy.reservedRegions(kind: .division)` (iOS 27.1; UIKit `UIView.reservedRegions`, `UIViewReservedRegionKind.divisionRegionKind`). On the Duo it reports one active region, frame `(455.5, 0, 40, 669)` with 20-point margins on each side, so the fold is at 475.5, matching native.

Done so far:

- `AdaptiveLibraryFold.find(in:)` reads the first active, full-height, vertical division region. `AdaptiveLibraryMetrics.columns(width:horizontalSizeClass:fold:)` puts the sidebar on one side of the fold and the detail on the other (each side at least 300 points), regardless of the width thresholds. Verified on the Duo: sidebar 475.5 points, side by side.
- The sidebar no longer inherits the window's trailing safe area at the SwiftUI level (`ignoresSafeArea(.container, edges: .trailing)` in the column modes), and each column asks for the fold's 20-point clearance with `safeAreaPadding`.

Not fixed yet:

- **84-point gap inside the sidebar.** UIKit adds the rail's width to the content of the sidebar's navigation stack even though the stack is nowhere near the rail: the sidebar's `UINavigationController` reports trailing inset 0, but its root hosting controller reports 84. SwiftUI modifiers outside the stack can't remove it, and the fold clearance from `safeAreaPadding` doesn't reach the UIKit-hosted stack either. Native avoids this because `UISplitViewController` manages its columns' insets. Fixing it likely needs the layout to host its columns in a small UIKit container it owns, or a SwiftUI API not yet found; that's a design decision for the user.
- **Title and search placement** differ (see above). Native's iPad sidebar starts with a small title and visible search, while its Duo sidebar starts with a large title and hidden search. The custom layout always shows search, per the user's earlier choice.
- **Initial visibility:** native starts with the sidebar hidden on the Duo; the custom layout shows it.

Debug: with `--inspect-native-layout`, Adaptive Demo also writes `Documents/library-columns.txt` with the division regions, the fold and the resolved columns.

### Experiment: UIKit's split view with our stacks (`--uikit-split`)

Why the sidebar keeps the rail's 84 points: each navigation stack reserves the rail's width when its trait collection says the vertical bar is on its trailing edge (`verticalBarEdge == .trailing`). Every controller in the custom layout reports that. In the native split view, the sidebar column reports `verticalBarEdge == .unspecified` (the split view sets this through private traits, `_UITraitVerticalBarAllowed`), so its content gets only the 20-point fold clearance. Overriding `preferredVerticalBarBehavior` on a column's hosting controller doesn't change the trait.

The Debug-only `--uikit-split` flag runs Adaptive Demo's Library on UIKit's `UISplitViewController` directly (double column, tiled), with our SwiftUI stacks hosted in its columns and its own navigation bars hidden. Results:

- **iPhone Duo, unfolded:** matches native. The sidebar reports `edge=0` and a 20-point trailing inset, with no rail gap; the detail gets the 495.7-point leading inset and the rail's 84 points; both columns reach the bottom. Side-by-side screenshots match native apart from the list's card style.
- **iPad, full screen:** the launch jump returns, in 3 of 3 launches: toolbars at `y = 150` (tab content inset 96), then `y = 86` (inset 32) about 0.1 s later, the same as `NavigationSplitView`. So the jump comes from UIKit's split view inside a tab, not from SwiftUI's wrapper. Its default sidebar width is 320 points.

### Plan under evaluation: native split view on iPhone, custom layout on iPad

Proposal (user): use SwiftUI's `NavigationSplitView` on iPhone-idiom devices (including iPhone Duo) and the custom layout on iPad. The choice has to be made at runtime (`userInterfaceIdiom`): one iOS binary serves both families, so `#if` can't remove the unused path. It never changes while the app runs.

Native Demo cold launches, layout timeline from the first reading through about 9 seconds:

| Device | State | Launches | Result |
| --- | --- | --- | --- |
| iPhone 18 Pro, iOS 27.0 | default | 4 | Stable: bar at `y = 62` from the first reading in all 4 |
| iPhone Duo, unfolded, iOS 27.1 | sidebar forced open (`--show-sidebar`), collection selected | 4 | No vertical movement. In 2 of 4, the sidebar starts 419 points wide and widens to the fold (475.7) about 0.1 s later; a 10 fps recording shows it in one frame of the launch fade-in |
| iPhone Duo, unfolded | default (sidebar starts hidden), collection selected | 4 | Stable in all 4 |
| iPhone Duo, closed (outer screen, 466 × 678) | default | 4 | Stable in all 4; one stack, large title, search hidden until pulled |
| iPhone Duo, closed | collection selected (pushed) | 2 | Stable in both; back button in the rail |
| iPhone Duo, fully flat | default, collection selected | 3 | Stable in all 3 |
| iPhone Duo, fully flat | sidebar forced open, collection selected | 3 | Stable in all 3. Flat, native does **not** split at the fold: the sidebar is its normal 419 points, side by side |
| iPhone 15, iOS 17.5 | default | 3 | Stable in all 3 (classic-tab fallback shell) |
| iPhone 16 Pro, iOS 18.2 | default | 3 | Stable in all 3 (classic-tab fallback shell) |

On iOS 17.5 the native sidebar's search field was visible on the first launch after install and hidden on the next two; each launch was stable. That's system behavior, not the demo's.

Native on the Duo therefore splits at the fold only while partly folded; flat, it behaves like any wide window. The custom layout's use of an *inactive* division region (step 3c) doesn't match that and would need revisiting if the custom layout is used on the Duo.

Not yet checked: interactions (opening the sidebar, rotation, folding with a collection open), and iOS 17/18 on iPad.

### Adopted: system split view on iPhone, custom layout on iPad

`AdaptiveLibraryView` now chooses its implementation once per launch with `AdaptiveLibraryEngine.resolve(idiom:arguments:)`: iPhone-family devices (including iPhone Duo, and iPhone apps running on iPad) use `NavigationSplitView`, exactly as Native Demo configures it (`NativeLibraryView`, now also compiled into Adaptive Demo); everything else uses the custom layout (`AdaptiveCustomLibraryView`). Debug-only `--force-custom-layout` and `--force-system-split` override the choice for comparisons. Tests cover the choice.

Checked with `--select-collection=1`, cold launches, layout timeline and screenshots:

- iPhone 18 Pro: Adaptive Demo identical to Native Demo (bar at `y = 62`), stable in 3 of 3.
- iPhone Duo, flat: identical to Native Demo (sidebar starts hidden, bar at `y = 24`), stable in 3 of 3.
- iPad, full screen: still the custom layout, stable in 3 of 3 (bars at `y = 96` from the first reading).
- All 13 Adaptive tests pass on iOS 17.5.

With this, the Duo-only issues found in the custom layout (the rail inset inside the sidebar, the flat-fold mismatch, the detail moving when the sidebar opens) no longer apply on shipping configurations; they matter only if the custom layout is forced onto a phone.

### Experiment: launch cover over the native split view

**Adopted (2026-11-01):** the native split view everywhere, with this cover on iPad only. The custom layout is parked. Debug flags: `--no-launch-cover`, `--force-launch-cover` (any device), `--launch-cover=0.3`.

Instead of replacing the native split view on iPad, hide its launch-time jump. `NativeLaunchCover` (Native Demo) draws a plain view in the system background color, matching the empty `UILaunchScreen`, over the whole app. It watches the window's navigation bar frames and the selected tab's top inset every frame, and fades out (0.15 s) once they've held still for 0.15 s, or after 1 s at most. The layout underneath is untouched. `--launch-cover=0.3` uses a fixed time instead; `--no-launch-cover` turns it off.

iPad, 5 cold launches (3 floating window, 2 full screen): the usual jump happened every time (toolbar `y = 128 → 64` windowed, `150 → 86` full screen, about 0.09 s after the first layout), and the cover lifted 0.12–0.14 s after the jump in all 5. The cover adds about 0.2 s before content shows.

Limits: it hides the brief jump only. The intermittent launch that stays wrong until the window is resized would be revealed as it is, since it's also "still". A real launch screen can't be held longer: iOS removes it at the app's first frame.

### iOS 17 support in the demos

The demo apps now target iOS 17. `DemoRootView` uses the `Tab` API with the tab bar's bottom accessory and minimization on iOS 26 and later, and falls back to classic `.tabItem` tabs with the player bar in a bottom `safeAreaInset` on iOS 17–25. The Debug-only mirrored-background trial needs iOS 26 and does nothing earlier. Safe Area Explorer stays at iOS 26, since it diagnoses the iOS 26 tab bar. All apps and test targets build with the iOS 17 minimum.

### The 10-point toolbar gap, explained

On iPad, the floating tab bar needs room at the top. Apple's split view leaves a 54-point strip for it, so its toolbars start at 86 (full screen, 32-point status area). Ordinary content, including our side-by-side columns, gets the system's standard 64-point strip, so our toolbars start at 96. A single full-width stack puts the tab bar inside its own toolbar row, starting at 32. Matching 86 by subtracting a hard-coded 10 points would break this project's no-fixed-offset rule. The user wants to match native, carefully: find an approach that doesn't hard-code the difference, and test it with and without a `TabView`, with the tab bar at the bottom, and back to iOS 17. Tracked in [TODO.md](../../TODO.md).

### Visible differences to address later

- The custom toolbars sit `10` points lower than the native settled position (`96` vs `86`).
- In a plain stack, the sidebar list renders as an inset card rather than the native sidebar surface.
- Opening search hides the custom sidebar's title and reset button (see above).

Row selection by tapping works (confirmed manually by the user).

## Next steps

1. **Manual review of step 2b:** live resizing between modes, rotation, the unfolded Duo, and overlay taps. iPhone and Duo still need testing and refinement.
2. **Polish:** sidebar surface (the component should accept any sidebar content, so this belongs to the content or an optional helper, not a forced style), animations, keyboard, and accessibility.
3. **Package extraction** once the behavior is settled.
4. **iOS 17 support.** The package must work on iOS/iPadOS 17 and later, and everything above has to be tested back to 17. The layout code itself uses only iOS 17-era APIs (`NavigationStack`, `GeometryReader`, `@Bindable`, two-value `onChange`, `.smooth` animation). The demo shell does not yet: `Tab` needs iOS 18, and `tabViewBottomAccessory` and `tabBarMinimizeBehavior` need iOS 26, so the demo's deployment target is 26. Testing on 17 needs a fallback shell (`.tabItem` tabs, and the player bar via `safeAreaInset`). iPadOS 17 also puts the tab bar at the bottom, so iPad behavior will differ. Installed simulators: iPhone 15 on iOS 17.5 and iPhone 16 Pro / SE on iOS 18.2; no iPad runtimes for 17 or 18 yet.

Each step repeats this launch comparison.

## Measuring

Launch either app with `--inspect-native-layout`. The probe writes `Documents/layout-timeline.txt` (one summary line per reading: seconds since process start, the selected tab's top safe inset, and every visible navigation bar's frame) and `Documents/native-layout.txt` (the latest full hierarchy). Readings happen on the probe's own layout changes and at fixed times during the first 8 seconds. The probe never changes layout.

Add `--present-search` (Debug only, either app) to open Library search when it appears, or, in Adaptive Demo only (Debug): `--hide-sidebar` (side-by-side sidebar starts hidden), `--show-sidebar` (overlay sidebar starts shown), `--library-layout=side-by-side|overlay|stack` (force a mode regardless of width), `--library-layout-schedule=MODE,MODE,...` (switch to each mode in turn, 3 seconds apart), `--sidebar-schedule=show,hide,...` (show or hide the sidebar in turn, 3 seconds apart), `--select-collection=N` (select collection N at launch), and `--scroll-library-to=N` (scroll the Library list to collection N at launch). Timeline lines also include each large scroll view's offset and adjusted top inset.
