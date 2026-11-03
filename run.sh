#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ACTION="run"
CONFIG="release"

# Developer CLI shares PixNabCore with the menu bar application.
if [[ "${1:-}" == "--cli" ]]; then
    shift
    exec swift run -c release pixnab-cli "$@"
fi
while [[ $# -gt 0 ]]; do
    argument="$1"
    shift
    case "$argument" in
        --build) ACTION="build" ;;
        --check) ACTION="check" ;;
        --lint) ACTION="lint" ;;
        --test) ACTION="test" ;;
        --clean) ACTION="clean" ;;
        --xcode) ACTION="xcode" ;;
        --debug) CONFIG="debug" ;;
        --help|-h)
            printf '%s\n' "Usage: ./run.sh [--build|--test|--check|--lint|--clean|--xcode] [--debug]" \
                         "       ./run.sh --cli formats" \
                         "       ./run.sh --cli convert '#ff8800' cssOKLCH"
            echo "Default: build, assemble PixNab.app, and open the app."
            exit 0 ;;
        *) echo "Unknown argument: $argument" >&2; exit 2 ;;
    esac
done

lint_sources() {
    echo "Checking Bash syntax and all Swift sources..."
    bash -n "$ROOT/run.sh"
    # A SwiftUI Settings scene without content produced an unwanted blank
    # "PixNab Settings" window on startup (fixed in 0.15.1).
    if grep -Eq '^[[:space:]]*(Settings|WindowGroup|DocumentGroup)[[:space:]]*\{' \
        "$ROOT/Sources/PixNab/App/PixNabApp.swift"; then
        echo "Menu-bar startup contract violated: do not declare an implicit SwiftUI window scene." >&2
        return 1
    fi
    if ! grep -Fq 'NSApplication.shared' "$ROOT/Sources/PixNab/App/PixNabApp.swift"; then
        echo "Menu-bar startup contract violated: expected an AppKit application entry point." >&2
        return 1
    fi
    command -v swiftc >/dev/null || { echo "swiftc is required for syntax checking" >&2; return 1; }
    local file
    # Parser mode doesn't require the macOS SDK and catches syntax regressions
    # in SwiftUI/AppKit files, but it is NOT a substitute for a native build.
    while IFS= read -r -d '' file; do
        swiftc -frontend -parse "$file"
    done < <(find "$ROOT/Sources" "$ROOT/Tests" -name '*.swift' -type f -print0)
    if [[ "$(uname -s)" == "Darwin" ]]; then plutil -lint "$ROOT/AppInfo.plist"; fi
    echo "Static syntax checks passed."
}

if [[ "$ACTION" == "lint" || "$ACTION" == "check" ]]; then
    lint_sources
    if [[ "$ACTION" == "lint" ]]; then exit 0; fi
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    if [[ "$ACTION" == "test" || "$ACTION" == "check" ]]; then
        echo "Running platform-independent PixNabCore tests. macOS app build is skipped on this system."
        swift test -c debug --disable-xctest
        exit $?
    fi
    echo "PixNab is a macOS application. Run this command on a Mac with Xcode 15.3+ installed." >&2
    exit 1
fi

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swift >/dev/null 2>&1; then
    echo "Xcode or Xcode Command Line Tools are missing. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    exit 1
fi

# Use Swift Testing only: no XCTest availability or XCTest runtime required.
# Run unit tests in debug mode for fast feedback; the macOS app is still built
# with the requested release/debug configuration. Fail on any test failure.
case "$ACTION" in
    check)
        echo "Running Swift Testing suite before building the macOS app…"
        swift test -c debug --disable-xctest
        ;;
    clean)
        swift package clean
        rm -rf "$ROOT/dist"
        echo "Build artifacts removed."
        exit 0 ;;
    xcode)
        open -a Xcode "$ROOT/Package.swift"
        exit 0 ;;
    test)
        swift test -c debug --disable-xctest
        exit 0 ;;
esac

swift build -c "$CONFIG" --product PixNab
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
EXECUTABLE="$BIN_DIR/PixNab"
[[ -x "$EXECUTABLE" ]] || { echo "Build succeeded but executable was not found: $EXECUTABLE" >&2; exit 1; }

APP="$ROOT/dist/PixNab.app"
# Assemble from a clean bundle to avoid stale files carried across versions.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$EXECUTABLE" "$APP/Contents/MacOS/PixNab"
chmod +x "$APP/Contents/MacOS/PixNab"

# Native .lproj catalogs belong in the main application bundle so SwiftUI and
# AppKit can resolve the same localization without additional runtime wrappers.
if [[ -d "$ROOT/Sources/PixNab/Resources/fr.lproj" ]]; then
    cp -R "$ROOT/Sources/PixNab/Resources/fr.lproj" "$APP/Contents/Resources/"
fi

# SwiftPM resource bundles (if any are added later) belong beside the executable.
find "$BIN_DIR" -maxdepth 1 -type d -name '*.bundle' -print0 |
while IFS= read -r -d '' bundle; do cp -R "$bundle" "$APP/Contents/Resources/"; done

codesign --force --sign - --timestamp=none "$APP"
echo "Built: $APP"

if [[ "$ACTION" == "run" ]]; then
    # Avoid multiple copies of the same menu bar application.
    pgrep -x PixNab >/dev/null 2>&1 && {
        echo "PixNab may already be running. Quit the prior instance from the menu bar before retrying." >&2
        exit 1
    }
    open "$APP"
    echo "PixNab opened. Find the eyedropper icon in the macOS menu bar."
fi
