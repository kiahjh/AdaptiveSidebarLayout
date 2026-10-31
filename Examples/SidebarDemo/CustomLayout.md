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

### Visible differences to address later

- The custom toolbars sit `10` points lower than the native settled position (`96` vs `86`).
- In a plain stack, the sidebar list renders as an inset card rather than the native sidebar surface.
- Opening search hides the custom sidebar's title and reset button (see above).

Row selection by tapping works (confirmed manually by the user).

## Next steps

1. **Manual review of step 2b:** live resizing between modes, rotation, the unfolded Duo, and overlay taps.
2. **Polish:** sidebar surface, animations, keyboard, keeping the sidebar's scroll position when entering or leaving the stack mode, and accessibility.
3. **Package extraction** once the behavior is settled.

Each step repeats this launch comparison.

## Measuring

Launch either app with `--inspect-native-layout`. The probe writes `Documents/layout-timeline.txt` (one summary line per reading: seconds since process start, the selected tab's top safe inset, and every visible navigation bar's frame) and `Documents/native-layout.txt` (the latest full hierarchy). Readings happen on the probe's own layout changes and at fixed times during the first 8 seconds. The probe never changes layout.

Add `--present-search` (Debug only, either app) to open Library search when it appears, or, in Adaptive Demo only (Debug): `--hide-sidebar` (side-by-side sidebar starts hidden), `--show-sidebar` (overlay sidebar starts shown), `--library-layout=side-by-side|overlay|stack` (force a mode regardless of width), and `--select-collection=N` (select collection N at launch). Timeline lines also include each large scroll view's offset and adjusted top inset.
