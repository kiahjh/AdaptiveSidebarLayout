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
- [ ] **Unfolded Duo: remove the rail's 84-point inset inside the sidebar.** UIKit adds it to the sidebar's navigation stack content even though the column is nowhere near the rail; also get the 20-point fold clearance into the UIKit-hosted stacks. Native's split view sets its columns' insets itself. See step 3c in the notes.
- [ ] **Unfolded Duo: title, search and initial visibility.** Native starts with the sidebar hidden, a large title below the buttons, and search hidden; decide which of these to match.
- [ ] **Duo rail and app toolbar items.** The layout's own buttons now stay out of the Duo's vertical bar (fixed). Toolbar items that *app content* adds to the sidebar or detail could still end up in the rail and get stuck there. Decide whether the layout applies this to its columns automatically, or documents it.
- [ ] **Tune mode thresholds** (currently side by side ≥ 920 points, overlay ≥ 520) after real-device use.
- [ ] **Keyboard:** Escape closes the overlay sidebar; check ⌃⌘S and focus movement between columns.

## Testing

- [ ] **iOS 17 and later.** The demos now target iOS 17 with a classic-tab fallback shell, and Native Demo is stable on iPhone at iOS 17.5 and 18.2. Still to do: Adaptive Demo on 17/18, and iPad on 17/18 (install iPad simulator runtimes for those; none are installed).
- [x] **Native split view on iPhone, custom layout on iPad.** Adopted in Adaptive Demo. Native measured stable on iPhone (17.5, 18.2, 27.0) and on the Duo closed, partly folded and flat; the only issue seen is a one-frame sidebar width snap on the partly folded Duo when the sidebar is forced open at launch, so the Duo keeps the system default (sidebar starts hidden).
- [ ] **iPhone:** swipe-back, search with the keyboard up, player bar while scrolling, landscape, Dynamic Type.
- [ ] **iPhone Duo:** real taps when unfolded (synthesized taps don't register on the inner display), folding/unfolding with a collection open, and portrait unfolded. Folded, and unfolded landscape with the overlay opening and closing, have been checked.
- [ ] **iPad:** live resizing between all three modes, rotation, overlay taps (dimming, sidebar button, choosing a collection).
- [ ] **Scroll position:** confirm the list doesn't shift when switching modes after normal scrolling (a one-row shift was seen after a programmatic jump).
- [ ] **VoiceOver:** overlay dismissal action, hidden sidebar not reachable, focus order.
- [ ] **Launch stability:** repeat the cold-launch timeline comparison after each change.

## Later

- [ ] Extract the layout into a Swift package once behavior is settled.
- [ ] Side-by-side recordings of Native Demo vs Adaptive Demo for the README.
