# Sumi

A bedtime commitment game for iOS: put your phone down, go to sleep, see what hatched when you wake up.

## What's here

| Path | What it is |
|---|---|
| `PRD-v2.md` | Current product spec ("Hatch"). Source of truth. |
| `SumiCore/` | Pure Swift package with the game rules: night window, night outcomes, counters, archetypes, hatching and collection. No UI, no Apple frameworks beyond Foundation. |
| `sketches/` | Wireframe sketches of the main screens. |
| `screenshot/` | Reference screenshots from other apps (internal research only). |

## Run the tests

On a Mac with Xcode 16 or later:

```bash
cd sumi/SumiCore && swift test
```

CI runs the same command on every push that touches `sumi/SumiCore` (`.github/workflows/sumi-core.yml`).

## Build status

- Slice 0 (SumiCore engine + tests + CI): in progress.
- Slice 0.5 (Screen Time spike on a real iPhone): next. See PRD Section 6.3 for the questions it must answer.
