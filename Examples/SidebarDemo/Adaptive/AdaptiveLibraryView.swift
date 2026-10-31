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

    var body: some View {
        GeometryReader { proxy in
            AdaptiveLibraryLayout(
                model: model,
                mode: Self.debugModeOverride
                    ?? metrics.mode(width: proxy.size.width, horizontalSizeClass: horizontalSizeClass),
                sidebarWidth: metrics.sidebarWidth
            )
        }
    }

    private static var debugModeOverride: AdaptiveLibraryMode? {
        #if DEBUG
            // Lets each mode be captured without resizing the window.
            let prefix = "--library-layout="
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) {
                return AdaptiveLibraryMode(rawValue: String(argument.dropFirst(prefix.count)))
            }
        #endif
        return nil
    }
}

private struct AdaptiveLibraryLayout: View {
    let model: DemoModel
    let mode: AdaptiveLibraryMode
    let sidebarWidth: CGFloat
    @State private var isPinnedSidebarVisible = Self.debugFlag("--hide-sidebar") ? false : true
    @State private var isOverlaySidebarVisible = Self.debugFlag("--show-sidebar")

    var body: some View {
        Group {
            switch mode {
            case .sideBySide, .overlay:
                columns
            case .stack:
                AdaptiveLibraryStack(model: model)
            }
        }
        .onAppear {
            #if DEBUG
                // Lets a selected collection be captured without UI automation.
                let prefix = "--select-collection="
                if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
                   let id = Int(argument.dropFirst(prefix.count)), model.selectedCollectionID == nil
                {
                    model.selectCollection(id)
                }
            #endif
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

    /// Side-by-side and overlay share one structure, so switching between them
    /// keeps the sidebar's scroll position and the detail's navigation stack.
    private var columns: some View {
        ZStack(alignment: .leading) {
            DemoDetailColumn(model: model, isSidebarVisible: sidebarVisibility)
                .padding(.leading, mode == .sideBySide && isPinnedSidebarVisible ? sidebarWidth : 0)
                .accessibilityHidden(isOverlayShowing)

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

            // Hidden by sliding it away rather than removing it, so its scroll
            // position and navigation state survive being hidden.
            NavigationStack {
                DemoLibraryBrowser(
                    model: model,
                    placement: .navigationStack,
                    isSidebarVisible: sidebarVisibility
                )
            }
            .frame(width: sidebarWidth)
            .overlay(alignment: .trailing) {
                // The HStack makes the divider vertical.
                HStack(spacing: 0) {
                    Divider()
                }
                .ignoresSafeArea()
            }
            .shadow(color: .black.opacity(isOverlayShowing ? 0.15 : 0), radius: 24)
            .offset(x: isSidebarShowing ? 0 : -sidebarWidth)
            .allowsHitTesting(isSidebarShowing)
            .accessibilityHidden(!isSidebarShowing)
            .accessibilityAction(.escape) {
                if mode == .overlay { hideOverlay() }
            }
        }
    }

    private var sidebarVisibility: Binding<Bool> {
        mode == .sideBySide ? $isPinnedSidebarVisible : $isOverlaySidebarVisible
    }

    private var isSidebarShowing: Bool {
        sidebarVisibility.wrappedValue
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

    private static func debugFlag(_ flag: String) -> Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains(flag)
        #else
            false
        #endif
    }
}

/// Narrow widths: the Library list, with collections pushed onto the same stack.
private struct AdaptiveLibraryStack: View {
    @Bindable var model: DemoModel

    var body: some View {
        NavigationStack(path: $model.stackPath) {
            DemoLibraryBrowser(model: model, placement: .compactStack)
                .navigationDestination(for: DemoCollection.ID.self) { id in
                    if let collection = model.collection(id: id) {
                        DemoCollectionDetail(collection: collection, model: model)
                    }
                }
        }
    }
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
