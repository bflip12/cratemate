// App state: playlists, the scanned library, per-row picks and export.

import AppKit
import CrateMateCore
import Observation

@Observable final class RowReview: Identifiable {
    let id: Int
    let src: SourceTrack
    let result: MatchResult
    /// Files offered in the picker: the match candidates plus anything picked from search.
    var options: [LibraryTrack]
    var scores: [String: Double]
    /// File path of the chosen track; nil means skip.
    var pick: String? { didSet { if pick != oldValue { touched = true } } }
    private(set) var touched = false
    /// UI state for the library search popover.
    var searching = false
    var searchQuery = ""

    init(id: Int, src: SourceTrack, result: MatchResult) {
        self.id = id
        self.src = src
        self.result = result
        options = result.candidates.map(\.track)
        scores = Dictionary(result.candidates.map { ($0.track.file, $0.score) }, uniquingKeysWith: { a, _ in a })
        pick = result.status == .missing ? nil : result.best?.track.file
        touched = false  // the initial pick isn't a user change
    }

    var picked: LibraryTrack? { pick.flatMap { p in options.first { $0.file == p } } }
    var needsAttention: Bool { result.status != .ok }

    func choose(_ t: LibraryTrack) {
        if !options.contains(t) { options.append(t) }
        pick = t.file
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

    func count(_ s: MatchResult.Status) -> Int { rows.filter { $0.result.status == s }.count }
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
    var selection: Set<String> = [] { didSet { matchSelected() } }

    var index: LibraryIndex?
    var scan: ScanState = .idle
    var reviews: [String: PlaylistReview] = [:]
    var showAll = false
    var playlistFilter = ""

    var exported: [URL] = []
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
            reviews = [:]  // picks were made against the old scan
            matchSelected()
        }
    }

    // MARK: Matching

    func matchSelected() {
        guard let index else { return }
        for p in selectedPlaylists where reviews[p.id] == nil {
            Task {
                let results = await Task.detached { p.tracks.map { index.match($0) } }.value
                guard self.index === index else { return }
                reviews[p.id] = PlaylistReview(
                    playlist: p,
                    rows: zip(p.tracks, results).enumerated().map { RowReview(id: $0, src: $1.0, result: $1.1) })
            }
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
                playlists.insert(p, at: 0)
                selection.insert(p.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Export

    var canExport: Bool { selectedPlaylists.contains { reviews[$0.id] != nil } }

    func export() {
        let dir = URL(fileURLWithPath: outputPath, isDirectory: true)
        var written: [URL] = []
        for p in selectedPlaylists {
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

    func revealExported() {
        NSWorkspace.shared.activateFileViewerSelecting(exported)
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
