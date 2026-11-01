# Roadmap

What's planned for CrateMate, roughly in order. There are no dates: it's a spare-time project, and things move when they're ready. Shipped work moves to [CHANGELOG.md](CHANGELOG.md).

Have an idea or need something on this list sooner? [Open a feature request](https://github.com/bflip12/cratemate/issues/new?template=feature_request.yml), or 👍 an existing one. Issues with the [`idea`](https://github.com/bflip12/cratemate/labels/idea) label are suggestions that haven't been planned yet.

## Now

- **First release, 0.1.0.** A downloadable DMG for Apple silicon and Intel Macs, published on GitHub Releases.
- **Testing against real DJ folders.** The matcher is tuned on a generated test library. Checking it against large real collections and real rekordbox imports, and turning every mismatch into a test.
- **Screenshots of the app** on the website and in the README.

## Next

- **Notarized builds,** so the app opens with a double-click and without the Open Anyway step, and keeps its Apple Music permission across updates.
- **Remember picks.** Keep the choices you made in the review list, so exporting the same playlist again doesn't mean fixing the same rows.
- **Export the not-found list,** as a text or CSV file, to use as a shopping list.
- **Install with Homebrew** (`brew install --cask cratemate`).

## Later

- **Re-export changed playlists.** Show which playlists changed in Apple Music since their last export, and update them in one go.
- **More DJ apps.** Test and document importing into Serato, Traktor and Engine DJ, and add any format tweaks they need.
- **A nicer DMG window,** with a background and the Applications shortcut laid out.

## Not planned

These go against [the project's design decisions](docs/adr/README.md):

- Moving, renaming or retagging files in your DJ folder ([ADR 0003](docs/adr/0003-read-only-dj-folder.md)).
- Downloading music, looking up metadata online, or any other network access ([ADR 0004](docs/adr/0004-offline-no-dependencies.md)).
