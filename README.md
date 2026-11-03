# PixNab 0.22.0 — Precision Color Picker & Color Studio for macOS

PixNab is a lightweight native macOS menu-bar color picker, built with
AppKit, SwiftUI, ScreenCaptureKit and a shared Swift color-conversion module.

## Startup and windows

- On launch PixNab creates **only its status-bar item**. It does not open a window.
- **Preferences…** opens a dedicated AppKit window hosting the SwiftUI `PreferencesView`.
- **Colors & Formats…** opens its own window only when requested.
- **Color Studio…** opens an independent native window with four tabs. No automatic window chaining.
- There is no SwiftUI `Settings { EmptyView() }` scene.

## What is included

- **One production sampling engine:** CPU per-pixel on Display P3 SDR BGRA8 frames with sRGB conversion for legacy formats.
- Circular magnifier with keyboard navigation, zoom, precision mode and multi-pick.
- Color format and value displayed **inside the circle** in a subtle overlay;
  no external caption prevents the lens from reaching screen edges.
- Lens placement constrained to the active display, including multi-monitor setups.
- Configurable global shortcuts, recent colors, favorites, color editor popover.
- Dedicated native **Color Wheel** window, reached directly from the menu bar
  or **Colors & Formats**. Inner disk controls hue/saturation, outer band controls
  HSL lightness with the sheet background visible between them. Five harmony
  types are supported. Click a swatch to use it; right-click to copy or save it.
  Copy, save, or export the entire palette as ASE/ACO. The compact RGBA editor
  instead provides color-tinted R/G/B and checkerboard alpha sliders without a
  second, performance-heavy harmony wheel. P3 capture remains unchanged.
- **Color Studio:** 300 offline web-design palettes in nine sectors: 30 featured themes
  (26 original and four explicitly attributed open-source selections) plus 270 labeled
  original PixNab design recipes, organized by style and intensity. Browse by sector,
  search/filter Featured vs Recipes, preview a realistic landing page, check WCAG 2.x
  text/CTA contrast and export ASE/ACO or semantic CSS/JSON/SwiftUI tokens.
  **Active PixNab color** is editable at the top via HEX/CSS, the native macOS
  color picker, recent captures, selected palette, or screen capture. Clicking
  **Use** activates a shade; **Compare** opens a fully independent editable A/B
  comparison. An explicit action sends Primary directly to the scale generator.
- **My Palettes:** save/rename/duplicate/reorder/edit/delete palettes independent of color history;
  preserve capture P3 provenance in saved swatches; make a non-destructive JSON backup/import.
- **Color comparison:** CIEDE2000 (Lab D50), plus explicitly separate OKLab distance;
  uses captured P3 components before clipping when available.
- **Color scales:** eleven OKLCH shades (50–950) with exact original at 500, sRGB
  chroma reduction, and CSS/JSON/SwiftUI token export.
- Color conversions, Adobe swatch exports, local preferences and pick sessions.
- 15/30 FPS capture rate preference; idle picker does not capture the screen.
- Shared, tested color parser and formatter, reusable SwiftUI components.
- CSS Lab/LCH, OKLab/OKLCH, HWB and Display P3 input/output. Sampled P3 values are retained for P3 export; other formats use sRGB.
- History and multi-pick sessions retain Display P3 SDR samples and the capture-time display profile label (not source-app ICC).

## Build and open on macOS 14+ (Apple Swift toolchain and macOS SDK)

```bash
chmod +x run.sh
./run.sh --check  # lint + Swift Testing tests + native build
./run.sh          # build, sign locally and open PixNab.app
```

Additional commands: `./run.sh --test`, `./run.sh --lint`, `./run.sh --clean`,
`./run.sh --build`, `./run.sh --xcode`, `./run.sh --cli formats`,
`./run.sh --cli convert '#ff8800' cssOKLCH`.

The benchmark, animated test workload, engine comparisons and their command-line
flags have been removed from this production package.

No Node, npm, CocoaPods, XcodeGen, backend or network access required.
PixNab's portable unit tests use **Swift Testing** (`import Testing`) rather
than XCTest. `./run.sh --test` runs them in debug mode using `--disable-xctest`, and
`./run.sh --check` requires them to
pass before compiling the macOS application. The tests are never silently skipped.
The project uses existing Swift Package Manager targets and commands, without
requiring `xctrace` or adding a dependency on Xcode.app to its source configuration.
On a Mac, the selected Swift toolchain must include the `Testing` module and a
compatible macOS SDK. Native AppKit and ScreenCaptureKit validation is still
required for production readiness.
See `docs/HOTFIX_V15_1.md` for this startup fix and its native acceptance steps.
The original v0.15 delivery notes remain in `docs/DELIVERY_V15.md`.

See `docs/HOTFIX_V15_2.md` for the geometry regression fix and native QA checklist.

## Languages and color boundaries

- English fallback plus the French UI catalog (`fr.lproj`) are packaged
  in `dist/PixNab.app/Contents/Resources` by the existing `run.sh` build.
  Select **System / English / French** in Preferences → Appearance → Language.
  The menu and preferences update without requiring a restart.
- P3 capture is standard dynamic range, 8 bits/channel. The actual ICC profile
  of the source application and HDR pixel values are **not** recoverable from
  the composited capture. Physical color-accuracy tests remain required.

## Native acceptance for v0.19.3

After extracting the source archive on your Mac, run `./run.sh --check`
(Swift Testing + production build), then `./run.sh` to launch the menu app.
Confirm the wheel is opened from **Colors & Formats**, its gap follows the
native sheet background (not white), and drag controls still work. Select each
of the five harmony modes; click a swatch, right-click to copy/save one color,
and try **Copy Palette**, **Save Palette**, and **Export Palette** (ASE/ACO).
Check copied values, saved history order, and actual ASE/ACO outputs in the
relevant receiving apps. In **Color Editor**, verify the tinted RGBA sliders,
alpha checkerboard, keyboard and VoiceOver adjustments, and absence of the
old Harmony disclosure section. The unused format navigation arrows must be
absent from the Colors & Formats header. Existing magnifier, pick sessions,
Display P3 history and language preferences must remain functional.

## v0.20.0 — Requirements finalization and native acceptance

- The 33 text formats are covered by stable-ID and output tests, and the documented public ColorSnapper format families are present. Exact **licensed-reference variant parity** cannot be proven from the public list and remains an explicit gate.
- The menu-bar history action now preserves captured Display P3 screen-pixel values and display-profile labels rather than discarding them. This is **not** original source-document ICC attribution.
- Gamut checks inspect P3 values before sRGB clipping. The active SDR capture policy is explicit (including `.SDR` on macOS 15+); HDR luminance sampling is intentionally unsupported.
- Preferences retain their existing tabs and settings, with improved multiline labels, shortcut recorder localization, accessibility text and translated dynamic statuses; System/English/French remains user-selectable.
- **162 portable Swift Testing tests passed in debug and release on Linux**. The native macOS UI, color capture, accessibility and format-reference comparison have not been executed here.

For the complete five-requirement checklist and native QA steps, read `docs/RELEASE_GATE_V20.md`.

## Release status

**Source release candidate, not a notarized production app.** Run `./run.sh --check` on your Mac to execute Swift Testing and build PixNab natively, then test the five requirement areas described in `docs/RELEASE_GATE_V20.md`. The project tree and run.sh commands are unchanged. No claim is made of originating-app ICC-profile recovery, actual HDR measurements, or one-to-one ColorSnapper variant parity.

See `docs/COLOR_STUDIO_V21.md` for workflows, official palette sources, numerical
assumptions, and a macOS hands-on acceptance matrix. Portable test suites cover
all new mathematical/data logic; native SwiftUI has to be built and exercised on a Mac.
