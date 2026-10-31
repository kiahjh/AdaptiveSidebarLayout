import SwiftUI

/// Where the Library browser is shown. A `NavigationSplitView` sidebar column
/// handles some things automatically that a plain navigation stack doesn't.
enum DemoLibraryPlacement: Equatable {
    /// Native sidebar column. `NavigationLink` rows become sidebar selection,
    /// and automatic search placement puts the field under the title.
    case splitViewSidebar
    /// A plain `NavigationStack` used as a sidebar next to a separate detail
    /// stack. Rows use the list's selection binding. Search uses the
    /// always-visible under-title drawer explicitly, because automatic
    /// placement puts it in the toolbar on iPad.
    case navigationStack
    /// The root of a single `NavigationStack` that also shows the detail.
    /// Rows match `.navigationStack`, plus a chevron; the layout pushes the
    /// selected collection. Search matches `.navigationStack`.
    case compactStack
}

struct DemoLibraryBrowser: View {
    @Bindable var model: DemoModel
    var placement = DemoLibraryPlacement.splitViewSidebar
    /// For custom layouts: shows a hide-sidebar button. `NavigationSplitView`
    /// supplies its own, so Native Demo leaves this `nil`.
    var isSidebarVisible: Binding<Bool>?
    @State private var isSearchPresented = false

    var body: some View {
        list
            .listStyle(.sidebar)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $model.query,
                isPresented: $isSearchPresented,
                placement: searchPlacement,
                prompt: "Search collections"
            )
            .overlay {
                if model.filteredCollections.isEmpty {
                    ContentUnavailableView.search(text: model.query)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset demo", systemImage: "arrow.counterclockwise", action: model.reset)
                }
                if let isSidebarVisible, isSidebarVisible.wrappedValue {
                    ToolbarItem(placement: .topBarTrailing) {
                        DemoSidebarButton(isVisible: isSidebarVisible)
                    }
                }
            }
            .onAppear {
                #if DEBUG
                    // Lets focused-search screenshots be captured without UI automation.
                    if ProcessInfo.processInfo.arguments.contains("--present-search") {
                        isSearchPresented = true
                    }
                #endif
            }
    }

    /// One `List` for every placement, so a layout that changes placement
    /// keeps the same list and its scroll position. Only the rows differ.
    private var list: some View {
        List(selection: selection) {
            ForEach(model.filteredCollections) { collection in
                switch placement {
                case .splitViewSidebar:
                    NavigationLink(value: collection.id) {
                        DemoCollectionRow(collection: collection)
                    }
                case .navigationStack, .compactStack:
                    // The same row in both custom placements, so switching
                    // between them doesn't rebuild rows or move the list.
                    DemoCollectionRow(collection: collection, showsChevron: placement == .compactStack)
                        .tag(collection.id)
                }
            }
        }
    }

    private var searchPlacement: SearchFieldPlacement {
        switch placement {
        case .splitViewSidebar: .automatic
        // Always visible, like the native sidebar's field. This makes the
        // large title start collapsed, which is accepted.
        case .navigationStack, .compactStack: .navigationBarDrawer(displayMode: .always)
        }
    }

    private var selection: Binding<DemoCollection.ID?> {
        Binding(
            get: { model.selectedCollectionID },
            set: { model.selectCollection($0) }
        )
    }
}

private struct DemoCollectionRow: View {
    let collection: DemoCollection
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            DemoArtwork(collection: collection)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.title)
                    .font(.headline)
                Text(collection.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if showsChevron {
                // Like a navigation link's indicator, for rows that push.
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The Library's detail column: the selected collection, with deeper
/// navigation in its own stack. Shared by the native and custom layouts.
struct DemoDetailColumn: View {
    @Bindable var model: DemoModel
    /// For custom layouts: shows a show-sidebar button while it's hidden.
    /// `NavigationSplitView` supplies its own, so Native Demo leaves this `nil`.
    var isSidebarVisible: Binding<Bool>?

    var body: some View {
        NavigationStack(path: $model.detailPath) {
            Group {
                if let collection = model.selectedCollection {
                    DemoCollectionDetail(collection: collection, model: model)
                } else {
                    ContentUnavailableView(
                        "Choose a collection",
                        systemImage: "square.stack",
                        description: Text("Select a collection from the library sidebar.")
                    )
                }
            }
            .toolbar { showSidebarItem }
            .navigationDestination(for: DemoCollection.ID.self) { id in
                if let collection = model.collection(id: id) {
                    DemoCollectionDetail(collection: collection, model: model)
                        .toolbar { showSidebarItem }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var showSidebarItem: some ToolbarContent {
        if let isSidebarVisible, !isSidebarVisible.wrappedValue {
            ToolbarItem(placement: .topBarLeading) {
                DemoSidebarButton(isVisible: isSidebarVisible)
            }
        }
    }
}

/// Shows or hides a custom layout's sidebar, with the same symbol and
/// keyboard shortcut as the native split view's button.
struct DemoSidebarButton: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button(isVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left") {
            withAnimation(.smooth(duration: 0.35)) {
                isVisible.toggle()
            }
        }
        .keyboardShortcut("s", modifiers: [.control, .command])
    }
}

struct DemoCollectionDetail: View {
    let collection: DemoCollection
    let model: DemoModel

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    DemoArtwork(collection: collection)
                        .frame(width: 180, height: 180)
                        .accessibilityHidden(true)
                    Text(collection.title)
                        .font(.title2.bold())
                    Text(collection.artist)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            Section("Tracks") {
                ForEach(collection.tracks) { track in
                    Button {
                        model.play(track)
                    } label: {
                        DemoTrackRow(track: track, isCurrent: model.currentTrack.id == track.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Simulate playing \(track.title)")
                }
            }

            Section("Explore another collection") {
                ForEach(model.collections.filter { $0.id != collection.id }.prefix(3)) { other in
                    NavigationLink(other.title, value: other.id)
                }
            }
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DemoQueueView: View {
    let model: DemoModel

    var body: some View {
        List {
            Section("Now Playing") {
                DemoTrackRow(track: model.currentTrack, isCurrent: true)
            }

            Section {
                if model.queuedTracks.isEmpty {
                    Text("No upcoming tracks")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.queuedTracks) { track in
                        DemoTrackRow(track: track, isCurrent: false)
                    }
                }
            } header: {
                Text("Up Next")
            } footer: {
                Text("Playback is simulated. This demo needs no audio access or internet connection.")
            }
        }
        .navigationTitle("Queue")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset demo", systemImage: "arrow.counterclockwise", action: model.reset)
            }
        }
    }
}

struct DemoArtwork: View {
    let collection: DemoCollection

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(collection.color.gradient)
            .overlay {
                Image(systemName: collection.symbol)
                    .font(.title)
                    .foregroundStyle(.white)
            }
    }
}

private struct DemoTrackRow: View {
    let track: DemoTrack
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(track.number.formatted())
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Text(track.collectionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "music.note")
                    .foregroundStyle(.indigo)
                    .accessibilityLabel("Current track")
            }
        }
        .padding(.vertical, 4)
    }
}
