// The window: playlists in the sidebar, the match review in the detail, and export.

import CrateMateCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            Detail()
        }
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
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Write an .m3u8 for each selected playlist to \(model.outputPath)")
                .disabled(!model.canExport)
            }
        }
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
                .badge(p.tracks.count)
                .tag(p.id)
        }
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
        }
        .padding(20)
        .frame(width: 420)
    }
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
                    .disabled(model.scan != .ready)
                }
                Button("Change") { model.chooseLibrary() }
            }
            FolderRow(title: "Save to", path: model.outputPath, detail: nil) {
                Button("Change") { model.chooseOutput() }
            }
        }
        .buttonStyle(.borderless)
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
    }
}

struct PlaylistSection: View {
    let review: PlaylistReview
    let showAll: Bool

    var body: some View {
        let rows = showAll ? review.rows : review.rows.filter(\.needsAttention)
        Section {
            if rows.isEmpty {
                Label("Everything matched", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            ForEach(rows) { TrackRow(row: $0) }
        } header: {
            HStack(spacing: 14) {
                Text(review.playlist.name).font(.headline).foregroundStyle(.primary)
                Spacer()
                Group {
                    Label("\(review.count(.ok))", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        .help("Matched")
                    Label("\(review.count(.check))", systemImage: "questionmark.circle.fill").foregroundStyle(.orange)
                        .help("Probably right, worth a check")
                    Label("\(review.count(.missing))", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                        .help("Not found in your DJ folder")
                }
                .labelStyle(.titleAndIcon)
                Text("\(review.exportTracks.count) of \(review.rows.count) in export")
                    .foregroundStyle(.secondary)
            }
            .font(.callout.monospacedDigit())
            .padding(.vertical, 4)
        }
    }
}

struct TrackRow: View {
    @Bindable var row: RowReview

    var body: some View {
        HStack(spacing: 10) {
            statusIcon.frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.src.title).lineLimit(1)
                Text("\(row.src.artist.isEmpty ? "Unknown artist" : row.src.artist) · \(fmtDur(row.src.duration))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Picker("Match", selection: $row.pick) {
                    ForEach(row.options) { t in
                        Text(optionLabel(t)).tag(Optional(t.file))
                    }
                    if !row.options.isEmpty { Divider() }
                    Text("Skip").tag(String?.none)
                }
                .labelsHidden()
                .fillWidth()
                .frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 4) {
                    if row.pick == row.result.best?.track.file, !row.result.dupes.isEmpty {
                        Image(systemName: "doc.on.doc")
                            .help(
                                "Also in your library at:\n" + row.result.dupes.joined(separator: "\n")
                                    + "\nMake sure the one used is the copy Rekordbox has.")
                    }
                    Text(
                        row.picked?.filename
                            ?? (row.result.status == .missing && !row.touched ? "Not found" : "Skipped")
                    )
                    .lineLimit(1).truncationMode(.middle)
                    .help(row.picked?.file ?? "")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 380)

            Button {
                openSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Search your DJ folder")
            .popover(isPresented: $row.searching, arrowEdge: .trailing) {
                LibrarySearch(row: row)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder private var statusIcon: some View {
        if row.pick == nil {
            Image(systemName: row.result.status == .missing && !row.touched ? "xmark.circle.fill" : "minus.circle")
                .foregroundStyle(row.result.status == .missing && !row.touched ? .red : .secondary)
        } else if row.touched {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
        } else {
            switch row.result.status {
            case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .check: Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
            case .missing: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
        }
    }

    private func optionLabel(_ t: LibraryTrack) -> String {
        var s = "\(t.artist.isEmpty ? "?" : t.artist) – \(t.title) · \(fmtDur(t.duration))"
        if let score = row.scores[t.file] { s += " · \(Int((score * 100).rounded()))%" }
        return s
    }

    /// Prefill with artist and title minus "(… Mix)" noise, so the search is broad enough.
    private func openSearch() {
        if row.searchQuery.isEmpty {
            let title = row.src.title.components(separatedBy: CharacterSet(charactersIn: "([")).first ?? row.src.title
            row.searchQuery = "\(row.src.artist) \(title)".trimmingCharacters(in: .whitespaces)
        }
        row.searching = true
    }
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
                        row.choose(t)
                        row.searching = false
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

extension View {
    /// Stretches a menu picker to the width it's offered, so every row's picker is the same size.
    /// Before macOS 26 a menu picker always sizes to its label.
    @ViewBuilder fileprivate func fillWidth() -> some View {
        if #available(macOS 26, *) { buttonSizing(.flexible) } else { self }
    }
}
