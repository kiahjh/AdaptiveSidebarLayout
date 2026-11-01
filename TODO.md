# To do

## Decision (2026-11-01)

Use the native `NavigationSplitView` everywhere, as in **Native Demo**, with a launch cover on iPad only. The cover hides the split view's launch-time toolbar jump (measured hidden in 8 of 8 iPad launches; see [the notes](Examples/SidebarDemo/CustomLayout.md#experiment-launch-cover-over-the-native-split-view)). This repo stays a record of the explorations and findings. The custom layout in **Adaptive Demo** is parked, not deleted.

## Open: native approach

- [ ] **Watch for the stuck launch gap.** The cover only hides the brief jump. If a launch ever keeps the extra space above the sidebar until the window is resized, the cover fades out onto it. Note the window state and what happened before.
- [ ] **iPad on iOS 17 and 18.** Install iPad simulator runtimes (none installed yet), then repeat the cover launch check (`cover-check.py`) and a full pass. The tab bar sits at the bottom on iPadOS 17 and moved to the top in 18, so the jump (and whether the cover is needed) may differ.
- [ ] **iPhone on 17.5 and 18.2:** the interaction checks done on iOS 27 (search button, pull-down search, collections, tabs, landscape).
- [ ] **iPhone:** swipe-back, Dynamic Type. Checked on iPhone 18 Pro: opening collections, Back, "Explore another collection", playing tracks, scrolling with tab bar minimization, pull-down search with typing, the search button, switching tabs (selection kept), landscape.
- [ ] **iPhone Duo:** by hand (neither Xcode's taps nor computer use reach the inner display): folding/unfolding with a collection open, portrait unfolded. The search button sits in the rail when closed, and the search field shows at launch there.
- [ ] **VoiceOver:** the cover is hidden from accessibility; check nothing is announced or focusable before it lifts.

## Parked: custom layout (Adaptive Demo)

Kept for reference in case the native approach fails. On iPad it avoided the launch jump without a cover; on iPhone it already used the native split view.

- [ ] Match native toolbar position in side-by-side mode (10-point gap) without a hard-coded offset.
- [ ] Sidebar surface: native sidebar background and list look (no white card), as an optional helper.
- [ ] Separate the search and sidebar buttons (they share one glass capsule; `ToolbarSpacer` on iOS 26+).
- [ ] Bug: iPad, blank lower third after returning to the Library tab. Seen once (landscape, after rotating, searching and going back from a pushed collection); not reproduced in four attempts.
- [ ] Unfolded Duo: the rail's 84-point inset inside the sidebar, and fold clearance in the UIKit-hosted stacks (only relevant if forced onto a phone).
- [ ] Tune mode thresholds; keyboard (Escape, ⌃⌘S, focus); live resizing between modes; overlay taps; scroll position across modes; VoiceOver.

## Later

- [ ] Side-by-side recordings of Native Demo with and without the launch cover for the README.
