# 0004. No network access and no third-party dependencies

**Status:** Accepted

## Context

CrateMate reads a user's whole music library and the contents of their DJ folder. That's personal data, and DJs are rightly wary of tools that might send it anywhere. The app's job, matching two local lists, doesn't need a server.

Every third-party package also adds code to audit, updates to follow and a supply-chain risk, for a small app maintained in spare time.

## Decision

The app makes no network requests and collects no analytics. It uses only Apple's frameworks: SwiftUI, AppKit, `iTunesLibrary`, AVFoundation and AudioToolbox. Adding a dependency needs an issue and agreement first.

## Consequences

- The privacy promise is simple and checkable: everything stays on the Mac.
- There's no crash reporting or usage data, so bugs are found through issues people file.
- Features that need online data, like looking up metadata from a web service, are out of scope.
- Matching, text normalisation and M3U writing are written in-house and covered by tests.
