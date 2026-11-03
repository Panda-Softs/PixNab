## 0.22.0 — Web design catalogue (300 palettes) and Color Studio interaction redesign (source release candidate)

- Expand bundled **offline** catalog from 30 to **300 distinct five-swatch palettes**. Preserve the original 30 featured selections (26 PixNab originals, four attributed external token selections), add 270 clearly labeled **original generated design recipes** (nine web-design sectors × ten named stories × three treatments). These are not copied or labeled as Adobe/Color Hunt works; Adobe Color remains an optional external inspiration link. The generated recipes use explicit semantic roles and are validated for WCAG 2.x normal-text contrast between Background/Text and Surface/Text.
- Introduce one comprehensible color-editing pattern everywhere in the Studio: editable HEX/CSS input with Apply; native macOS ColorPicker; sources from active PixNab color, recent capture history and the palette currently selected in Discover. The **global active color** is editable and visibly identified in the Studio header; direct screen picking remains available. Local A/B and scale inputs never silently overwrite the active color.
- Make palette swatch actions explicitly visible (Use / Compare); the latter opens Compare with the clicked swatch as B and the active color as A. Add direct "Create a scale from Primary" navigation. Comparison supports fully independent A/B editing, A↔B swap, history / palette picker and explicit Set A/B active; scales expose their base-color editor without the vague "Use Active Color" wording.
- Add Featured / Design recipes filters and count, retain use-case category search, annotate source provenance clearly and update French localization, documentation and accessibility labels. No new runtime dependency, no account/network requirement and no migration of existing saved palettes.
- Portable test coverage: **178/178 Swift Testing tests passed in debug** including 3 new tests for 300 unique palettes, role/category stability and generated Background/Text and Surface/Text contrast. SwiftUI/AppKit native type-checking, keyboard, VoiceOver, and actual macOS ColorPicker interactions must still be validated on macOS before production sign-off.

## 0.21.0 — Color Studio: curated palettes, named library, OKLCH scales & ΔE00 (source release candidate)

- Add a separate native **Color Studio** window, accessible from the status menu and Colors & Formats. Four independent workspaces: Discover / My Palettes / Color Scales / Compare Colors.
- Bundle **30 palettes** across nine web-design use cases. 26 are original PixNab collections; four are selected, credited subsets of official Nord, Catppuccin Latte, Catppuccin Mocha and Dracula palettes. Original source links and license notices are documented; no remote dependencies or image assets.
- Add role-based website preview, real WCAG 2.x sRGB text and CTA contrast ratios, search/filter, one-click selection, copy, named save, ASE/ACO plus semantic CSS/JSON/SwiftUI exports (conditional P3 CSS override only for genuine stored P3 data).
- Add separate `palettes.v1` persistence; palette rename, duplication, deletion, category assignment, append/remove/reorder colors, and non-destructive, size-limited JSON import/export. Preserve saved P3 provenance; do not mutate picked-color history.
- Implement CIEDE2000 with Sharma published reference-pair tests, Display P3-aware Lab D50 comparison and a separate clearly labeled OKLab sRGB preview metric.
- Implement 50–950 OKLCH scale generation with exact base 500 and binary-search chroma reduction to the sRGB gamut. This is **not claimed** to reproduce CSS Color 4's normative local-MINDE gamut mapping.
- Add French labels for new navigation, descriptions and data warnings. Previous shortcuts, menu bar launch behavior, color wheel and 33 output formats remain untouched.
- Portable Swift Testing coverage expanded from **162 to 175 tests** (debug). Native AppKit/SwiftUI compile and interaction/accessibility checks require a macOS SDK and manual validation.

## 0.20.0 — Color formats, ICC/SDR policy, preferences and language completion (source release candidate)

- Verify and inventory all **33** output-format IDs against ColorSnapper's published *families*; add portable coverage without inventing unverified proprietary format variants. Exact reference variant parity requires a licensed reference-app inventory.
- Fix menu-bar history selection silently dropping captured P3 pixel components and the display-profile name; preserve them on selection and subsequent CSS P3 copy.
- Detect out-of-sRGB P3 colors using unclipped linear-light sRGB values and display a clear clipping warning. Retain existing sRGB output behavior and original encoded Display P3 for CSS P3.
- Make 8-bit SDR the explicit native stream policy on macOS 15+; document that source application/document ICC and HDR luminance are not available from this capture pipeline.
- Complete dynamic French status, accessibility, shortcut recorder, error, count and preference labels; keep System/English/French selection and preserve saved older settings. Improve multiline preference row alignment.
- Five additional portable Swift Testing tests; **162/162 passed in debug and release on Linux**. Full native compilation and hardware/VoiceOver tests remain unverified here. Detailed remaining native/reference acceptance: `docs/RELEASE_GATE_V20.md`.
- No new runtime dependency, command, feature outside this scope, or architecture rearrangement.

## 0.19.8 — Continuous lightness-ring dragging (source hotfix)

- Fix lightness dragging stopping when the pressed pointer drifts a few pixels
  outside the thin outer ring. A drag **started on the ring** now keeps control
  of lightness until mouse-up; the hue/saturation disk cannot interrupt it.
- A drag **started on the disk** retains seamless disk → ring → disk switching
  and continues across the transparent gap without losing the last control.
- Keep the wheel's thin ring, transparent gap, marker geometry, palette actions,
  window navigation and all other application behavior unchanged.
- Add three Swift Testing regression cases for radial drift, angles outside the
  visible wheel, and disk/ring transitions. **157/157 portable tests pass in
  debug on Linux**. Native SwiftUI dragging must still be verified on macOS.
- Release-test compilation was attempted but exceeded the environment's time
  limit; no release-test result is claimed.

## 0.19.7 — Seamless disk-to-lightness-ring pointer interaction

- Fix a wheel interaction regression: hue/saturation and lightness no longer own independent mouse-drag gestures that require changing focus or clicking the ring first.
- Route one continuous gesture across the disk, transparent separator, and outer lightness ring according to the current pointer radius. Clicking or dragging either control works immediately, including moving between them without releasing the mouse.
- Keep the fine lightness ring, transparent gap, existing markers, HSL calculations, keyboard commands, color palettes, windows and preferences unchanged.
- Add three portable tests for disk/ring/gap boundaries, whole-wheel lightness coordinates and invalid geometry. **154/154 Swift Testing tests passed** in both debug and release on Linux; `./run.sh --lint` and Linux `./run.sh --check` passed.
- Native macOS SwiftUI compilation and interactive pointer/focus validation still require confirmation on macOS.

## 0.19.6 — Independent Color Wheel window (targeted navigation hotfix)

- Fix the menu action **Color Wheel…** opening **Colors & Formats** too: the
  former now owns a standalone, cached native window and never calls
  `showFormats()`.
- The button in **Colors & Formats** opens the same wheel window without
  creating another one. The wheel's × button and Escape close that window.
- Continue observing the existing preferences store for live language and
  appearance updates inside the independent wheel. Keep the existing palette
  actions and wheel geometry unchanged.
- Source structure, launch commands, and dependencies remain unchanged.
- Portable Swift Testing and Swift syntax can be checked on Linux; native
  AppKit window opening/closing must be validated on macOS.

## 0.19.5 — Restore free disk selection (critical UI hotfix)

- Fix the v0.19.4 pointer regression: the lightness ring had an all-circle
  `contentShape(Circle())` *above* the chromatic disk, causing lightness drags
  to intercept hue/saturation selection throughout the inner disk.
- Remove the all-circle ring hit area, place the ring gesture **behind** the
  disk, and give the disk its own explicit circular hit target.
- Use the ring's actual frame when converting pointer positions to HSL
  lightness. Keep the thin colored band and transparent gap unchanged.
- No changes to color calculations, palette actions, history or preferences.
- Validation: `swift test` passed **151/151** portable tests (Linux); Swift
  source parsed successfully. Optimized test build was interrupted by a
  runtime limit; native SwiftUI hit testing still requires manual testing
  on macOS (`./run.sh --check`, `./run.sh`).

## 0.19.4 — Color wheel ring spacing hotfix (source release candidate)

- Render the outer lightness control as a true ring instead of a filled circle, so the separator between the ring and the chromatic disk shows the native sheet background as in the approved reference.
- Keep the existing wheel math, handle centering, palette markers, and interactions unchanged; this is a visual geometry hotfix only.
- Portable validation: **151/151 Swift Testing tests** passed in debug after the UI patch. Release test compilation was started in this environment but the build step hit the execution time limit before the suite completed.

## 0.19.3 — Color wheel and RGB editor UX fixes (source release candidate)

- Remove the white separator behind the lightness ring; the existing sheet
  background is now visible between the ring and color disk. Preserve the
  centered lightness handle, original gradient, and wheel coordinate math.
- Remove the two previous/next format arrow buttons from the Colors & Formats
  header; the magnifier's existing format navigation remains unchanged.
- Keep the complete native wheel only in its dedicated sheet. Remove the duplicate
  collapsible HarmonyPicker (and associated redraw overhead) from the anchored
  RGBA popover; use an intrinsic, compact popover height.
- Replace monochrome channel sliders with separate red/green/blue gradients and
  a checkerboard alpha gradient. Support pointer dragging, arrow-key adjustment,
  and accessibility adjustable actions.
- Make palette suggestions actionable: click to select; contextual copy/save on
  any swatch; copy the entire palette using existing session formatting and
  separator; save it to history preserving favorites and order with one persistence
  write; export it as ASE or ACO through the existing encoder and save workflow.
- Three additional portable tests cover ordered palette history, P3 provenance
  separation, and palette formatting. **151/151 tests** passed on Linux in debug and release.
- No new source files, dependencies, CLI flags, or restructuring. This source
  package is **not** a notarized production release. Native UI compilation,
  drag/keyboard/accessibility behavior, and performance must be checked on macOS.

## 0.19.2 — Native ColorWheel parity and testable language selection (source release candidate)

- Replace the fixed-radius hue picker with a native SwiftUI disk allowing arbitrary
  hue and saturation coordinates. Reuse the shared PixNabCore HSL conversion,
  geometric mapping, and harmony palette rules; do not embed JavaScript/WebView.
- Render the disk from eight CSS-derived radial color layers and add the external
  HSL lightness ring. Its 12-point-band handle is precisely centered in the ring.
  No purple focus outline is drawn on the wheel or outer ring during interaction.
- Match the standalone wheel's primary/secondary marker hierarchy and palette
  offsets, including the single +/-10 HSL lightness monochromatic variation.
  Inner-disk selection intentionally resets lightness to 50%, as in the reference.
  Hue and saturation are retained when the lightness reaches black or white.
- Use an icon-only close button in the existing wheel sheet; Escape still closes.
  Keep the sheet accessible through the existing menu and format-browser entry.
- Add **Preferences → Appearance → Language** with System / English / French.
  Persist this field in the existing optional-key settings model; existing
  preferences remain compatible. Localize AppKit menus and window titles at
  runtime, and pass the selected locale through the existing SwiftUI views.
- Add ten targeted geometry, harmony, and language migration tests. Verified
  portable suite: **148/148 Swift Testing tests** on Linux Swift 6.2.1 in both
  debug and release configurations. Static Swift parsing and Bash syntax pass.
- The native UI has **not** been compiled or interactively verified on macOS
  in this environment. Confirm `./run.sh --check`, sheet layout, dragging,
  keyboard operation, and language switching on the user's Mac before sign-off.

## 0.19.1 — Direct color wheel navigation and visible harmony picker (source release candidate)

- Fix discoverability: **Color Wheel…** opens the existing Colors & Formats
  window and immediately presents a dedicated wheel-first sheet.
- Add **Color Wheel** beside **Edit Color** in the existing window toolbar.
  The previous collapsible harmony controls remain available in the RGB editor.
- Share one native HarmonyPicker component across both views. Do not duplicate
  color calculations, introduce dependencies, or change stored user data.
- Render a full hue disk and visible harmony markers instead of only a thin
  gradient ring; keep the shared HSL behavior and selected-color state.
- Add French labels for new navigation and sheet controls.
- **Validation gate:** Swift Testing portable tests run on Linux. Native AppKit/
  SwiftUI build and interactive presentation must be verified on macOS.

## 0.19.0 — Harmonies and provenance consistency (source release candidate)

- Add a **native color harmony wheel** to the existing anchored color editor,
  using standard sRGB/HSL operations rather than Canva's proprietary web code:
  complementary, analogous, triadic, tetradic and monochromatic palettes.
  Accessible buttons select a swatch; dragging the ring changes hue. The panel
  stays collapsible and existing capture controls are unchanged.
- Centralize HSL-to-RGB reconstruction and reuse it in the existing CSS parser
  and harmony calculations; retain alpha and return the precise source color.
- Preserve sampled P3 color identity in the history, saved selection and macOS
  menu swatches. Editing a color in NSColorPanel explicitly clears stale P3
  attribution instead of silently retaining a former capture's metadata.
- Extend native French UI text and localize dynamically generated format-menu
  labels. Keep the existing localization resources and package structure.
- Add six portable regression cases compared to the original v0.18.0 test
  count (two P3 identity tests plus four harmony/HSL tests): **138/138** passed
  on Linux Swift 6.2.1 in debug. macOS compilation and UI acceptance pending.
- **Release gate remains NO-GO**: ColorSnapper reference parity, calibrated
  monitor testing, HDR handling, legal/name clearance, Developer ID notarization,
  accessibility and native UX checks remain unverified. No public signing.

## 0.18.0 — Consolidated functional release candidate (macOS acceptance pending)

- Reuse the existing ScreenCaptureKit stream in Display P3 **SDR BGRA8** rather
  than clipping every captured screen pixel to sRGB at acquisition. The existing
  CoreGraphics sampling path converts the selected pixel to sRGB for traditional
  formats; the encoded Display P3 channels are retained for CSS P3 output.
- Retain source-P3 components with each history item and ordered multi-pick
  session; preserve round-trip and legacy JSON decoding without migration.
  Distinguish two P3 samples even if they clip to identical sRGB bytes.
- Complete the shared format catalog with Generic HSB, Swift NSColor HSB and
  Swift UIColor HSB, using the existing color model and formatter.
- Add initial French native UI localization for existing preferences, menus,
  color editor and format browser. Ship the `fr.lproj` catalog in the main
  application bundle via the existing `run.sh` build path. English remains
  the default; no new command or dependency.
- Regression tests cover source-P3 retention, old saved sessions, clipped gamut
  collisions and HSB numeric reference cases. See the release acceptance notes
  for the precise validation limits and external blockers.
- **Not a production sign-off:** source-app ICC profiles are not obtainable from
  the composited screen pixel; HDR sampling, hardware validation, exact reference
  version/format parity, notarization and trademark clearance remain open.

## 0.17.0 — Swift Testing migration (test infrastructure update)

- Migrate all **126 existing unit tests** across the **same seven test source files**
  from XCTest to `Testing` using `@Suite`, `@Test`, `#expect`, `#require`, and `Issue.record`.
- Preserve test cases, their failure expectations, tolerances, and coverage of
  color conversions, history, formats, input validation, geometry and performance guards.
- Reuse the existing SwiftPM `PixNabCoreTests` target with no extra dependencies.
- Make `./run.sh --test` run the Swift Testing suite in debug mode with
  `--disable-xctest` (no XCTest runtime); `./run.sh --check`
  requires the tests to pass **before** the macOS application build, without a skip path.
- Keep the application version, business logic, file tree, command names and bundle
  structure unchanged. Verified on Linux Swift 6.2.1: 126/126 tests passed.
- Test execution and native UI behavior with Apple's macOS Swift 6.3.3 toolchain
  require a separate run on the target Mac.

## 0.17.0 — macOS Command Line Tools compatibility fix (superseded by Swift Testing migration)

- **Historical behavior, removed by the Swift Testing migration above:** `./run.sh --check` reports missing XCTest and continues building PixNab on macOS rather than failing before the app compilation.
- `./run.sh --test` explicitly fails when XCTest is unavailable; tests have not been removed or falsely marked successful.
- Existing project structure, command names, source files and application version are unchanged.

# Changelog

## 0.17.0 — Consolidated color spaces and export catalog (source release candidate)

- Complete the **existing** shared CSS color input/output workflows for CIE Lab
  and LCH D50, OKLab, OKLCH, HWB, and Display P3. LCH is documented by the
  current official ColorSnapper Pro feature page; undocumented variants were
  not added.
- Reuse `CIELabColor`, `OKLabColor`, `ColorFormatter`, `ColorParser`,
  `SRGBColor`, the existing history and the Colors & Formats UI. No new service,
  framework, file, target or command.
- Convert imported Display P3 to the existing sRGB storage contract; values
  outside sRGB are clipped, and an exported P3 color remains only an encoding
  of an sRGB sample, **not** a preserved wide-gamut measurement.
- Surface the stored capture-time display profile name as a tooltip on each
  history swatch, explicitly labeling it as display metadata and not an
  original per-pixel ICC payload.
- Add nine dedicated numeric, round-trip, alpha, malformed-input and settings
  compatibility tests; 126/126 portable tests and syntax checks passed on Linux.
- Update the 139-item requirement tracker with traceable evidence, retaining
  outstanding native/reference/legal release gates; five source-complete requirements
  move to "À tester", none to "Validée".
- No native macOS build, calibrated P3 capture, full reference-app comparison,
  localization, Adobe direct integration, notarization or trademark clearance
  was possible in this environment. **Not approved for public release.**

## 0.16.6 — CSS Lab import and round-trip conversion (source preview)

- Parse CSS `lab(L% a b / alpha)` in the existing shared `ColorParser`, matching the CSS Lab D50 format introduced in 0.16.5.
- Reuse `CIELabColor` for the inverse D50 XYZ-to-sRGB transformation, preserving the existing normalized sRGB storage and explicit out-of-gamut clipping policy.
- Validate finite numeric components, percent lightness, optional alpha and malformed input; preserve the existing strict parser for Hex, RGB and HSL.
- Add reference, round-trip and invalid-input regression tests; no new files, dependencies, components, commands or project restructuring.
- Advances PN-CLR-006; does not establish numerical accuracy on physical P3 displays, ColorSnapper format parity, or macOS build validation.


## 0.16.5 — CIE Lab conversion and requirement coverage (source preview)

- Implement CSS `lab()` (CIE Lab, D50) using the existing shared formatter and color-conversion module. Converts normalized sRGB to XYZ D50 with Bradford adaptation.
- Expose the format automatically in the existing formats list, preference picker and CLI; no new UI, files, packages or commands.
- Verify Lab numerical references for white, black and red, plus shared formatting options; 114 portable tests pass on Linux.
- Advances PN-CLR-006 and the implemented-format coverage of PN-FMT-001; does **not** establish format parity with ColorSnapper.
- The other open requirements still require real reference-app evidence, macOS interaction and color calibration, or production signing. No macOS build has been run.

## 0.16.4 — Multi-Pick lens feedback (source preview)

- Highlight the existing magnifier border blue while Command is held during picking; precision (yellow) takes precedence if both modes are active.
- Keep Command-click and Command-Return behavior unchanged and non-configurable; global hotkey settings remain unchanged.
- Preserve Escape cancellation, normal click completion, history, and formats.
- Reuse the existing lens drawing and controller update loop; no new files, commands, dependencies or preferences.
- Native macOS interaction and build validation remain pending.

## 0.16.3 — Refresh capture on Space and display changes (source preview)

- Fix the existing display-change path: restart ScreenCaptureKit when macOS changes Space or display configuration even when the display ID remains unchanged.
- Keep the existing capture revision cancellation and stream lifecycle; do not add a second capture path.
- Preserve source layout, commands, formats, preferences, and local data.
- Linux syntax validation and 112 portable tests pass; native macOS capture and fullscreen/Space behavior require manual validation.

## 0.16.2 — Accurate capture-profile history metadata (source preview)

- Fix repeated picks retaining a previous display's profile when the latest capture has no profile metadata.
- Preserve existing favorite state and stable history ID; use the current capture's profile when present.
- Reuse the existing `ColorHistory.add` path, avoiding a second scan/removal of the history list.
- Add profile-refresh regression tests. No new files, commands, components, or dependencies.
- macOS native build and physical capture validation remain pending.

## 0.16.1 — Fix display-profile history propagation (source preview)

- Complete the existing sample → controller → history metadata path.
- Fix missing argument when constructing `SampledPixel` in the macOS target.
- No new modules, files, commands or dependencies. Native macOS build and visual acceptance remain unverified.

## 0.16.0 — Targeted work on incomplete requirements (source preview)

- Added temporary fn-key event passthrough during picking to allow interaction with content behind the loupe; restore picker interactions on release. Native interaction verification pending.
- Reuse the existing display-reconfiguration path when macOS changes the active Space. Fullscreen behavior must be validated on a Mac.
- Record the active display color-space profile name with newly picked history entries, without changing the sRGB output pipeline or older saved data. This is display metadata, **not** preservation of original per-pixel ICC or HDR information.
- Added three portable regression tests for profile metadata and history compatibility.
- Kept the existing source tree, package targets, run.sh interface, and existing components.
- NOT CLOSED: original-pixel ICC provenance, measured sRGB/P3 accuracy, reference-only format variants, reference-UI pixel parity, and native Space/fullscreen tests. No proprietary reference list was invented.
- Linux checks only; native macOS compilation and interaction are unverified.

## 0.15.2 — Lens geometry and internal color overlay

- Remove the external caption panel below the magnifier circle.
- Display the color format and value inside the lens, with very light translucent backing and text shadow.
- Keep the center pixel unobstructed; clip the label within the circle.
- Clamp the square magnifier to the current display so it reaches the bottom, top and side edges.
- Introduce testable lens geometry and four new regression tests.
- No changes to CPU Per-Pixel, global hotkeys, history, formats or persisted preferences.

## 0.15.1 — Fix phantom empty Settings window

- Replaced the SwiftUI app lifecycle and its empty `Settings` scene with an AppKit-only menu-bar entry point.
- Preserved SwiftUI views inside the existing AppKit Preferences / Colors & Formats windows.
- Disabled automatic window restoration, including for windows created by older releases.
- Added a menu-bar startup regression check to `run.sh --lint` and `--check`.
- No changes to sampling, color formatting, user settings, keyboard shortcuts or history.

See `docs/HOTFIX_V15_1.md`.

## 0.15.0 — Production cleanup

- CPU Per-Pixel is the only sampling engine.
- Removed legacy, Single-Pass and Bulk-Rows samplers and all benchmark runtimes.
- Removed capture performance diagnostics and experimental strategy environment variable.
- Preserved ScreenCaptureKit frame admission, render caching and sRGB contract.
- Replaced experimental sampler A/B tests with production extraction correctness tests.
- Removed obsolete performance commands, helpers and benchmark documentation.
- Preserved `run.sh`, menu bar features and local settings/history.

See `docs/DELIVERY_V15.md`.
