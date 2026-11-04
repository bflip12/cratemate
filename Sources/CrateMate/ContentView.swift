// The window: playlists in the sidebar, the match review in the detail, and export.

import CrateMateCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            Detail()
        }
        .onAppear { model.undoManager = undoManager }
        .onChange(of: undoManager) { model.undoManager = undoManager }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Show", selection: $model.showAll) {
                    Text("Needs attention").tag(false)
                    Text("All tracks").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .disabled(model.selection.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.export()
                } label: {
                    Label(
                        model.exportable.count > 1 ? "Export \(model.exportable.count) Playlists" : "Export",
                        systemImage: "square.and.arrow.up")
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
                .help("Save an .m3u8 for each selected playlist in \(model.outputPath)")
                .disabled(!model.canExport)
            }
        }
        .navigationTitle(windowTitle)
        .navigationSubtitle(windowSubtitle)
        .alert(
            exportedTitle,
            isPresented: Binding(get: { !model.exported.isEmpty }, set: { if !$0 { model.exported = [] } })
        ) {
            Button("Show in Finder") {
                model.revealExported()
                model.exported = []
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text(
                "Saved to \((model.outputPath as NSString).abbreviatingWithTildeInPath). In Rekordbox, choose File › Import › Import Playlist, or drag the file onto Playlists."
                    + (model.leftOut.isEmpty
                        ? ""
                        : "\n\nLeft out \(model.leftOut.joined(separator: ", ")), with no songs to export.")
            )
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var windowTitle: String {
        switch model.selectedPlaylists.count {
        case 0: return "CrateMate"
        case 1: return model.selectedPlaylists[0].name
        case let n: return "\(n) Playlists"
        }
    }

    private var windowSubtitle: String {
        let reviews = model.selectedPlaylists.compactMap { model.reviews[$0.id] }
        guard !reviews.isEmpty else { return "" }
        let songs = reviews.reduce(0) { $0 + $1.rows.count }
        let exported = reviews.reduce(0) { $0 + $1.exportTracks.count }
        return "\(exported) of \(songs) songs in export"
    }

    private var exportedTitle: String {
        model.exported.count == 1
            ? "Exported \(model.exported[0].lastPathComponent)" : "Exported \(model.exported.count) playlists"
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            if model.playlistsLoading && model.playlists.isEmpty {
                Label("Loading Apple Music…", systemImage: "hourglass").foregroundStyle(.secondary)
            }
            if let err = model.playlistsError {
                Text(err).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Playlist Export…") { model.openExportFile() }
            }
            if !groups.isEmpty {
                // Folders are outline rows, like in Apple Music, not collapsible sections: a section
                // header's hover chevron jumps around when it's toggled.
                Section("Playlists") {
                    ForEach(groups, id: \.folder) { group in
                        if let folder = group.folder {
                            DisclosureGroup(isExpanded: expanded(folder)) {
                                rows(group.playlists)
                            } label: {
                                Label(folder, systemImage: "folder")
                                    .contextMenu {
                                        Button("Select All Playlists in Folder") {
                                            model.selection = Set(group.playlists.map(\.id))
                                        }
                                    }
                            }
                        } else {
                            rows(group.playlists)
                        }
                    }
                }
            }
        }
        .searchable(text: $model.playlistFilter, placement: .sidebar, prompt: "Filter playlists")
        .safeAreaInset(edge: .bottom, spacing: 0) { SidebarFooter() }
    }

    private func rows(_ playlists: [Playlist]) -> some View {
        ForEach(playlists) { p in
            Label(p.name, systemImage: p.isSmart ? "gearshape" : "music.note.list")
                .badge(badge(p))
                .help(found(p))
                .tag(p.id)
        }
    }

    /// Songs in the export out of all songs, once the playlist is matched; until then, the song count.
    private func badge(_ p: Playlist) -> Text {
        guard let r = model.reviews[p.id] else { return Text("\(p.tracks.count)") }
        return Text("\(r.exportTracks.count)/\(p.tracks.count)")
    }

    private func found(_ p: Playlist) -> String {
        guard let r = model.reviews[p.id] else { return "" }
        return "\(r.exportTracks.count) of \(p.tracks.count) songs in export"
    }

    /// Folders open while filtering, so every match is visible.
    private func expanded(_ folder: String) -> Binding<Bool> {
        Binding(
            get: { !model.playlistFilter.isEmpty || (model.folderExpanded[folder] ?? model.expandFolders) },
            // Without an explicit animation the rows appear at once; only collapsing animates.
            set: { open in withAnimation { model.folderExpanded[folder] = open } })
    }

    /// Playlists grouped by folder in Apple Music's order; `folder` is nil for those not in one.
    private var groups: [(folder: String?, playlists: [Playlist])] {
        let filter = model.playlistFilter
        let shown =
            filter.isEmpty
            ? model.playlists
            : model.playlists.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        var order: [String?] = []
        var byFolder: [String?: [Playlist]] = [:]
        for p in shown {
            if byFolder[p.folder] == nil { order.append(p.folder) }
            byFolder[p.folder, default: []].append(p)
        }
        return order.map { ($0, byFolder[$0]!) }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Picker("Playlist folders:", selection: $model.expandFolders) {
                Text("Collapsed").tag(false)
                Text("Expanded").tag(true)
            }
            .pickerStyle(.radioGroup)
            Text("How Apple Music folders appear in the sidebar when CrateMate opens.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Picks:") {
                Button("Forget All Picks…") { model.confirmingForgetPicks = true }
                    .disabled(model.picks.count == 0)
            }
            .padding(.top, 12)
            Text(
                "CrateMate remembers the files you choose and the songs you skip, in every playlist."
                    + (model.picks.count == 0 ? "" : " \(songs(model.picks.count)) so far.")
            )
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 420)
        .confirmationDialog(
            "Forget your picks for \(songs(model.picks.count))?", isPresented: $model.confirmingForgetPicks
        ) {
            Button("Forget Picks", role: .destructive) { model.forgetPicks() }
        } message: {
            Text("Every song goes back to CrateMate's own match. You can't undo this.")
        }
    }

    private func songs(_ n: Int) -> String { n == 1 ? "1 song" : "\(n) songs" }
}

struct SidebarFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FolderRow(title: "DJ folder", path: model.libraryPath, detail: libraryDetail) {
                if model.libraryPath != nil {
                    Button {
                        model.scanLibrary(rescan: true)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Re-read the tags of every file")
                    .accessibilityLabel("Rescan DJ Folder")
                    .disabled(model.scan != .ready)
                }
                Button("Change") { model.chooseLibrary() }
            }
            FolderRow(title: "Save to", path: model.outputPath, detail: nil) {
                Button("Change") { model.chooseOutput() }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var libraryDetail: String? {
        switch model.scan {
        case .idle: return nil
        case .scanning(let done, let total): return total == 0 ? "Scanning…" : "Scanning… \(done) of \(total)"
        case .ready: return "\(model.index?.count ?? 0) tracks"
        }
    }
}

struct FolderRow<Actions: View>: View {
    let title: String
    let path: String?
    let detail: String?
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(path.map { ($0 as NSString).lastPathComponent } ?? "Not set")
                    .lineLimit(1).truncationMode(.middle)
                    .help(path ?? "")
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
            }
            Spacer(minLength: 4)
            actions
        }
    }
}

// MARK: - Detail

struct Detail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.libraryPath == nil {
            ContentUnavailableView {
                Label {
                    Text("Choose your DJ folder")
                } icon: {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
                }
            } description: {
                Text(
                    "CrateMate matches your Apple Music playlists against the files Rekordbox already uses. It only reads them; nothing is moved or retagged."
                )
            } actions: {
                Button("Choose Folder…") { model.chooseLibrary() }.buttonStyle(.borderedProminent)
            }
        } else if case .scanning(let done, let total) = model.scan {
            VStack(spacing: 12) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .frame(width: 280)
                Text(total == 0 ? "Finding audio files…" : "Reading tags… \(done) of \(total)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        } else if model.selection.isEmpty {
            ContentUnavailableView(
                "Pick a playlist", systemImage: "music.note.list",
                description: Text("Select one or more playlists on the left. Use ⌘-click to select several."))
        } else {
            ReviewList()
        }
    }
}

struct ReviewList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            ForEach(model.selectedPlaylists) { p in
                if let review = model.reviews[p.id] {
                    PlaylistSection(review: review, showAll: model.showAll)
                } else {
                    Section(p.name) { ProgressView().controlSize(.small) }
                }
            }
        }
        .listStyle(.inset)
        // A fresh table per selection: reused rows keep the old playlist's row heights and draw squashed.
        .id(model.selectedPlaylists.map(\.id))
    }
}

struct PlaylistSection: View {
    @Environment(AppModel.self) private var model
    let review: PlaylistReview
    let showAll: Bool

    var body: some View {
        let rows = showAll ? review.rows : review.rows.filter(\.needsAttention)
        let repeated = review.repeatedRows
        Section {
            if review.noneFound && !showAll {
                NoneFound(review: review)
            } else if rows.isEmpty {
                Label(
                    review.rows.allSatisfy { $0.result.status == .ok } ? "Everything matched" : "Nothing left to check",
                    systemImage: "checkmark.circle"
                )
                .foregroundStyle(.secondary)
            }
            if showAll || !review.noneFound {
                ForEach(rows) { TrackRow(row: $0, repeated: repeated.contains($0.id)) }
            }
        } header: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 14) {
                    Text(review.playlist.name).font(.headline).foregroundStyle(.primary)
                    Spacer()
                    Group {
                        Label("\(review.count(.matched))", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            .help("Matched")
                        Label("\(review.count(.check))", systemImage: "questionmark.circle.fill").foregroundStyle(
                            .orange
                        )
                        .help("Probably right, worth a check")
                        Label("\(review.count(.missing))", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                            .help("Not found in your DJ folder")
                        if review.count(.skipped) > 0 {
                            Label("\(review.count(.skipped))", systemImage: "minus.circle").foregroundStyle(.secondary)
                                .help("Skipped")
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    Text("\(review.exportTracks.count) of \(review.rows.count) in export")
                        .foregroundStyle(.secondary)
                    if review.leftToCheck > 0 && !review.noneFound {
                        Button("Accept All") {
                            withAnimation { model.acceptAll(in: review) }
                        }
                        .controlSize(.small)
                        .help("Keep the current choice for every song left to check")
                    }
                }
                .font(.callout.monospacedDigit())
                .padding(.vertical, 4)
                if !rows.isEmpty && (showAll || !review.noneFound) {
                    ColumnHeadings()
                }
            }
        }
    }
}

/// "Apple Music" and "DJ folder" over the two halves of the rows below.
struct ColumnHeadings: View {
    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 18, height: 1)
            Text("Apple Music").frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 14, height: 1)
            Text("DJ folder").frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: TrackRow.actionsWidth, height: 1)
        }
        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        .padding(.bottom, 2)
    }
}

/// Shown instead of a wall of red rows when nothing in the playlist is in the DJ folder.
struct NoneFound: View {
    @Environment(AppModel.self) private var model
    let review: PlaylistReview

    var body: some View {
        let n = review.rows.count
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(n == 1 ? "This song isn't in your DJ folder" : "None of these \(n) songs are in your DJ folder")
            } icon: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
            .font(.headline)
            Text(
                "If you expected some, check that the DJ folder at the bottom of the sidebar is the one your Rekordbox collection uses."
            )
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(n == 1 ? "Copy Song" : "Copy Song List") { model.copyNotFound(in: review) }
                    .help("Copy the artist and title of each song, one per line")
                Button("Show Songs") { model.showAll = true }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

/// One song: what Apple Music has on the left, and the DJ folder file it's matched to on the right.
struct TrackRow: View {
    /// Width of the icons at the end of a row, which the column headings leave room for.
    static let actionsWidth: CGFloat = 92

    @Environment(AppModel.self) private var model
    @Bindable var row: RowReview
    /// The file is already used by an earlier row in this playlist.
    var repeated = false

    var body: some View {
        let diffs = row.needsAttention ? row.picked.map { differences(row.src, $0) } ?? [] : []
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                statusIcon.frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.src.title).lineLimit(1)
                    Text(
                        marked(
                            row.src.artist.isEmpty ? "Unknown artist" : row.src.artist, diffs.contains(.noSongArtist))
                            + AttributedString(" · \(fmtDur(row.src.duration))")
                    )
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary).frame(width: 14)
                fileCell(diffs).frame(minWidth: 200, maxWidth: .infinity)
                actions.frame(width: Self.actionsWidth, alignment: .trailing)
            }
            if let reason = row.reason {
                Text(reason).font(.caption).foregroundStyle(Color.warning).lineLimit(2)
                    .padding(.leading, 28)
                    .help(reason)
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Change File…") { row.panel = .choose }
            Button("Search DJ Folder…") { row.openSearch() }
            if let file = row.picked?.file {
                Divider()
                Button("Show in Finder") { model.reveal([file]) }
                if !copies.isEmpty {
                    Button("Show Every Copy in Finder") { model.reveal([file] + copies) }
                }
            }
        }
    }

    /// The matched file, as a button that opens the other choices.
    private func fileCell(_ diffs: [Difference]) -> some View {
        let picked = row.picked
        return Button {
            row.panel = .choose
        } label: {
            HStack(spacing: 6) {
                if let t = picked {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(fileTitle(t, diffs)).lineLimit(1)
                            if let score = row.scores[t.file] {
                                Text(percent(score))
                                    .font(.caption2.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        Text(
                            marked(
                                t.artist.isEmpty ? "Unknown artist" : t.artist,
                                diffs.contains(.artist) || diffs.contains(.noFileArtist))
                                + AttributedString(" · ")
                                + marked(
                                    fmtDur(t.duration), diffs.contains { if case .length = $0 { true } else { false } })
                                + AttributedString(" · \(t.filename)")
                        )
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                } else {
                    Text(row.state == .missing ? "Not in your DJ folder" : "Skipped").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(
                picked == nil ? AnyShapeStyle(.quinary) : AnyShapeStyle(.background),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(
                    Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: 1, dash: picked == nil ? [3, 2] : []))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(picked?.file ?? "Choose a file")
        .accessibilityLabel(picked.map { "Matched to \($0.label), \($0.filename)" } ?? "No file")
        .accessibilityHint("Choose a different file")
        .popover(isPresented: panelShown, arrowEdge: .bottom) {
            if row.panel == .search { LibrarySearch(row: row) } else { FileChoices(row: row) }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if repeated {
                Image(systemName: "repeat").foregroundStyle(.secondary)
                    .help("An earlier song in this playlist uses the same file, so it'll be in the export twice.")
            }
            if !copies.isEmpty {
                Button {
                    model.reveal([row.pick!] + copies)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help(
                    "Also in your DJ folder at:\n" + copies.joined(separator: "\n")
                        + "\nClick to show every copy in Finder. Check which one Rekordbox uses before you delete any."
                )
                .accessibilityLabel("Show every copy in Finder")
            }
            // Hidden rather than removed once decided, so the columns stay lined up.
            Button {
                withAnimation { model.decide(row, row.picked) }
            } label: {
                Image(systemName: row.pick == nil ? "minus.circle" : "checkmark")
            }
            .help(row.pick == nil ? "Leave it out of the export" : "Keep this match")
            .accessibilityLabel(row.pick == nil ? "Skip" : "Keep match")
            .opacity(row.needsAttention ? 1 : 0)
            .disabled(!row.needsAttention)
            .accessibilityHidden(!row.needsAttention)

            Button {
                row.openSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Search your DJ folder")
        }
        .buttonStyle(.borderless)
    }

    private var panelShown: Binding<Bool> {
        Binding(
            get: { row.panel != nil },
            set: { shown in
                if !shown {
                    row.panel = nil
                    row.hovered = nil
                }
            })
    }

    /// Other copies of the picked file's recording, when the pick is the matcher's own.
    private var copies: [String] {
        row.pick != nil && row.pick == row.result.best?.track.file ? row.result.dupes : []
    }

    /// The file's title, with the version words or the whole title marked if they differ from the song's.
    private func fileTitle(_ t: LibraryTrack, _ diffs: [Difference]) -> AttributedString {
        if diffs.contains(.title) { return marked(t.title, true) }
        guard diffs.contains(.version), let start = versionStart(t.title) else { return AttributedString(t.title) }
        return AttributedString(String(t.title[..<start])) + marked(String(t.title[start...]), true)
    }

    @ViewBuilder private var statusIcon: some View {
        switch row.state {
        case .matched:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(
                row.decided ? AnyShapeStyle(.tint) : AnyShapeStyle(.green))
        case .check: Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
        case .missing: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .skipped: Image(systemName: "minus.circle").foregroundStyle(.secondary)
        }
    }
}

/// Where a title's remix or edit words start: at "(", "[" or " - ".
private func versionStart(_ title: String) -> String.Index? {
    [title.firstIndex(of: "("), title.firstIndex(of: "["), title.range(of: " - ")?.lowerBound].compactMap { $0 }.min()
}

/// `text`, with an orange highlight if `on`, for a part of a match that differs from the song.
private func marked(_ text: String, _ on: Bool) -> AttributedString {
    var a = AttributedString(text)
    if on {
        a.backgroundColor = Color.orange.opacity(0.22)
        a.foregroundColor = .primary
    }
    return a
}

/// The popover behind a row's file cell: every candidate in aligned columns, then search and skip.
struct FileChoices: View {
    @Environment(AppModel.self) private var model
    let row: RowReview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !row.options.isEmpty {
                HStack(spacing: 8) {
                    Color.clear.frame(width: 14, height: 1)
                    Text("File").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Length").frame(width: 84, alignment: .trailing)
                    Text("Score").frame(width: 40, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 4)
                ForEach(row.options) { t in
                    item(t.file, label: "Use \(t.label)") {
                        choose(t)
                    } content: { lit in
                        fileItem(t, lit)
                    }
                }
                Divider().padding(.horizontal, 10).padding(.vertical, 5)
            }
            command("Search DJ Folder…") { row.openSearch() }
            command("Skip This Song") { choose(nil) }
        }
        .padding(6)
        .frame(width: 480)
    }

    private func fileItem(_ t: LibraryTrack, _ lit: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").font(.caption.weight(.bold))
                .opacity(row.pick == t.file ? 1 : 0).frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(t.artist.isEmpty ? "Unknown artist" : t.artist) – \(t.title)").lineLimit(1)
                Text(t.filename).font(.caption).opacity(lit ? 0.85 : 1)
                    .foregroundStyle(lit ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(fmtDur(t.duration))
                if let diff = lengthDiff(t) {
                    Text(diff).font(.caption).foregroundStyle(
                        lit ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.warning))
                }
            }
            .frame(width: 84, alignment: .trailing)
            Text(row.scores[t.file].map(percent) ?? "").frame(width: 40, alignment: .trailing)
        }
        .monospacedDigit()
    }

    private func command(_ title: String, action: @escaping () -> Void) -> some View {
        item(title, label: title, action: action) { _ in
            Text(title).padding(.leading, 22).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A menu-like item: highlighted under the pointer, closing the popover when chosen.
    private func item(
        _ key: String, label: String, action: @escaping () -> Void, @ViewBuilder content: (Bool) -> some View
    ) -> some View {
        let lit = row.hovered == key
        return Button(action: action) {
            content(lit)
                .foregroundStyle(lit ? Color.white : Color.primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(lit ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .onHover { inside in
            if inside {
                row.hovered = key
            } else if row.hovered == key {
                row.hovered = nil
            }
        }
    }

    private func choose(_ t: LibraryTrack?) {
        row.panel = nil
        row.hovered = nil
        withAnimation { model.decide(row, t) }
    }

    /// "+0:44" or "−0:17" against the song's length, past the 3 s that counts as the same.
    private func lengthDiff(_ t: LibraryTrack) -> String? {
        guard let s = row.src.duration, let f = t.duration, s > 0, f > 0, abs(f - s) > 3 else { return nil }
        return "\(f > s ? "+" : "−")\(fmtDur(abs(f - s)))"
    }
}

extension Color {
    /// Orange text that stays readable on a light background.
    fileprivate static let warning = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? .systemOrange : NSColor(srgbRed: 0.70, green: 0.31, blue: 0, alpha: 1)
        })
}

struct LibrarySearch: View {
    @Environment(AppModel.self) private var model
    @Bindable var row: RowReview

    var body: some View {
        let query = row.searchQuery
        let results = model.index?.search(query) ?? []
        VStack(alignment: .leading, spacing: 8) {
            TextField("Artist, title or filename", text: $row.searchQuery)
                .textFieldStyle(.roundedBorder)
            if results.isEmpty {
                Text(query.isEmpty ? "Type to search your DJ folder." : "Nothing found.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 60)
            } else {
                List(results) { t in
                    Button {
                        row.panel = nil
                        withAnimation { model.decide(row, t) }
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(t.artist.isEmpty ? "?" : t.artist) – \(t.title)").lineLimit(1)
                            Text("\(fmtDur(t.duration)) · \(t.filename)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(height: 280)
            }
        }
        .padding(12)
        .frame(width: 420)
    }
}
