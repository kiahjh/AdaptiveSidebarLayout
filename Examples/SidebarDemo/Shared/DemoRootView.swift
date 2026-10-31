import SwiftUI

struct DemoRootView<Library: View>: View {
    @State private var model = DemoModel()
    private let library: (DemoModel) -> Library

    init(@ViewBuilder library: @escaping (DemoModel) -> Library) {
        self.library = library
    }

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
        .tint(.indigo)
    }
}

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

private struct DemoPlaybackAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let model: DemoModel

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
                if placement != .inline {
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

            if placement != .inline {
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
