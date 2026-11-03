// App state: playlists, the scanned library, per-row picks and export.

import AppKit
import CrateMateCore
import Observation
import SwiftUI

/// A 0–1 match score as a whole percentage, e.g. "78%".
func percent(_ score: Double) -> String { "\(Int((score * 100).rounded()))%" }

/// How a row stands now, counting the user's decisions.
enum RowState {
    /// Matched with confidence, or the user chose the file.
    case matched
    /// The matcher's pick is probably right, and the user hasn't looked yet.
    case check
    /// Not found, and the user hasn't decided yet.
    case missing
    /// The user left it out of the export.
    case skipped
}

@Observable final class RowReview: Identifiable {
    let id: Int
    let src: SourceTrack
    let result: MatchResult
    /// Files offered in the picker: the match candidates plus anything picked from search.
    var options: [LibraryTrack]
    var scores: [String: Double]
    /// File path of the chosen track; nil means skip.
    private(set) var pick: String?
    /// Whether the user has decided on this song: chose a file, skipped it or kept the suggested
    /// match, in this playlist, another one or an earlier session.
    private(set) var decided = false
    /// UI state for the library search popover.
    var searching = false
    var searchQuery = ""

    init(id: Int, src: SourceTrack, result: MatchResult, restored: RestoredPick?) {
        self.id = id
        self.src = src
        self.result = result
        options = result.candidates.map(\.track)
        scores = Dictionary(result.candidates.map { ($0.track.file, $0.score) }, uniquingKeysWith: { a, _ in a })
        apply(restored)
    }

    var picked: LibraryTrack? { pick.flatMap { p in options.first { $0.file == p } } }
    /// Still to look at: the matcher wasn't sure, and the user hasn't decided yet.
    var needsAttention: Bool { !decided && result.status != .ok }

    var state: RowState {
        if decided { return pick == nil ? .skipped : .matched }
        switch result.status {
        case .ok: return .matched
        case .check: return .check
        case .missing: return .missing
        }
    }

    /// Why the matcher wasn't sure, for a row that still needs attention.
    var reason: String? {
        guard needsAttention, let best = result.best else { return nil }
        if let other = result.runnerUp {
            return "Another file scores \(percent(other.score)): \(other.track.filename)"
        }
        if result.status == .missing {
            return "The closest file scores \(percent(best.score)): \(best.track.filename)"
        }
        let parts = differences(src, best.track).map { d -> String in
            switch d {
            case .version: return "different version"
            case .title: return "different title"
            case .artist: return "different artist (\(best.track.artist))"
            case .noSongArtist: return "no artist in Apple Music"
            case .noFileArtist: return "no artist on the file"
            case .length(let secs): return "\(fmtDur(abs(secs))) \(secs > 0 ? "longer" : "shorter")"
            }
        }
        guard let first = parts.first else { return "Close, but not a confident match" }
        return (first.prefix(1).uppercased() + first.dropFirst() + parts.dropFirst().map { ", \($0)" }.joined())
    }

    /// Shows a saved pick, or the matcher's own pick if there's none.
    func apply(_ restored: RestoredPick?) {
        switch restored {
        case .use(let track):
            if !options.contains(track) { options.append(track) }
            pick = track.file
            decided = true
        case .skip:
            pick = nil
            decided = true
        case nil:
            pick = result.status == .missing ? nil : result.best?.track.file
            decided = false
        }
    }
}

@Observable final class PlaylistReview: Identifiable {
    let playlist: Playlist
    let rows: [RowReview]
    var id: String { playlist.id }

    init(playlist: Playlist, rows: [RowReview]) {
        self.playlist = playlist
        self.rows = rows
    }

    func count(_ s: RowState) -> Int { rows.filter { $0.state == s }.count }
    /// Nothing in the playlist was found in the DJ folder.
    var noneFound: Bool { rows.allSatisfy { $0.result.status == .missing } }
    /// Rows whose file is already used by an earlier row, so it would be in the export twice.
    var repeatedRows: Set<Int> {
        var seen = Set<String>()
        var out = Set<Int>()
        for row in rows {
            guard let file = row.pick else { continue }
            if !seen.insert(file).inserted { out.insert(row.id) }
        }
        return out
    }
    var leftToCheck: Int { rows.filter(\.needsAttention).count }
    var exportTracks: [LibraryTrack] { rows.compactMap(\.picked) }
}

enum ScanState: Equatable {
    case idle
    case scanning(done: Int, total: Int)
    case ready
}

@Observable @MainActor final class AppModel {
    static let shared = AppModel()

    /// Settings saved before the app was renamed from am2rb, under its old bundle identifier.
    private static let legacyDefaults = UserDefaults(suiteName: "com.bobbyf.am2rb")

    var libraryPath: String? =
        UserDefaults.standard.string(forKey: "library") ?? legacyDefaults?.string(forKey: "library")
    {
        didSet { UserDefaults.standard.set(libraryPath, forKey: "library") }
    }
    var outputPath: String =
        UserDefaults.standard.string(forKey: "output")
        ?? legacyDefaults?.string(forKey: "output")
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/CrateMate").path
    {
        didSet { UserDefaults.standard.set(outputPath, forKey: "output") }
    }
    /// How Apple Music folders start out in the sidebar. Changing it resets every folder to match.
    var expandFolders: Bool = UserDefaults.standard.bool(forKey: "expandFolders") {
        didSet {
            UserDefaults.standard.set(expandFolders, forKey: "expandFolders")
            folderExpanded = [:]
        }
    }
    /// Folders opened or closed by hand this session; the rest follow `expandFolders`.
    var folderExpanded: [String: Bool] = [:]

    var playlists: [Playlist] = []
    var playlistsError: String?
    var playlistsLoading = false
    var selection: Set<String> = [] { didSet { matchPlaylists() } }

    var index: LibraryIndex?
    var scan: ScanState = .idle
    var reviews: [String: PlaylistReview] = [:]
    var showAll = false
    var playlistFilter = ""

    /// Picks the user made, by song. Restored into each review as it's built.
    private(set) var picks = PickStore.load()
    var confirmingForgetPicks = false
    /// The main window's undo manager, for undoing decisions in the review list.
    weak var undoManager: UndoManager?

    var exported: [URL] = []
    /// Selected playlists left out of the last export because they had no songs to export.
    var leftOut: [String] = []
    var errorMessage: String?

    var selectedPlaylists: [Playlist] { playlists.filter { selection.contains($0.id) } }

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        loadPlaylists()
        if libraryPath != nil { scanLibrary() }
    }

    func loadPlaylists() {
        playlistsLoading = true
        Task {
            defer { playlistsLoading = false }
            do {
                playlists = try await Task.detached { try loadAppleMusicPlaylists() }.value
                playlistsError = nil
                matchPlaylists()
            } catch {
                playlistsError =
                    "Couldn't read your Apple Music library. Allow CrateMate in System Settings › Privacy & Security › Media & Apple Music, or open a playlist exported as Unicode Text."
            }
        }
    }

    // MARK: Library

    func chooseLibrary() {
        guard let url = pickFolder(message: "Choose the folder with your DJ files (the ones Rekordbox uses).") else {
            return
        }
        libraryPath = url.path
        scanLibrary()
    }

    func chooseOutput() {
        guard let url = pickFolder(message: "Choose where to save the .m3u8 playlists.") else { return }
        outputPath = url.path
    }

    func scanLibrary(rescan: Bool = false) {
        guard let path = libraryPath, scan == .idle || scan == .ready else { return }
        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "The DJ folder \(path) isn't there any more. Is the drive connected?"
            return
        }
        scan = .scanning(done: 0, total: 0)
        Task {
            let result = await CrateMateCore.scanLibrary(URL(fileURLWithPath: path), rescan: rescan) { done, total in
                Task { @MainActor in
                    if case .scanning = self.scan { self.scan = .scanning(done: done, total: total) }
                }
            }
            index = result.index
            scan = .ready
            reviews = [:]  // rebuilt against the new scan, with saved picks restored
            matching = []
            matchPlaylists()
        }
    }

    // MARK: Matching

    /// Playlists being matched right now, so a playlist isn't matched twice at once.
    private var matching: Set<String> = []

    /// Matches every playlist that hasn't been matched against this scan yet, selected ones
    /// first. Every playlist is matched, not just the selected ones, so the sidebar can show how
    /// much of each was found.
    func matchPlaylists() {
        guard let index else { return }
        let todo = selectedPlaylists + playlists.filter { !selection.contains($0.id) }
        for p in todo where reviews[p.id] == nil && !matching.contains(p.id) {
            matching.insert(p.id)
            Task {
                let results = await Task.detached { p.tracks.map { index.match($0) } }.value
                guard self.index === index else { return }
                matching.remove(p.id)
                reviews[p.id] = PlaylistReview(
                    playlist: p,
                    rows: zip(p.tracks, results).enumerated().map { i, pair in
                        RowReview(
                            id: i, src: pair.0, result: pair.1,
                            restored: picks.restore(pair.0, result: pair.1, in: index))
                    })
            }
        }
    }

    // MARK: Picks

    /// Records the user's choice for `row` (nil to skip it), remembers it, and applies it to the same
    /// song in every other loaded playlist.
    func decide(_ row: RowReview, _ track: LibraryTrack?) {
        let name = track == nil ? "Skip" : track?.file == row.pick ? "Keep Match" : "Choose File"
        setPicks([(row.src, SavedPick(file: track?.file, best: row.result.best?.track.file))], undoName: name)
    }

    /// Keeps the current choice for every row in `review` that's still left to check.
    func acceptAll(in review: PlaylistReview) {
        let changes = review.rows.filter(\.needsAttention).map { row in
            (row.src, SavedPick?.some(SavedPick(file: row.pick, best: row.result.best?.track.file)))
        }
        setPicks(changes, undoName: "Accept All")
    }

    func forgetPicks() {
        picks.removeAll()
        savePicks()
        undoManager?.removeAllActions(withTarget: self)
        reviews = [:]
        matching = []
        matchPlaylists()
    }

    /// Saves `changes` (nil forgets a song's pick), updates every loaded row of those songs, and
    /// registers an undo that puts the old picks back.
    ///
    /// Rows are found by song rather than kept from before, so undo still works after a rescan
    /// rebuilds them.
    private func setPicks(_ changes: [(SourceTrack, SavedPick?)], undoName: String) {
        let before = changes.map { src, _ in (src, picks[src]) }
        if let undoManager {
            undoManager.registerUndo(withTarget: self) { model in
                MainActor.assumeIsolated {
                    withAnimation { model.setPicks(before, undoName: undoName) }
                }
            }
            undoManager.setActionName(undoName)
        }
        for (src, pick) in changes { picks[src] = pick }
        savePicks()

        guard let index else { return }
        let keys = Set(changes.map { PickStore.key(for: $0.0) })
        for review in reviews.values {
            for row in review.rows where keys.contains(PickStore.key(for: row.src)) {
                row.apply(picks.restore(row.src, result: row.result, in: index))
            }
        }
    }

    private func savePicks() {
        do {
            try picks.save()
        } catch {
            errorMessage =
                "Couldn't save your picks, so they'll be forgotten when CrateMate quits. \(error.localizedDescription)"
        }
    }

    // MARK: Fallback: exported .txt

    func openExportFile() {
        let panel = NSOpenPanel()
        panel.message = "Choose a playlist exported from Apple Music with Format: Unicode Text."
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do {
                let p = try parseExport(url)
                playlists.removeAll { $0.id == p.id }
                reviews[p.id] = nil  // the file may have changed since it was last opened
                playlists.insert(p, at: 0)
                selection.insert(p.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Export

    /// Selected playlists with at least one song to export.
    var exportable: [Playlist] { selectedPlaylists.filter { reviews[$0.id]?.exportTracks.isEmpty == false } }
    var canExport: Bool { !exportable.isEmpty }

    func export() {
        let dir = URL(fileURLWithPath: outputPath, isDirectory: true)
        var written: [URL] = []
        leftOut = selectedPlaylists.filter { reviews[$0.id]?.exportTracks.isEmpty == true }.map(\.name)
        for p in exportable {
            guard let r = reviews[p.id] else { continue }
            do {
                written.append(try writeM3U(name: p.name, tracks: r.exportTracks, to: dir))
            } catch {
                errorMessage = "Couldn't write \(p.name).m3u8: \(error.localizedDescription)"
                return
            }
        }
        exported = written
    }

    /// Copies "Artist – Title" for each song in `review` that wasn't found, one per line.
    func copyNotFound(in review: PlaylistReview) {
        let lines = review.rows.filter { $0.result.status == .missing }.map { row in
            row.src.artist.isEmpty ? row.src.title : "\(row.src.artist) – \(row.src.title)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    func revealExported() {
        NSWorkspace.shared.activateFileViewerSelecting(exported)
    }

    /// Selects the files in Finder. Only reveals them: CrateMate never changes the DJ folder.
    func reveal(_ files: [String]) {
        NSWorkspace.shared.activateFileViewerSelecting(files.map { URL(fileURLWithPath: $0) })
    }

    private func pickFolder(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
