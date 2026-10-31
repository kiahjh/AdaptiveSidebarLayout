@testable import NativeDemo
import Testing

@MainActor
struct DemoModelTests {
    @Test
    func startsWithPredictableFixtures() {
        let model = DemoModel()

        #expect(model.selectedTab == .library)
        #expect(model.selectedCollectionID == nil)
        #expect(model.detailPath.isEmpty)
        #expect(model.collections.count == 24)
        #expect(model.currentTrack == model.collections[0].tracks[0])
        #expect(model.queuedTracks == Array(model.collections[0].tracks.dropFirst()))
        #expect(!model.isPlaying)
    }

    @Test
    func fixtureIdentifiersAreUnique() {
        let collections = DemoFixtures.collections
        let tracks = collections.flatMap(\.tracks)

        #expect(Set(collections.map(\.id)).count == collections.count)
        #expect(Set(tracks.map(\.id)).count == tracks.count)
    }

    @Test
    func searchIgnoresCaseAndSurroundingWhitespace() {
        let model = DemoModel()
        model.query = "  COLLECTION 02  "

        #expect(model.filteredCollections.map(\.id) == [2])

        model.query = "artist 03"
        #expect(model.filteredCollections.map(\.id) == [3])

        model.query = "   "
        #expect(model.filteredCollections == model.collections)
    }

    @Test
    func switchingCollectionsClearsOnlyTheDetailPath() {
        let model = DemoModel()
        model.selectCollection(1)
        model.detailPath = [2, 3]
        model.query = "collection"

        model.selectCollection(4)

        #expect(model.selectedCollection?.id == 4)
        #expect(model.detailPath.isEmpty)
        #expect(model.query == "collection")
    }

    @Test
    func switchingTabsPreservesBrowsingState() {
        let model = DemoModel()
        model.selectCollection(1)
        model.detailPath = [2, 3]
        model.query = "collection"

        model.selectedTab = .queue
        model.selectedTab = .library

        #expect(model.selectedCollection?.id == 1)
        #expect(model.detailPath == [2, 3])
        #expect(model.query == "collection")
    }

    @Test
    func simulatedPlaybackUpdatesTheSharedQueue() {
        let model = DemoModel()
        let tracks = model.collections[2].tracks

        model.play(tracks[3])

        #expect(model.currentTrack == tracks[3])
        #expect(model.queuedTracks == Array(tracks.dropFirst(4)))
        #expect(model.isPlaying)

        model.nextTrack()
        #expect(model.currentTrack == tracks[4])
        #expect(model.queuedTracks == Array(tracks.dropFirst(5)))

        model.togglePlayback()
        #expect(!model.isPlaying)
    }

    @Test
    func advancingAnEmptyQueueDoesNotChangeTheCurrentTrack() {
        let model = DemoModel()
        let lastTrack = model.collections[0].tracks.last!
        model.play(lastTrack)

        model.nextTrack()

        #expect(model.currentTrack == lastTrack)
        #expect(model.queuedTracks.isEmpty)
    }

    @Test
    func resetRestoresTheSameInitialData() {
        let model = DemoModel()
        model.selectCollection(3)
        model.detailPath = [4, 5]
        model.query = "test"
        model.selectedTab = .queue
        model.play(model.collections[2].tracks[4])

        model.reset()

        #expect(model.selectedTab == .library)
        #expect(model.selectedCollectionID == nil)
        #expect(model.detailPath.isEmpty)
        #expect(model.query.isEmpty)
        #expect(model.currentTrack == model.collections[0].tracks[0])
        #expect(model.queuedTracks == Array(model.collections[0].tracks.dropFirst()))
        #expect(!model.isPlaying)
    }
}
