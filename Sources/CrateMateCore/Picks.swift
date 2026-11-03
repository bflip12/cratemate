// Remembering the user's picks, so a song fixed once stays fixed in every playlist and after a
// relaunch. Picks are keyed by song, not by playlist: the right file for a song doesn't depend on
// which playlist it's in.

import Foundation

/// `picks.json` in ``appSupportDir``, where ``PickStore`` saves the user's picks.
public let picksFile = appSupportDir.appendingPathComponent("picks.json")

/// A choice the user made for one song in the review list.
public struct SavedPick: Codable, Hashable, Sendable {
    /// Path of the chosen file, or `nil` if the song was skipped.
    public var file: String?
    /// Path of the matcher's best file when the choice was made, if it had one.
    ///
    /// A skip only holds while this is still the best file, so a song that later turns up in the
    /// DJ folder isn't kept out of the export.
    public var best: String?

    /// Creates a saved pick.
    public init(file: String?, best: String?) {
        self.file = file
        self.best = best
    }
}

/// What a saved pick means for a song after a scan.
public enum RestoredPick: Equatable, Sendable {
    /// Use this file.
    case use(LibraryTrack)
    /// Leave the song out of the export.
    case skip
}

/// The user's picks for every song they've decided on, saved in `picks.json` in ``appSupportDir``.
public struct PickStore: Sendable {
    /// Saved picks keyed by ``key(for:)``.
    public private(set) var picks: [String: SavedPick]

    /// Creates a store holding `picks`.
    public init(picks: [String: SavedPick] = [:]) {
        self.picks = picks
    }

    /// Identifies a song across playlists: its normalised artist and title.
    ///
    /// The length isn't part of it, because Apple Music and its text export round it differently.
    public static func key(for src: SourceTrack) -> String {
        "\(norm(src.artist))\t\(norm(src.title))"
    }

    /// The number of songs with a saved pick.
    public var count: Int { picks.count }

    /// The saved pick for `src`, if there is one.
    public subscript(src: SourceTrack) -> SavedPick? {
        get { picks[Self.key(for: src)] }
        set { picks[Self.key(for: src)] = newValue }
    }

    /// Forgets every saved pick.
    public mutating func removeAll() { picks = [:] }

    /// The saved pick for `src`, if it still applies to this scan of the DJ folder.
    ///
    /// A picked file applies while it's still in `index`. A skip applies while the matcher's best
    /// file is the same one it was when the song was skipped.
    public func restore(_ src: SourceTrack, result: MatchResult, in index: LibraryIndex) -> RestoredPick? {
        guard let saved = self[src] else { return nil }
        if let file = saved.file {
            return index.track(at: file).map { .use($0) }
        }
        return saved.best == result.best?.track.file ? .skip : nil
    }

    /// Reads the store from `url`. A missing or unreadable file gives an empty store.
    public static func load(from url: URL = picksFile) -> PickStore {
        guard let data = try? Data(contentsOf: url),
            let picks = try? JSONDecoder().decode([String: SavedPick].self, from: data)
        else { return PickStore() }
        return PickStore(picks: picks)
    }

    /// Writes the store to `url`, creating its folder if needed.
    public func save(to url: URL = picksFile) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(picks).write(to: url, options: .atomic)
    }
}
