# CrateMate: brand rationale

Why the brand looks the way it does: what the app needed from it, the direction that was chosen, and the directions that were tried and rejected. The usage rules are in [README.md](README.md), and the original sketch is [sketches/riso-moire-sketch.svg](sketches/riso-moire-sketch.svg).

## The app

A small, free, open-source Mac app for DJs who find music in Apple Music and play from Rekordbox. It reads your Apple Music playlists, finds each song among the audio files in your DJ folder by artist, title, version and length, and writes a playlist file that Rekordbox imports. The imported tracks link to files already in your Rekordbox collection, so your cue points and beatgrids are kept.

What matters to the people who use it:

- **It finds your copy.** Not Apple's file, the one you prepared for your sets.
- **It picks the right cut.** It tells an Extended Mix from an Original Mix or a Radio Edit by track length.
- **It shows its work.** Every song is marked matched, worth a check, or not found, and you can fix any of them before exporting.
- **It never touches your files.** It only reads your DJ folder.

The audience is working and bedroom DJs: people who care about records and their own collection, and who are wary of anything that looks like a generic productivity tool.

**How it should feel: an organisation tool for a record collection.** It sorts and files; it doesn't make music. So nothing that reads as a music-making or music-streaming app: no waveforms, knobs, faders, equaliser bars or play buttons.

The app started out as am2rb (Apple Music to Rekordbox) and was renamed once the brand was settled.

## Name

**CrateMate**, one word. A crate is where a DJ keeps a set; the mate is the friend who packs it for you. The wordmark is set in lowercase, `cratemate`, with "mate" picked out in a second colour. In running text and the app's menu bar it's CrateMate.

## Chosen direction: Riso moiré in forest and yellow, with Geist

### The mark

Two sets of concentric rings, offset side by side and printed in two inks that overlap, like a two-colour risograph print. Where they cross, the inks mix and a moiré appears. One set is your Apple Music copy and the other is your DJ copy, finding each other. It reads as two things being lined up and matched, not as a record or a speaker.

On a 100 × 100 grid: five rings per set with radii 5, 10.5, 16, 21.5 and 27 and a stroke of 2.4. The left set is centred at (42, 50) and the right at (58, 50), and each set is clipped to a circle of radius 31. The second ink is nudged by (0.5, −0.4) to look slightly misregistered, and a light paper grain sits over everything. The overlap has to look like ink mixing (multiply), not like transparency.

The moiré turns to mush at small sizes, so the icon is redrawn with fewer, thicker rings at 64 px and below.

### Palette

| Name | Hex | Use |
|---|---|---|
| Paper | `#F2ECDC` | Icon ground, light backgrounds |
| Forest | `#2F5A49` | First ink; "mate" on light backgrounds |
| Yellow | `#F5D000` | Second ink; "mate" on dark backgrounds |
| Deep forest | `#1E3A2F` | Wordmark text on light; dark backgrounds |

Yellow is never text on paper; it doesn't have the contrast. On light grounds the wordmark is deep forest with "mate" in forest; on dark grounds it's paper with "mate" in yellow.

### Typeface

**Geist** (SemiBold, 600), lowercase, tracked tight (about −0.05 em at display size), under the open font licence. It's precise and plain, which keeps the brand on the "tool" side, while the icon's print texture provides the warmth. The wordmark is converted to outlines, with the join between "crate" and "mate" spaced by eye.

### Voice

Plain and warm, a little bit of record-shop talk, never cute. Sample status line: "23 of 25 in the crate. 2 still out there."

## Inside the app

The brand stays out of the app's interface. CrateMate is a native Mac app and should look like one: system controls, the system font and SF Symbols. The brand shows in the icon, the first-run screen and the docs.

There's no brand accent colour either. Forest is close to the green that means "matched", and yellow is close to the orange that means "worth a check", so tinting the app with them would blur the status colours. The app follows the user's system accent colour, like most Mac apps.

## What was tried and rejected

1. **"Matchcut", a violet record split diagonally into a flat half and a grooved half on near-black.** Too serious and "new-age techy", like a developer tool. The name didn't say what the app does either.
2. **Crate Mate as a cartoon:** a smiling red milk crate full of records on sunny yellow, in a chunky rounded font. The name worked, but the look was too childish.
3. **Other lighter names with cartoon looks:** "fetchlist", "tote" and "Porter". Same problem: too cute.
4. **Literal vinyl looks** (an obi-strip sleeve, a rubber-stamped white label, record labels and grooves). Too "music app", as if you make music with it. The obi one was also too Japanese-forward.
5. **Round, soft fonts** like Fraunces with its "soft" setting. Too bubbly.
6. **Other colourways for the moiré** (oxblood and mustard, navy and fluoro pink, teal and orange, black and red, blue and coral) and other typefaces (Gloock, Instrument Serif, Schibsted Grotesk, Archivo condensed capitals, DM Mono). Considered and passed over for forest and yellow with Geist.

The runner-up was **Spines**: a row of record spines with one spine pulled up as the match. Its "filed and sorted" feeling was the right spirit, but the moiré said "matching" more directly.

Overall direction: **an organisation tool with an analog, printed feel. Not childish, not techy, not a music-making app.**

## Constraints

- **Icon toolchain:** the project builds with the Xcode Command Line Tools only, so there's no asset catalog or Icon Composer. The icon is drawn in code by `scripts/make-icon.swift` (Core Graphics), and `scripts/make-icon.sh` turns it into `Resources/AppIcon.icns` with `iconutil`.
- **Trademarks:** the brand uses none of Apple's or rekordbox's logos, names or colours (such as Apple Music's red and pink).
- **No third-party assets** that need a paid licence or attribution.
