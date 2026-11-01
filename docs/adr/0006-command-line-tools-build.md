# 0006. Build with SwiftPM and the Command Line Tools only

**Status:** Accepted

## Context

Requiring full Xcode to build a small app shuts out contributors who only have the Command Line Tools, and an `.xcodeproj` is a large, merge-unfriendly file. A plain Swift package builds anywhere with `swift build`, but SwiftPM doesn't produce an `.app` bundle.

Two problems came with this choice:

- In the macOS 27 SDK, SwiftUI's `@State` is a macro whose compiler plugin ships only with Xcode, so code using it doesn't build with the Command Line Tools.
- SwiftPM records the deployment target (14.0) as the binary's SDK version, so macOS runs the app in compatibility mode with old window chrome.

## Decision

- Keep the project a plain Swift package with no Xcode project.
- `scripts/build-app.sh` assembles `CrateMate.app`, restamps the SDK version with `vtool`, adds the icon and ad-hoc signs it.
- Don't use `@State`. Keep UI state on the `@Observable` models.
- Build universal (arm64 and x86_64) with `--arch` flags, which works with the Command Line Tools.
- Draw the app icon in code (`scripts/make-icon.swift`) instead of using an asset catalog.

## Consequences

- Anyone with `xcode-select --install` can build, test and run the app.
- CI and releases use the same scripts as local builds.
- UI state lives on the models, which also makes it easier to test.
- No SwiftUI previews, asset catalogs or Icon Composer. Changes to the icon go through the script.
- The `vtool` step must stay, and `scripts/test.sh` passes the Swift Testing plugin path explicitly because incremental builds can lose it.
