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

    /// Narrowest column on either side of a fold for the layout to split there.
    var minimumColumnWidthAtFold: CGFloat = 300

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

    /// The full arrangement, including a fold if there is one. Like the native
    /// split view on iPhone Duo, an unfolded device puts the sidebar on one side
    /// of the fold and the detail on the other, regardless of width.
    func columns(
        width: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        fold: AdaptiveLibraryFold?
    ) -> AdaptiveLibraryColumns {
        if horizontalSizeClass != .compact, let fold,
           fold.position >= minimumColumnWidthAtFold,
           width - fold.position >= minimumColumnWidthAtFold
        {
            return AdaptiveLibraryColumns(
                mode: .sideBySide,
                sidebarWidth: fold.position,
                sidebarTrailingClearance: fold.leadingClearance,
                detailLeadingClearance: fold.trailingClearance
            )
        }
        return AdaptiveLibraryColumns(
            mode: mode(width: width, horizontalSizeClass: horizontalSizeClass),
            sidebarWidth: sidebarWidth
        )
    }
}

/// A fold (or another system division) that splits the Library's area into
/// two sides, from SwiftUI's reserved regions (iOS 27.1+).
struct AdaptiveLibraryFold: Equatable {
    /// Where the area divides, in the Library's own coordinates.
    var position: CGFloat
    /// Space to keep clear of interactive content just before the fold.
    var leadingClearance: CGFloat
    /// Space to keep clear of interactive content just after the fold.
    var trailingClearance: CGFloat

    /// The first vertical division that runs the area's full height. The
    /// region is used even while the system reports it as inactive (as it may
    /// when the device is flat): the native split view divides at the fold in
    /// every unfolded posture.
    static func find(in proxy: GeometryProxy) -> AdaptiveLibraryFold? {
        guard #available(iOS 27.1, *) else { return nil }
        let size = proxy.size
        for region in proxy.reservedRegions(kind: .division, options: .includeInactive) {
            let frame = region.frame
            // The fold itself, without the margins the system adds around it.
            let foldMinX = frame.minX + region.margins.leading
            let foldMaxX = frame.maxX - region.margins.trailing
            let position = (foldMinX + foldMaxX) / 2
            guard frame.height >= size.height - 1,
                  frame.width < size.width / 2,
                  position > 0, position < size.width
            else { continue }
            return AdaptiveLibraryFold(
                position: position,
                leadingClearance: position - frame.minX,
                trailingClearance: frame.maxX - position
            )
        }
        return nil
    }
}

/// The resolved arrangement for one layout pass.
struct AdaptiveLibraryColumns: Equatable {
    var mode: AdaptiveLibraryMode
    var sidebarWidth: CGFloat
    /// Extra space inside the sidebar's trailing edge, e.g. beside a fold.
    var sidebarTrailingClearance: CGFloat = 0
    /// Extra space inside the detail's leading edge in side-by-side mode.
    var detailLeadingClearance: CGFloat = 0
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
            let fold = AdaptiveLibraryFold.find(in: proxy)
            let columns = resolvedColumns(width: proxy.size.width, fold: fold)
            AdaptiveLibraryLayout(
                model: model,
                columns: columns,
                availableWidth: proxy.size.width
            )
            #if DEBUG
            .modifier(AdaptiveLibraryDebug.RegionLog(proxy: proxy, fold: fold, columns: columns))
            #endif
        }
        // Like the native split view, fill the whole tab, including safe areas
        // such as the status bar, the iPhone Duo's rail and the player bar.
        // Each column is hosted in UIKit, which gives it the safe area of the
        // edges it actually touches, so backgrounds reach the edges while
        // content stays clear of them.
        .ignoresSafeArea(.container)
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

    private func resolvedColumns(width: CGFloat, fold: AdaptiveLibraryFold?) -> AdaptiveLibraryColumns {
        var columns = metrics.columns(width: width, horizontalSizeClass: horizontalSizeClass, fold: fold)
        if let debugMode {
            columns.mode = debugMode
        }
        return columns
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

    /// `--sidebar-schedule=show,hide,...` shows or hides the current mode's
    /// sidebar in turn, three seconds apart, like tapping its button.
    static var sidebarSchedule: [Bool] {
        value(for: "--sidebar-schedule=")?
            .split(separator: ",")
            .compactMap { $0 == "show" ? true : $0 == "hide" ? false : nil } ?? []
    }

    /// `--scroll-library-to=N` scrolls the Library list to collection N at launch.
    static var collectionToScrollTo: DemoCollection.ID? {
        value(for: "--scroll-library-to=").flatMap(Int.init)
    }

    #if DEBUG
        /// With `--inspect-native-layout`, writes the reserved division
        /// regions and the resolved columns to `Documents/library-columns.txt`
        /// whenever they change. Read-only.
        struct RegionLog: ViewModifier {
            let proxy: GeometryProxy
            let fold: AdaptiveLibraryFold?
            let columns: AdaptiveLibraryColumns

            func body(content: Content) -> some View {
                let text = description
                return content
                    .onAppear { Self.write(text) }
                    .onChange(of: text) { Self.write(text) }
            }

            private var description: String {
                var lines = ["size=\(proxy.size) safe=\(proxy.safeAreaInsets)"]
                if #available(iOS 27.1, *) {
                    for region in proxy.reservedRegions(kind: .division, options: .includeInactive) {
                        lines.append("division frame=\(region.frame) margins=\(region.margins) active=\(region.isActive)")
                    }
                }
                lines.append("fold=\(String(describing: fold))")
                lines.append("columns=\(columns)")
                return lines.joined(separator: "\n")
            }

            private static func write(_ text: String) {
                guard flag("--inspect-native-layout"),
                      let directory = try? FileManager.default.url(
                          for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
                      )
                else { return }
                try? (text + "\n").write(
                    to: directory.appendingPathComponent("library-columns.txt"), atomically: true, encoding: .utf8
                )
            }
        }
    #endif

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
    let columns: AdaptiveLibraryColumns
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
                    AdaptiveColumnHost(
                        // Beside a fold, keep content clear of it on this side.
                        leadingClearance: isDetailBesideSidebar ? columns.detailLeadingClearance : 0
                    ) {
                        DemoDetailColumn(model: model, isSidebarVisible: sidebarVisibility)
                    }
                    .padding(.leading, isDetailBesideSidebar ? sidebarWidth : 0)
                    .accessibilityHidden(isOverlayShowing)
                }

                // Only present while showing, so VoiceOver never finds a
                // "Hide Sidebar" control with no sidebar to hide.
                if isOverlayShowing {
                    dimming
                        .transition(.opacity)
                }

                libraryStack
            }
            .onAppear {
                if let id = AdaptiveLibraryDebug.collectionToScrollTo {
                    scrollProxy.scrollTo(id, anchor: .top)
                }
            }
        }
        #if DEBUG
        .task {
                for isVisible in AdaptiveLibraryDebug.sidebarSchedule {
                    do {
                        try await Task.sleep(for: .seconds(3))
                    } catch {
                        return
                    }
                    withAnimation(Self.animation) {
                        sidebarVisibility.wrappedValue = isVisible
                    }
                }
            }
        #endif
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
            .fill(.black.opacity(0.2))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: hideOverlay)
            .accessibilityLabel("Hide Sidebar")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, hideOverlay)
    }

    private var libraryStack: some View {
        // Hosted so the sidebar's safe area comes from where it sits, not the
        // whole layout (it mustn't get the iPhone Duo rail's inset from the far
        // edge), and so fold clearance reaches its bar, search and list.
        AdaptiveColumnHost(
            trailingClearance: mode == .stack ? 0 : columns.sidebarTrailingClearance,
            // As a column it never reaches the rail; as the whole Library it may.
            allowsVerticalBar: mode == .stack
        ) {
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

    private var mode: AdaptiveLibraryMode {
        columns.mode
    }

    private var sidebarWidth: CGFloat {
        columns.sidebarWidth
    }

    private var isDetailBesideSidebar: Bool {
        mode == .sideBySide && isPinnedSidebarVisible
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
