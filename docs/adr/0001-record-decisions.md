# 0001. Record architecture decisions

**Status:** Accepted

## Context

CrateMate has a handful of rules that look arbitrary without their history: no `@State`, no network, never write to the DJ folder, a `vtool` step in the build. They're explained across the README, CONTRIBUTING.md, CODE_STYLE.md and commit messages, which makes them easy to miss and easy to undo by accident.

## Decision

Record each significant decision as a short architecture decision record (ADR) in `docs/adr/`, numbered in order, with its context, the decision and its consequences. The first ones write down decisions that were already made.

## Consequences

- New contributors can find out why something is the way it is before changing it.
- Reversing a decision means writing a new ADR, which makes the change deliberate.
- It's one more file to write for a big change. Small changes don't need one.
