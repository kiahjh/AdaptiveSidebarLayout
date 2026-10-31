# To do

Open work for the adaptive sidebar layout. Details and measurements live in [the custom layout notes](Examples/SidebarDemo/CustomLayout.md).

## Layout behavior

- [ ] **Match native toolbar position in side-by-side mode.** Native's toolbars start one 54-point row below the status area (86 on a full-screen iPad); ours get the system's standard 64-point tab bar strip (96). Find a way to match native *without* a hard-coded 10-point offset, then test every case below, since the right spacing depends on where the tab bar is (or whether there is one):
  - [ ] With a `TabView`, floating tab bar at the top (iPadOS 18+, redesigned in 26)
  - [ ] Without any `TabView`: the layout used on its own
  - [ ] Tab bar at the bottom: compact widths, iPhone, iPadOS 17
  - [ ] `.sidebarAdaptable` tab style, and a hidden tab bar
  - [ ] Full screen, floating window, window touching the top edge, Stage Manager, landscape
  - [ ] iPhone, Duo folded and unfolded
  - [ ] iOS/iPadOS 17, 18, 26 and 27
- [ ] **Sidebar surface.** The layout should accept any sidebar content, so it shouldn't force a list style. Give the sidebar column its background from the layout itself, and offer an *optional* helper that gives a `List` the native sidebar look (no white card). Today the demo's list falls back to the card style because nothing tells it it's in a sidebar.
- [ ] **Tune mode thresholds** (currently side by side ≥ 920 points, overlay ≥ 520) after real-device use.
- [ ] **Keyboard:** Escape closes the overlay sidebar; check ⌃⌘S and focus movement between columns.

## Testing

- [ ] **iOS 17 and later.** The package must support iOS/iPadOS 17+. The layout code uses only iOS 17-era APIs, but the demo's tab shell needs iOS 18 (`Tab`) and 26 (`tabViewBottomAccessory`, `tabBarMinimizeBehavior`). Add a fallback shell (`.tabItem` tabs, player bar via `safeAreaInset`) so the demo runs on 17. Install iPad simulator runtimes for 17 and 18 (only iPhone 15 on 17.5 and iPhones on 18.2 are installed).
- [ ] **iPhone:** swipe-back, search with the keyboard up, player bar while scrolling, landscape, Dynamic Type.
- [ ] **iPhone Duo:** unfolded, and folding/unfolding with a collection open. Only folded has been checked.
- [ ] **iPad:** live resizing between all three modes, rotation, overlay taps (dimming, sidebar button, choosing a collection).
- [ ] **Scroll position:** confirm the list doesn't shift when switching modes after normal scrolling (a one-row shift was seen after a programmatic jump).
- [ ] **VoiceOver:** overlay dismissal action, hidden sidebar not reachable, focus order.
- [ ] **Launch stability:** repeat the cold-launch timeline comparison after each change.

## Later

- [ ] Extract the layout into a Swift package once behavior is settled.
- [ ] Side-by-side recordings of Native Demo vs Adaptive Demo for the README.
