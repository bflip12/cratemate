// Scoring Apple Music songs against library files.

import Foundation

/// A song as Apple Music knows it.
public struct SourceTrack: Hashable, Sendable {
    /// The title as shown in Apple Music, including any "(Extended Mix)" or "feat." parts.
    public var title: String
    /// The artist, or an empty string if unknown.
    public var artist: String
    /// The album, or an empty string if unknown. Not used for matching.
    public var album: String
    /// Length in seconds, if known. Used to tell different cuts of the same track apart.
    public var duration: Double?

    /// Creates a source track.
    public init(title: String, artist: String, album: String = "", duration: Double? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
}

/// An audio file in the DJ library.
public struct LibraryTrack: Hashable, Identifiable, Sendable {
    /// Absolute path. This is what goes into the exported playlist.
    public var file: String
    /// The title tag, or a guess from the filename if the file is untagged.
    public var title: String
    /// The artist tag, or a guess from the filename if the file is untagged.
    public var artist: String
    /// The album tag, or an empty string.
    public var album: String
    /// Length in seconds, if it could be read.
    public var duration: Double?
    /// The file path, which is unique within a library.
    public var id: String { file }
    /// The last path component, for display.
    public var filename: String { (file as NSString).lastPathComponent }
    /// "Artist - Title", as written to `#EXTINF` lines.
    public var label: String { "\(artist.isEmpty ? "?" : artist) - \(title)" }
}

/// Scores at or above this are a confident match.
public let matchThreshold = 0.85
/// Scores at or above this (and below ``matchThreshold``) are picked, but flagged for a check.
public let probableThreshold = 0.70

/// A library file that might be the song, with its score.
public struct Candidate: Hashable, Identifiable, Sendable {
    /// The library file.
    public var track: LibraryTrack
    /// How well it matches, from 0 to 1.
    public var score: Double
    /// The file path.
    public var id: String { track.file }
}

/// The outcome of matching one song against the library.
public struct MatchResult: Sendable {
    /// How sure the match is.
    public enum Status: Sendable {
        /// Confident match.
        case ok
        /// Probably right, but worth a look: a low score, or a close runner-up.
        case check
        /// Nothing scored high enough.
        case missing
    }
    /// How sure the match is.
    public var status: Status
    /// The highest-scoring file, if any file shares a word with the title.
    public var best: Candidate?
    /// A different recording that scored within 0.03 of `best`. Set only when that downgraded the status to `check`.
    public var runnerUp: Candidate?
    /// Other files that look like the same recording as `best`.
    public var dupes: [String]
    /// Up to 6 plausible files, best first.
    public var candidates: [Candidate]
}

struct Prepared {
    var core: String
    var coreTokens: Set<String>
    var vtokens: Set<String>
    var artists: Set<String>
    var duration: Double?

    init(title: String, artist: String, duration: Double?) {
        let st = splitTitle(title)
        core = st.core
        coreTokens = Set(st.core.split(separator: " ").map(String.init))
        vtokens = st.vtokens
        artists = artistTokens(artist, st.feats)
        self.duration = duration
    }
}

func overlap(_ a: Set<String>, _ b: Set<String>) -> Double {  // share of the smaller set found in the larger
    guard !a.isEmpty, !b.isEmpty else { return 0 }
    return Double(a.intersection(b).count) / Double(min(a.count, b.count))
}

func dice(_ a: Set<String>, _ b: Set<String>) -> Double {
    if a.isEmpty && b.isEmpty { return 1 }
    if a.isEmpty || b.isEmpty { return 0 }
    return 2 * Double(a.intersection(b).count) / Double(a.count + b.count)
}

func levRatio(_ a: String, _ b: String) -> Double {
    if a == b { return 1 }
    let a = Array(a.unicodeScalars)
    let b = Array(b.unicodeScalars)
    if a.isEmpty || b.isEmpty { return 0 }
    var prev = Array(0...b.count)
    for i in 1...a.count {
        var diag = prev[0]
        prev[0] = i
        for j in 1...b.count {
            let tmp = prev[j]
            prev[j] = min(prev[j] + 1, prev[j - 1] + 1, diag + (a[i - 1] == b[j - 1] ? 0 : 1))
            diag = tmp
        }
    }
    return 1 - Double(prev[b.count]) / Double(max(a.count, b.count))
}

private let cutOnlyWords: Set<String> = [
    "extended", "radio", "edit", "club", "remastered", "remaster", "clean", "explicit",
]

func versionScore(_ a: Set<String>, _ b: Set<String>) -> Double {
    if a.isEmpty && b.isEmpty { return 1 }
    if a.isEmpty || b.isEmpty {
        // extended / radio edit vs plain title: same track, different cut
        return (a.isEmpty ? b : a).isSubset(of: cutOnlyWords) ? 0.6 : 0.2
    }
    return dice(a, b)
}

func score(_ p: Prepared, _ l: Prepared) -> Double {
    let title = max(p.core == l.core ? 1 : 0, dice(p.coreTokens, l.coreTokens), levRatio(p.core, l.core))
    let artist = !p.artists.isEmpty && !l.artists.isEmpty ? overlap(p.artists, l.artists) : 0.5
    let version = versionScore(p.vtokens, l.vtokens)
    var s = 0.5 * title + 0.3 * artist + 0.2 * version
    // Duration is what tells an Extended Mix from an Original Mix
    if let pd = p.duration, let ld = l.duration, pd > 0, ld > 0 {
        let d = abs(pd - ld)
        if d <= 3 { s += 0.1 } else if d <= 10 { s += 0.03 } else if d > 30 { s -= 0.15 }
    }
    return max(0, min(1, s))
}

/// The scanned library, prepared for matching and search.
public final class LibraryIndex: @unchecked Sendable {
    /// Every file in the library, sorted by path.
    public let tracks: [LibraryTrack]
    private let prepared: [Prepared]
    private let byToken: [String: [Int]]
    private let searchHay: [[String]]
    private let byFile: [String: LibraryTrack]

    /// Builds the index. This does all the per-file normalising up front, so matching is fast.
    public init(tracks: [LibraryTrack]) {
        self.tracks = tracks.sorted { $0.file < $1.file }
        byFile = Dictionary(self.tracks.map { ($0.file, $0) }, uniquingKeysWith: { a, _ in a })
        prepared = self.tracks.map { Prepared(title: $0.title, artist: $0.artist, duration: $0.duration) }
        var idx: [String: [Int]] = [:]
        for (i, p) in prepared.enumerated() { for t in p.coreTokens { idx[t, default: []].append(i) } }
        byToken = idx
        searchHay = self.tracks.map { tokens("\($0.artist) \($0.title) \($0.filename)") }
    }

    /// The number of files in the library.
    public var count: Int { tracks.count }

    /// The file at `path`, if it's in the library.
    public func track(at path: String) -> LibraryTrack? { byFile[path] }

    /// Finds the library file that best matches `src`, plus other plausible files and duplicate copies.
    public func match(_ src: SourceTrack) -> MatchResult {
        let p = Prepared(title: src.title, artist: src.artist, duration: src.duration)
        var pool = Set<Int>()
        for t in p.coreTokens { pool.formUnion(byToken[t] ?? []) }
        let ids = pool.isEmpty ? Array(tracks.indices) : Array(pool)
        let ranked = ids.map { (i: $0, s: score(p, prepared[$0])) }
            .sorted { $0.s != $1.s ? $0.s > $1.s : $0.i < $1.i }
        guard let best = ranked.first else { return MatchResult(status: .missing, dupes: [], candidates: []) }

        let b = prepared[best.i]
        func sameRecording(_ i: Int) -> Bool {
            let r = prepared[i]
            guard r.core == b.core, r.vtokens == b.vtokens else { return false }
            guard let rd = r.duration, let bd = b.duration else { return true }
            return abs(rd - bd) <= 1
        }
        let dupes = ranked.filter { $0.i != best.i && sameRecording($0.i) }.map { tracks[$0.i].file }
        let runner = ranked.first { $0.i != best.i && !sameRecording($0.i) }
        let close = runner.map { best.s - $0.s < 0.03 && $0.s >= probableThreshold } ?? false

        var status: MatchResult.Status =
            best.s >= matchThreshold ? .ok : best.s >= probableThreshold ? .check : .missing
        if status == .ok && close { status = .check }

        let candidates = ranked.filter { $0.s >= 0.35 }.prefix(6)
            .map { Candidate(track: tracks[$0.i], score: $0.s) }
        return MatchResult(
            status: status,
            best: Candidate(track: tracks[best.i], score: best.s),
            runnerUp: close ? runner.map { Candidate(track: tracks[$0.i], score: $0.s) } : nil,
            dupes: dupes,
            candidates: candidates)
    }

    /// Free-text search over the library ("artist title", partial words ok).
    public func search(_ query: String, limit: Int = 12) -> [LibraryTrack] {
        let q = tokens(query)
        guard !q.isEmpty else { return [] }
        return tracks.indices
            .compactMap { i -> (Int, Double)? in
                let hay = searchHay[i]
                let hits = q.filter { w in hay.contains { $0.hasPrefix(w) } }.count
                return hits > 0 ? (i, Double(hits) / Double(q.count)) : nil
            }
            .sorted {
                $0.1 != $1.1
                    ? $0.1 > $1.1 : tracks[$0.0].title.localizedCompare(tracks[$1.0].title) == .orderedAscending
            }
            .prefix(limit)
            .map { tracks[$0.0] }
    }
}
