import Foundation
import Testing

@testable import CrateMateCore

@Test func normalising() {
    #expect(norm("Café del Mar") == "cafe del mar")
    #expect(norm("Above & Beyond") == "above and beyond")
    #expect(norm("  Καλημέρα!! ") == "καλημερα")
    #expect(norm("Track_A--(VIP)") == "track a vip")
}

@Test func splittingTitles() {
    let a = splitTitle("Song B (Joe Remix)")
    #expect(a.core == "song b")
    #expect(a.vtokens == ["joe", "remix"])

    let b = splitTitle("Lose Yourself (feat. Bob)")
    #expect(b.core == "lose yourself")
    #expect(b.feats == ["Bob"])
    #expect(b.vtokens.isEmpty)

    let c = splitTitle("Track A - Extended Mix")
    #expect(c.core == "track a")
    #expect(c.vtokens == ["extended"])

    let d = splitTitle("Strings of Life ft. Someone")
    #expect(d.core == "strings of life")
    #expect(d.feats == ["Someone"])
}

@Test func filenameFallback() {
    let f = fromFilename("/x/02 - Kerri Chandler - Rain.wav")
    #expect(f.artist == "Kerri Chandler")
    #expect(f.title == "Rain")
    #expect(fromFilename("/x/Rain.wav").title == "Rain")
}

private func lt(_ file: String, _ artist: String, _ title: String, _ dur: Double) -> LibraryTrack {
    LibraryTrack(file: "/lib/\(file)", title: title, artist: artist, album: "", duration: dur)
}

@Test func durationPicksTheRightCut() {
    let idx = LibraryIndex(tracks: [
        lt("a1.mp3", "Mr Fingers", "Track A (Original Mix)", 390),
        lt("a2.mp3", "Mr Fingers", "Track A (Extended Mix)", 465),
    ])
    let short = idx.match(SourceTrack(title: "Track A", artist: "Mr Fingers", duration: 390))
    #expect(short.best?.track.file == "/lib/a1.mp3")
    #expect(short.status == .ok)
    let long = idx.match(SourceTrack(title: "Track A", artist: "Mr Fingers", duration: 466))
    #expect(long.best?.track.file == "/lib/a2.mp3")
}

@Test func remixVersusPlain() {
    let idx = LibraryIndex(tracks: [
        lt("b.mp3", "Moodymann", "Song B", 300),
        lt("b2.mp3", "Moodymann", "Song B (Joe Remix)", 420),
    ])
    #expect(
        idx.match(SourceTrack(title: "Song B (Joe Remix)", artist: "Moodymann", duration: 421)).best?.track.file
            == "/lib/b2.mp3")
    #expect(
        idx.match(SourceTrack(title: "Song B", artist: "Moodymann", duration: 300)).best?.track.file == "/lib/b.mp3")
}

@Test func missingAndSearch() {
    let idx = LibraryIndex(tracks: [lt("s.mp3", "Rhythim Is Rhythim", "Strings of Life", 480)])
    #expect(idx.match(SourceTrack(title: "Not In Library", artist: "Nobody", duration: 200)).status == .missing)
    #expect(idx.search("rhyth strin").first?.file == "/lib/s.mp3")
    #expect(idx.search("zzz").isEmpty)
}

@Test func m3uOutput() {
    let text = m3uText([lt("s.mp3", "A", "B", 200.4)])
    #expect(text == "#EXTM3U\n#EXTINF:200,A - B\n/lib/s.mp3\n")
}

@Test func parsesUnicodeTextExport() throws {
    let rows = [
        "Name\tArtist\tComposer\tAlbum\tTime\tLocation", "Café\tÉnergie\t\tX\t409\t",
        "Rain\tKerri Chandler\t\tY\t6:01\t",
    ]
    var data = Data([0xFF, 0xFE])
    data.append(rows.joined(separator: "\r").data(using: .utf16LittleEndian)!)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("cratemate-test-export.txt")
    try data.write(to: url)
    let p = try parseExport(url)
    #expect(p.tracks.count == 2)
    #expect(p.tracks[0] == SourceTrack(title: "Café", artist: "Énergie", album: "X", duration: 409))
    #expect(p.tracks[1].duration == 361)
}

@Test func savedPickFollowsTheSongAcrossPlaylists() {
    var store = PickStore()
    store[SourceTrack(title: "Organic Liquid Tester (Original Mix)", artist: "Cryme")] = SavedPick(
        file: "/lib/olt.mp3", best: nil)
    #expect(store[SourceTrack(title: "Organic Liquid Tester (Original Mix)", artist: "CRYME", duration: 339)] != nil)
    #expect(store[SourceTrack(title: "Organic Liquid Tester (Extended Mix)", artist: "Cryme")] == nil)
}

@Test func savedFileAppliesWhileItIsInTheDJFolder() {
    let src = SourceTrack(title: "Track A", artist: "Mr Fingers", duration: 390)
    var store = PickStore()
    store[src] = SavedPick(file: "/lib/a2.mp3", best: "/lib/a1.mp3")

    let both = LibraryIndex(tracks: [
        lt("a1.mp3", "Mr Fingers", "Track A (Original Mix)", 390),
        lt("a2.mp3", "Mr Fingers", "Track A (Extended Mix)", 465),
    ])
    #expect(store.restore(src, result: both.match(src), in: both) == .use(both.track(at: "/lib/a2.mp3")!))

    let moved = LibraryIndex(tracks: [lt("a1.mp3", "Mr Fingers", "Track A (Original Mix)", 390)])
    #expect(store.restore(src, result: moved.match(src), in: moved) == nil)
}

@Test func skipHoldsUntilABetterFileTurnsUp() {
    let src = SourceTrack(title: "Strings of Life", artist: "Rhythim Is Rhythim", duration: 480)
    let before = LibraryIndex(tracks: [lt("s.mp3", "Someone Else", "Strings", 200)])
    var store = PickStore()
    store[src] = SavedPick(file: nil, best: before.match(src).best?.track.file)
    #expect(store.restore(src, result: before.match(src), in: before) == .skip)

    let after = LibraryIndex(tracks: [
        lt("s.mp3", "Someone Else", "Strings", 200),
        lt("sol.mp3", "Rhythim Is Rhythim", "Strings of Life", 480),
    ])
    #expect(store.restore(src, result: after.match(src), in: after) == nil)
}

@Test func picksSurviveARelaunch() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("cratemate-test-picks/picks.json")
    try? FileManager.default.removeItem(at: url)
    #expect(PickStore.load(from: url).count == 0)

    var store = PickStore()
    store[SourceTrack(title: "Rain", artist: "Kerri Chandler")] = SavedPick(file: "/lib/rain.wav", best: nil)
    store[SourceTrack(title: "Not In Library", artist: "Nobody")] = SavedPick(file: nil, best: nil)
    try store.save(to: url)

    let loaded = PickStore.load(from: url)
    #expect(loaded.picks == store.picks)
}

/// End to end against the fake library from scripts/make-test-library.sh.
///
/// Run with CRATEMATE_TEST_LIBRARY=<dir passed to the script>.
@Test(.enabled(if: ProcessInfo.processInfo.environment["CRATEMATE_TEST_LIBRARY"] != nil))
func fakeLibrary() async throws {
    let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CRATEMATE_TEST_LIBRARY"]!)
    let playlist = try parseExport(dir.appendingPathComponent("sample export.txt"))
    let scan = await scanLibrary(dir.appendingPathComponent("lib"), rescan: true)
    #expect(scan.index.count == 11)

    let results = playlist.tracks.map { (src: $0, r: scan.index.match($0)) }
    for (src, r) in results {
        print(
            "\(r.status)\t\(src.artist) - \(src.title)\t-> \(r.best?.track.filename ?? "-")\t\(Int((r.best?.score ?? 0) * 100))%"
        )
    }
    let missing = results.filter { $0.r.status == .missing }
    #expect(missing.map(\.src.title) == ["Not In Library"])
    #expect(results.filter { $0.r.status != .missing }.count == 9)

    func file(_ title: String) -> String? { results.first { $0.src.title == title }?.r.best?.track.filename }
    #expect(file("Track A") == "Track A (Original Mix).mp3")
    #expect(file("Song B (Joe Remix)") == "Song B (Joe Remix).mp3")
    #expect(file("Rain") == "02 - Kerri Chandler - Rain.wav")
    #expect(file("Cafe del Mar") == "Cafe.flac")
    #expect(results.first { $0.src.title == "Song B" }?.r.dupes.count == 1)
}
