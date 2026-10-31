import Foundation
import Observation

enum DemoTab: Hashable {
    case library
    case queue
}

@MainActor
@Observable
final class DemoModel {
    let collections = DemoFixtures.collections
    var selectedTab = DemoTab.library
    var query = ""
    var detailPath: [DemoCollection.ID] = []
    private(set) var selectedCollectionID: DemoCollection.ID?
    private(set) var currentTrack = DemoFixtures.collections[0].tracks[0]
    private(set) var queuedTracks = Array(DemoFixtures.collections[0].tracks.dropFirst())
    private(set) var isPlaying = false

    var filteredCollections: [DemoCollection] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return collections }
        return collections.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedCollection: DemoCollection? {
        collections.first { $0.id == selectedCollectionID }
    }

    func collection(id: DemoCollection.ID) -> DemoCollection? {
        collections.first { $0.id == id }
    }

    func selectCollection(_ id: DemoCollection.ID?) {
        guard id != selectedCollectionID else { return }
        selectedCollectionID = id
        detailPath.removeAll()
    }

    func play(_ track: DemoTrack) {
        guard let collection = collection(id: track.collectionID),
              let index = collection.tracks.firstIndex(where: { $0.id == track.id }) else { return }
        currentTrack = track
        queuedTracks = Array(collection.tracks.dropFirst(index + 1))
        isPlaying = true
    }

    func togglePlayback() {
        isPlaying.toggle()
    }

    func nextTrack() {
        guard !queuedTracks.isEmpty else { return }
        currentTrack = queuedTracks.removeFirst()
    }

    func reset() {
        selectedTab = .library
        query = ""
        detailPath.removeAll()
        selectedCollectionID = nil
        currentTrack = collections[0].tracks[0]
        queuedTracks = Array(collections[0].tracks.dropFirst())
        isPlaying = false
    }
}
