import SwiftUI

/// The demo apps' shared shell: Library and Queue tabs plus a simulated player.
///
/// iOS 26 and later use the system tab bar's bottom accessory for the player.
/// iOS 17 through 25 get a fallback with classic tab items and the player bar
/// placed above the tab bar inside each tab, so the layouts can be tested on
/// every supported OS.
struct DemoRootView<Library: View>: View {
    @State private var model = DemoModel()
    private let library: (DemoModel) -> Library

    init(@ViewBuilder library: @escaping (DemoModel) -> Library) {
        self.library = library
    }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                DemoAccessoryTabs(model: model, library: library)
            } else {
                DemoClassicTabs(model: model, library: library)
            }
        }
        .onAppear {
            #if DEBUG
                // `--select-collection=N` selects collection N at launch, so
                // both apps can be captured in the same state.
                let prefix = "--select-collection="
                if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
                   let id = Int(argument.dropFirst(prefix.count)), model.selectedCollectionID == nil
                {
                    model.selectCollection(id)
                }
            #endif
        }
        .tint(.indigo)
    }
}

/// iOS 26+: `Tab` values, the tab bar's bottom accessory, and minimization.
@available(iOS 26, *)
private struct DemoAccessoryTabs<Library: View>: View {
    @Bindable var model: DemoModel
    let library: (DemoModel) -> Library

    var body: some View {
        TabView(selection: $model.selectedTab) {
            Tab("Library", systemImage: "square.grid.2x2", value: DemoTab.library) {
                library(model)
            }

            Tab("Queue", systemImage: "list.bullet", value: DemoTab.queue) {
                NavigationStack {
                    DemoQueueView(model: model)
                }
            }
        }
        .modifier(DemoPlaybackAccessoryAttachment(model: model))
        .modifier(DemoTabBarMinimizationAttachment())
    }
}

/// iOS 17–25: classic tab items, with the player bar above the tab bar.
private struct DemoClassicTabs<Library: View>: View {
    @Bindable var model: DemoModel
    let library: (DemoModel) -> Library

    var body: some View {
        TabView(selection: $model.selectedTab) {
            library(model)
                .safeAreaInset(edge: .bottom) { DemoPlayerBar(model: model) }
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
                .tag(DemoTab.library)

            NavigationStack {
                DemoQueueView(model: model)
            }
            .safeAreaInset(edge: .bottom) { DemoPlayerBar(model: model) }
            .tabItem { Label("Queue", systemImage: "list.bullet") }
            .tag(DemoTab.queue)
        }
    }
}

@available(iOS 26, *)
private struct DemoTabBarMinimizationAttachment: ViewModifier {
    private var omitsMinimization: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("--without-tab-minimization")
        #else
            false
        #endif
    }

    func body(content: Content) -> some View {
        if omitsMinimization {
            // Omit the modifier itself to isolate its layout participation,
            // rather than attaching it with an explicit `.never` value.
            content
        } else {
            content.tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}

@available(iOS 26, *)
private struct DemoPlaybackAccessoryAttachment: ViewModifier {
    let model: DemoModel

    private var hidesAccessory: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("--without-accessory")
        #else
            false
        #endif
    }

    func body(content: Content) -> some View {
        if hidesAccessory {
            // Omit the modifier itself, not just its visible content, so this
            // control removes the accessory's participation in native layout.
            content
        } else {
            content.tabViewBottomAccessory {
                DemoPlaybackAccessory(model: model)
            }
        }
    }
}

/// The player inside the iOS 26 tab bar accessory, which can be inline.
@available(iOS 26, *)
private struct DemoPlaybackAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let model: DemoModel

    var body: some View {
        DemoPlaybackControls(model: model, isCompact: placement == .inline)
    }
}

/// The fallback player bar for iOS 17–25.
private struct DemoPlayerBar: View {
    let model: DemoModel

    var body: some View {
        DemoPlaybackControls(model: model, isCompact: false)
            .padding(.vertical, 4)
            .background(.bar, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }
}

private struct DemoPlaybackControls: View {
    let model: DemoModel
    let isCompact: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let collection = model.collection(id: model.currentTrack.collectionID) {
                DemoArtwork(collection: collection)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.currentTrack.title)
                    .font(.subheadline.weight(.semibold))
                if !isCompact {
                    Text(model.currentTrack.collectionTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: model.togglePlayback) {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(model.isPlaying ? "Pause simulated playback" : "Start simulated playback")

            if !isCompact {
                Button(action: model.nextTrack) {
                    Image(systemName: "forward.fill")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(model.queuedTracks.isEmpty)
                .accessibilityLabel("Next track")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
