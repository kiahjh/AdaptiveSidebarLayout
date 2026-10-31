# Native sidebar background investigation

## Scope and result

On October 30, 2026, investigate the floating-window top strip using supported background styling. The initial pass did not change container safe areas, move controls, or change the native tabs. A later user-authorized trial extends only the split container into the top safe area; its initial measured result is recorded below. No custom sidebar was implemented. The user has visually confirmed the standalone **Split Only Demo** reaches the edges in full-screen and floating-window modes. A subsequent same-window accessory-only control is also recorded below.

**Current status: cold-launch layout stability failed subsequent manual testing.** The top-edge container change corrected background/dimming coverage in the paired measurement, but does not reliably prevent excessive initial toolbar/sidebar top spacing. The change remains Native Demo's installed default for investigation, not a validated complete solution. It applies `.ignoresSafeArea(.container, edges: .top)` to the Library split container in both Debug and Release builds. Native tabs, the accessory, and automatic column adaptation remain enabled; no custom layout was implemented.

No launch flag is required, including after closing and reopening the app. The original reference is now a Debug-only opt-out, `--system-split-insets`. Split Only Demo explicitly retains the unmodified system-insets configuration. Broader iPad, iPhone, and Duo testing remains in progress; enabling this default is not a claim that all device/posture/keyboard scenarios have passed.

The commands and measurements below record the investigation as it happened, before the fix became the default. To repeat an old unmodified Native Demo reference launch on the current build, add `--system-split-insets`.

## Environment and measurements

- Xcode 27.1 beta, iPad Air 13-inch (M4) simulator running iPadOS 27.0.
- Actual scene window, floating away from the display's edges; not a preview or headless hosting controller.
- Window bounds: `(0, 0, 809.5, 1109)` points; safe insets: top `10`, bottom `10`, left/right `0`.
- Use the same restored window and `--show-sidebar` in every trial, with no selected collection. This argument requests native `.all` visibility on launch; it is not the app's normal `.automatic` initial value.
- Settled root hosting controller, tab controller, and tab-content hosting controller frames: `(0, 0, 809.5, 1109)`.
- Settled split-view controller frame: `(0, 10, 809.5, 1099)`. Its own top safe inset is already `0`.
- Native sidebar navigation controller also starts at `y = 10`; its hosting view clips to its bounds.

The visible ten-point strip is outside the split controller's bounds, not simply unused space inside its List. The tab's parent views cover that region. This explains why background configuration inside a column does not necessarily reach the window edge; it does not prove the cause or behavior of a standalone split view.

An early layout capture showed the tab-content top inset at `74`, then the one-second snapshot showed `10`, without a manual resize. Early/transitional captures must not be confused with the settled appearance or treated as a persistent cold-launch failure. The diagnostic delay is only for reading the hierarchy; it does not trigger layout or implement a fix.

## Trials

Each trial used only the modifier shown below; the broad split-view extension was not enabled during column-only trials.

### 1. Navigation-column material

Applied to `DemoLibraryBrowser` inside the sidebar closure:

```swift
.containerBackground(.regularMaterial, for: .navigation)
```

The material changed, but the top strip remained. This also changed native column compositing: the detail controller stopped extending behind the sidebar and the divider became visible. It is not merely a color change with every internal frame held fixed.

### 2. Background-extension effect on the split view

Applied to `NavigationSplitView`, after its style:

```swift
.backgroundExtensionEffect()
```

The background filled the top strip. A comparison of the settled hierarchy captures found the window bounds/insets, split-controller frame, both navigation-bar frames/insets, and bottom-accessory frame/insets unchanged.

**Correction after manual review:** the earlier claim that this effect persistently clipped the artwork SF Symbols was a mistaken reading of reduced screenshots. Enlarging the original screenshot pixels showed complete music-note, guitar, waveform, and piano-key symbols. The user also did not observe clipping live. The claimed symbol-rendering regression is withdrawn; it is not evidence against this API or native navigation.

The user's screen recording does show a different, real concern: while scrolling the Library, a blurred reflection of a row appears below the playback accessory, including an orange artwork reflection at the bottom edge. This is consistent with the modifier's documented mirrored, blurred copies at available safe-area edges. Applied to the entire split view, it extends live content beyond the bottom as well as filling the top. This is not yet an adopted fix because that bottom reflection is undesirable for the demo's design; it is not being classified as a framework defect. Navigation transitions and the remaining comparison scenarios still need review.

The user also identified a **darker** band at the top where the extension meets the sidebar surface. The earlier description of that band as lighter was incorrect. Its precise rendering cause has not been established; color matching should not be assumed to solve material continuity.

### 3. Effect on only the column's material view

Applied to `DemoLibraryBrowser`:

```swift
.containerBackground(for: .navigation) {
    Rectangle()
        .fill(.regularMaterial)
        .backgroundExtensionEffect()
}
```

The top strip remained. It did not extend the background to the top edge. Earlier symbol-artifact descriptions were not verified and are withdrawn along with the screenshot-reading correction above.

### 4. Column background ignoring only the top safe area

Applied to `DemoLibraryBrowser`:

```swift
.containerBackground(for: .navigation) {
    Rectangle()
        .fill(.regularMaterial)
        .ignoresSafeArea(.container, edges: .top)
}
```

The top strip remained. The split controller still started at `y = 10`, with top safe inset `0`. Earlier symbol-artifact descriptions were not verified and are withdrawn along with the screenshot-reading correction above. These observations do not establish that every possible native styling configuration fails.

## First Split Only Demo launch: unmatched window states

Both apps built successfully and were launched without `--extend-split-background`, using the same `--show-sidebar --inspect-native-layout` arguments. The first snapshots were:

| App | Window state / bounds | Window safe insets (top/bottom) | Split-controller frame |
| --- | --- | --- | --- |
| Native Demo | Floating, `809.5 × 1109` | `10 / 10` | `(0, 10, 809.5, 1099)` |
| Split Only Demo | Full screen, `1024 × 1366` | `32 / 20` | `(0, 0, 1024, 1366)` |

The standalone split controller fills its window in that first full-screen launch, preserving the window's safe insets for its native content. This is useful evidence about that configuration, but the two window states differ: it is **not** yet a matched test proving the floating-window difference is caused by tabs. The control app is left running for a manual floating-window comparison. Native Demo was relaunched with the background-extension effect disabled, so it is ready as the reference.

## Accessory-only control: top boundary unchanged

The same Native Demo build was launched twice in its restored floating window on the same iPad simulator. Both launches used `--show-sidebar --inspect-native-layout`; only the second added `--without-accessory`. Neither enabled the background-extension effect. The option removes the accessory modifier itself, not merely the player view.

| Measurement | Accessory present | Accessory absent |
| --- | --- | --- |
| Window bounds | `(0, 0, 809.5, 1109)` | `(0, 0, 809.5, 1109)` |
| Window safe insets (top/bottom) | `10 / 10` | `10 / 10` |
| Tab-content safe insets (top/bottom) | `10 / 62` | `10 / 10` |
| Split-controller frame | `(0, 10, 809.5, 1099)` | `(0, 10, 809.5, 1099)` |
| Native accessory views in captured hierarchy | `1` | `0` |

The top strip remained in the no-accessory screenshot. Removing the accessory changed the bottom safe area as expected, but did not change the split controller's top boundary. Thus the accessory is **not responsible for the reproduced floating-window top gap in this configuration**. Combined with the user's successful standalone review, this narrows the investigation to the tab/split composition rather than an inherent inability of the native sidebar to fill its window. It is not a claim about every OS release or every possible tab configuration.

At the end of this control, Native Demo was left running with the accessory omitted and extension effect disabled for manual review. A standard launch still includes the accessory. The app built successfully and all eight demo-model tests passed at that stage; those tests did not verify native layout.

## Top-safe-area container trial: promising initial overlay result

The user authorized a scoped test of `.ignoresSafeArea(.container, edges: .top)` on the split-view container itself. Both launches kept the native tabs and bottom accessory, used `--show-sidebar --inspect-native-layout`, and omitted both `--without-accessory` and `--extend-split-background`. Only the second added `--extend-split-to-top`.

The same restored floating window measured `749 × 899` points and used the intermediate native overlay-sidebar presentation. Its window safe insets were `10 / 0 / 10 / 0` in both launches. The read-only captures showed:

| Measurement | Reference | Container trial |
| --- | --- | --- |
| Split-controller frame | `(0, 10, 749, 889)` | `(0, 0, 749, 899)` |
| Split-controller top/bottom safe insets | `0 / 62` | `10 / 62` |
| Native dimming-view frame | `(0, 10, 749, 889)` | `(0, 0, 749, 899)` |
| Detail navigation-bar frame | `(0, 64, 749, 54)` | Unchanged |
| Sidebar navigation-bar frame | `(0, 64, 420, 160)` | Unchanged |
| Search-field frame | `(16, 170, 388, 44)` | Unchanged |
| Bottom-accessory frame | `(10, 837, 729, 52)` | Unchanged |

The captured trial shows the actual sidebar and native dimming layer reaching the top edge. Crucially, the split controller regains the real window top inset instead of reporting a zero top inset in a frame positioned below it. There is no copied background, fixed inset compensation, or manual UIKit safe-area override. The measured navigation bars, search field, and accessory remain positioned as before in this case.

This initial measurement is **not complete validation**. Full-screen and display-edge placement, wide side-by-side and compact stack layouts, navigation state/content positioning, tab switching, sidebar dismissal/animation, scrolling, and search/keyboard behavior require separate review. Do not infer that every content inset or interaction is unchanged solely from this table. Following a positive user review, the user requested the fix as the normal installed behavior for rigorous testing on iPad, iPhone, and Duo.

## Default build for rigorous device testing

`NativeLibraryView` now defaults to the top-extended container configuration, even with no arguments and in Release builds. The no-tabs control explicitly passes `extendsContainerToTop: false`, preserving its original behavior. Debug comparison options select one configuration rather than combining the fixed container with a mirrored-background copy.

The added configuration tests cover the real Library view's default, the standalone control's system-insets selection, an explicit original-insets opt-out, and legacy trial precedence. Existing model tests continue to cover the shared data/state. These tests do not replace real-device and simulator UI review. No Duo-specific fold adapter or safe-area compensation has been added.

Validation of this default build: Native Demo and Split Only Demo built successfully in Debug, Native Demo also built successfully in Release for the generic iOS Simulator destination, and all **13 tests passed**. A launch with only read-only instrumentation (no layout or visibility arguments) measured an `888 × 975` iPad window with the split controller filling `(0, 0, 888, 975)` and retaining top/bottom safe insets `10 / 62`. The app was then terminated and relaunched with **no arguments at all**; its running process command line was checked to contain only the executable path. This confirms that the installed normal launch no longer depends on the old trial flag. iPhone and Duo UI behavior still requires the user's requested rigorous testing.

## Cold-launch stability failure after default build

The user subsequently reported intermittent excessive empty space above the sidebar's navigation content. Some launches remain incorrect until the window is resized; others briefly show the incorrect layout and then correct themselves. Their screenshot was named `Screenshot 2026-10-30 at 2.39.50 PM.png`. This resembles the earlier Music app launch/resize symptom, but an identical underlying cause has not been established. Both a persistent incorrect state and a visible initial flash fail the desired stability requirement.

The running app was **not relaunched, resized, or reconfigured** during inspection. Its PID was `93371`, and its command line contained only the Native Demo executable, with no layout, visibility, accessory, or probe arguments. This rules out the earlier lost-launch-flag explanation for this process. By inspection time the sidebar was closed; the detail's sidebar button still appeared low. Therefore the live capture below measures the detail-visible state, not the open sidebar in the user's original screenshot.

The existing probe requires a launch argument, so it could not be enabled in this process without restarting. Instead, a standalone LLDB debugger briefly attached to the existing simulator process. A successful main-thread expression read public window/controller/view properties, traversed already-loaded views, and then detached. It did not set insets, request layout, change visibility, or recreate views. Two preceding expression attempts failed to compile; they produced no hierarchy measurement. Screenshots taken before and after debugger inspection both retained the low button position.

| Live measurement | Observed value |
| --- | --- |
| Window bounds | `(0, 0, 704, 724)` |
| Window / root / tab-controller top safe inset | `10` |
| Tab-content hosting-controller top safe inset | `74` |
| Split-controller frame | `(0, 0, 704, 724)` |
| Split-controller top/bottom safe insets | `74 / 62` |
| Detail navigation-controller top safe inset | `128` |
| Detail navigation-bar frame | `(0, 128, 704, 54)` |
| Native bottom-accessory frame | `(10, 662, 684, 52)` |
| Explicit additional controller safe insets | All captured values zero |

The split controller still reaches the window's top, so this is not simply a return of the ten-point frame gap. Its inherited top safe inset differs from the earlier good captures (`74` rather than `10`), and the detail navigation bar is `64` points lower (`128` rather than `64`). This is consistent with an extra toolbar-height contribution. **These are different window sizes and not a matched before/after-resize pair**, so they do not by themselves prove double counting, stale state, or the responsible framework component. The earlier transient `74`-point capture is relevant context, not proof that this persistent failure has the same cause.

Evidence is saved under the session's approved temporary directory:

- `native-flaky-start-current.png`: screenshot before debugger inspection.
- `native-flaky-start-after-inspection.png`: screenshot after detaching; low button position remains.
- `native-flaky-start-live-layout-final.txt`: successful debugger capture, including process arguments and detach confirmation.
- `capture-native-live-layout.lldb`: read-only capture commands; not part of the app.

No app source or installed behavior was changed during that live inspection. No delayed layout invalidation, forced refresh, identity reset, fixed-offset padding, or artificial resize was added. Passing model/configuration tests do not contradict this UI failure. A controlled bad-state/resize/restore measurement would help isolate the remaining native issue; any further native proposal must demonstrate stable first rendering rather than merely repair layout afterward. A custom Library layout remains an alternative to evaluate using the same shared model/content and native tabs/accessory, not a guaranteed fix for an unisolated tab-container issue.

## Tab-bar minimization control: no improvement in the startup inset sequence

The user authorized a low-confidence isolation test of the optional `.tabBarMinimizeBehavior(.onScrollDown)` modifier. This API controls scroll-driven tab-bar minimization, **not sidebar visibility**. The iPad top tabs had not visibly minimized during manual testing; the question was whether the modifier participates in container layout even without a visible minimization transition.

Two controls were tested separately:

1. An initial build selected `.never` instead of `.onScrollDown` under `--without-tab-minimization`. Three alternating launch pairs showed the same early and later inset values in both configurations.
2. The retained diagnostic now **omits the modifier entirely** under that argument. Three further alternating launch pairs also showed the same early and later values. This avoids equating an explicit `.never` setting with absence of the modifier.

Every measured launch used `--inspect-native-layout`, retained the default top-extended split container, native Library/Queue tabs, bottom accessory, identical fixtures, and automatic column visibility. No collection was selected and the sidebar was closed. Neither the background-extension trial nor the accessory-removal option was enabled. These were fresh simulator processes, not manual sidebar interactions. There was no scripted resize, layout invalidation, or forced view recreation inside the app.

The initial `.never` comparison's first pair used a floating `817 × 724` window. The second and third pairs were full-screen `1024 × 1366`; the window state changed between pairs, so the entire set must not be described as one unchanged floating window. Bounds were matched within each pair. All three subsequent omission pairs used the same full-screen bounds.

| Comparison | Pairs | Window top inset | Early saved split top inset / detail bar y | Later saved split top inset / detail bar y |
| --- | --- | --- | --- | --- |
| `.onScrollDown` vs `.never`, floating | 1 | `10` | `74 / 128` in both | `10 / 64` in both |
| `.onScrollDown` vs `.never`, full screen | 2 | `32` | `96 / 150` in both | `32 / 86` in both |
| `.onScrollDown` vs omitted modifier, full screen | 3 | `32` | `96 / 150` in both | `32 / 86` in both |

The capture script saved the probe's latest file approximately `1.5` and `4` seconds after `simctl launch` returned. These are **file-read times, not timestamped continuous measurements of the live hierarchy**: the existing probe captures on its own layout events and once more after attachment. The earliest scheduled `0.25`-second reads had no fresh capture and were not used. Therefore this table establishes the recorded early/later layout sequence, not the precise duration of any on-screen flash. Simulator video and settled screenshots were also retained; reduced contact sheets are for context, not a basis for pixel-level rendering claims.

Both the explicit-off and omitted-modifier controls retained the same early extra `64`-point contribution and later correction as their references. **No improvement was demonstrated.** All twelve measured launches had reached the corrected values by the later saved snapshot. The previously observed persistent-until-resize state did not recur in this sample, so this test does not establish its precise cause or prove that every form of the failure is independent of minimization. It does show that the optional modifier is not required for the recorded early offset in this native composition.

The final omission build ran successfully and all **13 model/configuration tests passed**; no test claims to validate these native UI transitions. Normal Debug and Release behavior remains `.onScrollDown`. Only the new Debug argument omits the modifier. Sidebar controls, column visibility, navigation state, and accessory content were not changed.

Evidence is under the approved session temporary directory:

- `tab-minimization-control/`: initial `.never` build's three pairs, raw probe captures, `report.json`, settled screenshots, and `cold-launches.mp4`.
- `tab-minimization-omission-control/`: final omission build's three pairs and corresponding evidence.
- `capture-tab-minimization-control.py`: capture script; separate from the app.

Native Demo is left running with `--inspect-native-layout --without-tab-minimization` for optional manual review. A fresh Home Screen launch drops those arguments and returns to the unchanged normal configuration. Omitting minimization is not adopted as a fix, and native launch stability remains an open failure.

## Retained diagnostics

Debug-only launch arguments:

- `--system-split-insets`: restore the original unmodified split-container configuration. This takes precedence over other layout comparison arguments and is required to repeat historical reference launches on the current Native Demo build. Release builds ignore it.
- `--show-sidebar`: start with native `.all` column visibility for repeatable screenshots. Omit for the normal `.automatic` behavior.
- `--without-accessory`: in Native Demo, omit the `tabViewBottomAccessory` modifier entirely while retaining its tabs, Library, minimization behavior, and styling. This isolates the accessory's layout contribution; it is not a hidden or empty accessory. Omit this argument for the reference configuration. Split Only Demo does not use the tab shell and is unaffected by this option.
- `--without-tab-minimization`: in Native Demo, omit `.tabBarMinimizeBehavior(.onScrollDown)` entirely while retaining both tabs, the accessory, the top-container configuration, and native sidebar controls/adaptation. It leaves minimization to the system default rather than specifying `.never`. It is independent of `--without-accessory`, ignored in Release builds, and has not fixed the reproduced early inset sequence.
- `--extend-split-to-top`: a compatibility option for the now-default `.ignoresSafeArea(.container, edges: .top)` configuration. Native Demo no longer needs this argument. It can also explicitly select the configuration in Split Only Demo. An original-insets opt-out wins; otherwise this option takes precedence over the mirrored-background trial.
- `--extend-split-background`: select `.backgroundExtensionEffect()` instead of the default top-edge fix. This reproduces trial 2 for manual review; it does not enable any other trial modifier. It is off by default and ignored in Release builds.
- `--inspect-native-layout`: attach a zero-sized, read-only UIKit probe. It writes `Documents/native-layout.txt` in the app's data container, recording window/controller/view frames, safe insets, clipping, and resolved background colors. It captures on probe layout changes. Since the custom-layout comparison, it also reads the hierarchy at fixed times during the first 8 seconds and appends a one-line summary per reading to `Documents/layout-timeline.txt`. It replaces the earlier single extra capture at one second; see [the custom layout notes](CustomLayout.md). There is no open-ended polling, layout invalidation, safe-area mutation, or private API invocation. Internal class names in the output are observations only, not dependencies.

For normal cross-device review, run Native Demo with **no arguments** and reopen it from the Home Screen to check cold launches. For original-insets comparisons, use `--system-split-insets`; optional `--show-sidebar --inspect-native-layout` arguments make paired measurements reproducible. To repeat the discarded mirrored trial, use `--extend-split-background --show-sidebar`. Removing all comparison arguments returns to the fixed default, not the original gap-producing configuration.

The other trial flags and modifiers are not retained in the app; reproduce one of those trials by temporarily applying its snippet. Never combine a trial with another modifier and attribute the result to just one.

## Next questions

1. Treat the remaining intermittent launch offset as a failed stability check, not as a solved layout. Preserve the native reference and this evidence while deciding whether another clean, controlled native experiment is warranted or to proceed with the custom Library layout. The accessory-only control ruled out the player as the source of the earlier ten-point background gap; it did not isolate this new stability failure.
2. Foreground content positioning, compact adaptation, and transitions must be reviewed separately. This container-bounds experiment is different from background-only styling; the passing initial bar/search/accessory measurements do not prove every safe-area interaction remains correct.
3. Any candidate must pass cold launch, sidebar animation, tab switching, resizing, full screen, search, and bottom-accessory checks before being adopted.

References: [Navigation container backgrounds](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/navigation), [Split-view backgrounds](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/navigationsplitview), and [Background-extension effect](https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect()).
