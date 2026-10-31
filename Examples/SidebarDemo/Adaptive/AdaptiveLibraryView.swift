import SwiftUI

/// How the custom Library arranges its sidebar and detail.
enum AdaptiveLibraryMode: String, Equatable, CaseIterable {
    /// Sidebar and detail side by side. The sidebar can be hidden.
    case sideBySide = "side-by-side"
    /// Detail fills the width; the sidebar slides over it with dimming.
    case overlay
    /// One navigation stack: the Library list, with collections pushed on top.
    case stack
}

/// Sizes that decide the layout mode. Everything is based on the width the
/// Library actually gets, so iPhone, iPad windows and Duo follow one set of rules.
struct AdaptiveLibraryMetrics: Equatable {
    /// Matches the native sidebar's ideal column width.
    var sidebarWidth: CGFloat = 420
    /// Narrowest detail column worth showing next to the sidebar.
    var minimumDetailWidth: CGFloat = 500
    /// Detail that must stay visible beside an overlay sidebar, so it still
    /// reads as an overlay and can be tapped to dismiss.
    var minimumOverlayMargin: CGFloat = 100

    func mode(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> AdaptiveLibraryMode {
        // A compact size class also moves the tab bar to the bottom, so follow
        // the system there even if the width would allow an overlay.
        if horizontalSizeClass == .compact || width < sidebarWidth + minimumOverlayMargin {
            return .stack
        }
        if width >= sidebarWidth + minimumDetailWidth {
            return .sideBySide
        }
        return .overlay
    }
}

/// The custom Library layout. It picks a mode from the available width and
/// uses only ordinary navigation stacks, never `NavigationSplitView`.
struct AdaptiveLibraryView: View {
    let model: DemoModel
    var metrics = AdaptiveLibraryMetrics()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var debugMode = AdaptiveLibraryDebug.initialMode

    var body: some View {
        GeometryReader { proxy in
            AdaptiveLibraryLayout(
                model: model,
                mode: debugMode
                    ?? metrics.mode(width: proxy.size.width, horizontalSizeClass: horizontalSizeClass),
                sidebarWidth: metrics.sidebarWidth,
                availableWidth: proxy.size.width
            )
        }
        #if DEBUG
        .task {
                // Switches modes on a fixed schedule so mode changes can be
                // checked without resizing the window.
                for mode in AdaptiveLibraryDebug.modeSchedule {
                    do {
                        try await Task.sleep(for: .seconds(3))
                    } catch {
                        return
                    }
                    debugMode = mode
                }
            }
        #endif
    }
}

/// Debug-only launch arguments for capturing states without UI automation.
private enum AdaptiveLibraryDebug {
    /// `--library-layout=MODE` forces a mode regardless of width.
    static var initialMode: AdaptiveLibraryMode? {
        value(for: "--library-layout=").flatMap(AdaptiveLibraryMode.init(rawValue:))
    }

    /// `--library-layout-schedule=MODE,MODE,...` switches to each mode in
    /// turn, three seconds apart.
    static var modeSchedule: [AdaptiveLibraryMode] {
        value(for: "--library-layout-schedule=")?
            .split(separator: ",")
            .compactMap { AdaptiveLibraryMode(rawValue: String($0)) } ?? []
    }

    /// `--select-collection=N` selects collection N at launch.
    static var collectionToSelect: DemoCollection.ID? {
        value(for: "--select-collection=").flatMap(Int.init)
    }

    /// `--scroll-library-to=N` scrolls the Library list to collection N at launch.
    static var collectionToScrollTo: DemoCollection.ID? {
        value(for: "--scroll-library-to=").flatMap(Int.init)
    }

    static func flag(_ flag: String) -> Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains(flag)
        #else
            false
        #endif
    }

    private static func value(for prefix: String) -> String? {
        #if DEBUG
            ProcessInfo.processInfo.arguments
                .first { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)) }
        #else
            nil
        #endif
    }
}

/// All three modes share one view structure. The Library's navigation stack is
/// the sidebar in the two-column modes and the whole Library in the stack mode,
/// so switching modes never rebuilds it: its scroll position, search field and
/// list stay as they were.
private struct AdaptiveLibraryLayout: View {
    let model: DemoModel
    let mode: AdaptiveLibraryMode
    let sidebarWidth: CGFloat
    let availableWidth: CGFloat
    @State private var isPinnedSidebarVisible = !AdaptiveLibraryDebug.flag("--hide-sidebar")
    @State private var isOverlaySidebarVisible = AdaptiveLibraryDebug.flag("--show-sidebar")

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .leading) {
                // The stack mode shows detail inside the Library's own stack.
                // Removing this column there doesn't disturb the Library stack,
                // which keeps its place in the structure.
                if mode != .stack {
                    DemoDetailColumn(model: model, isSidebarVisible: sidebarVisibility)
                        .padding(.leading, mode == .sideBySide && isPinnedSidebarVisible ? sidebarWidth : 0)
                        .accessibilityHidden(isOverlayShowing)
                }

                dimming

                libraryStack
            }
            .onAppear {
                if let id = AdaptiveLibraryDebug.collectionToScrollTo {
                    scrollProxy.scrollTo(id, anchor: .top)
                }
            }
        }
        .onAppear {
            if let id = AdaptiveLibraryDebug.collectionToSelect, model.selectedCollectionID == nil {
                model.selectCollection(id)
            }
        }
        .onChange(of: mode) { oldMode, _ in
            // An overlay left open shouldn't reappear the next time the
            // window narrows.
            if oldMode == .overlay {
                isOverlaySidebarVisible = false
            }
        }
        .onChange(of: model.selectedCollectionID) {
            // Choosing a collection from the overlay reveals it, like native.
            if mode == .overlay, isOverlaySidebarVisible {
                withAnimation(Self.animation) {
                    isOverlaySidebarVisible = false
                }
            }
        }
    }

    private var dimming: some View {
        Rectangle()
            .fill(.black)
            .opacity(isOverlayShowing ? 0.2 : 0)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .allowsHitTesting(isOverlayShowing)
            .onTapGesture(perform: hideOverlay)
            .accessibilityLabel("Hide Sidebar")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, hideOverlay)
            .accessibilityHidden(!isOverlayShowing)
    }

    private var libraryStack: some View {
        NavigationStack(path: libraryPath) {
            DemoLibraryBrowser(
                model: model,
                placement: mode == .stack ? .compactStack : .navigationStack,
                isSidebarVisible: mode == .stack ? nil : sidebarVisibility
            )
            .navigationDestination(for: DemoCollection.ID.self) { id in
                if let collection = model.collection(id: id) {
                    DemoCollectionDetail(collection: collection, model: model)
                }
            }
        }
        .frame(width: mode == .stack ? availableWidth : sidebarWidth)
        .overlay(alignment: .trailing) {
            if mode != .stack {
                // The HStack makes the divider vertical.
                HStack(spacing: 0) {
                    Divider()
                }
                .ignoresSafeArea()
            }
        }
        .shadow(color: .black.opacity(isOverlayShowing ? 0.15 : 0), radius: 24)
        // Hidden by sliding it away rather than removing it, so its scroll
        // position and navigation state survive being hidden.
        .offset(x: isLibraryShowing ? 0 : -sidebarWidth)
        .allowsHitTesting(isLibraryShowing)
        .accessibilityHidden(!isLibraryShowing)
        .accessibilityAction(.escape) {
            if mode == .overlay { hideOverlay() }
        }
    }

    /// In the stack mode, collections push onto the Library's own stack. In
    /// the column modes, they show in the detail column and this stays at
    /// its root.
    private var libraryPath: Binding<[DemoCollection.ID]> {
        mode == .stack ? Bindable(model).stackPath : .constant([])
    }

    private var sidebarVisibility: Binding<Bool> {
        mode == .sideBySide ? $isPinnedSidebarVisible : $isOverlaySidebarVisible
    }

    private var isLibraryShowing: Bool {
        mode == .stack || sidebarVisibility.wrappedValue
    }

    private var isOverlayShowing: Bool {
        mode == .overlay && isOverlaySidebarVisible
    }

    private func hideOverlay() {
        withAnimation(Self.animation) {
            isOverlaySidebarVisible = false
        }
    }

    static let animation = Animation.smooth(duration: 0.35)
}

extension DemoModel {
    /// The single-stack path: the selected collection, then its detail path.
    /// Shares state with the two-column modes, so a selection and deeper
    /// navigation survive switching between widths. Going back to the list
    /// clears the selection, as the native split view does when collapsed.
    var stackPath: [DemoCollection.ID] {
        get { selectedCollectionID.map { [$0] + detailPath } ?? [] }
        set {
            selectCollection(newValue.first)
            detailPath = Array(newValue.dropFirst())
        }
    }
}
