import Foundation
import SwiftUI

struct DemoCollection: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let artist: String
    let tracks: [DemoTrack]

    var color: Color {
        switch id % 4 {
        case 0: .orange
        case 1: .indigo
        case 2: .teal
        default: .pink
        }
    }

    var symbol: String {
        switch id % 4 {
        case 0: "pianokeys"
        case 1: "music.note"
        case 2: "guitars"
        default: "waveform"
        }
    }
}

struct DemoTrack: Identifiable, Hashable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let artist: String
    let collectionID: DemoCollection.ID
    let collectionTitle: String
}

enum DemoFixtures {
    static let collections: [DemoCollection] = (1 ... 24).map { collectionNumber in
        let title = String(format: "Collection %02d", collectionNumber)
        let artist = String(format: "Artist %02d", collectionNumber)
        return DemoCollection(
            id: collectionNumber,
            title: title,
            artist: artist,
            tracks: (1 ... 8).map { trackNumber in
                DemoTrack(
                    id: collectionNumber * 100 + trackNumber,
                    number: trackNumber,
                    title: String(format: "Track %02d", trackNumber),
                    artist: artist,
                    collectionID: collectionNumber,
                    collectionTitle: title
                )
            }
        )
    }
}
