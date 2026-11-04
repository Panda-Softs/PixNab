#!/usr/bin/env bash
# Builds PixNab.app and packages it as a versioned macOS DMG.
# Supports ad-hoc signed development releases; does not notarize.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST="$ROOT/AppInfo.plist"
BUMP=""
TARGET_VERSION=""
RUN_TESTS=0
SHOW_VERSION=0

usage() {
  cat <<'EOF'
Usage: ./release-dmg.sh [options]

  (no options)         Read AppInfo.plist and create dist/PixNab-vX.Y.Z.dmg
  --bump patch         Increment patch version (0.22.2 -> 0.22.3)
  --bump minor         Increment minor version (0.22.2 -> 0.23.0)
  --bump major         Increment major version (0.22.2 -> 1.0.0)
  --version X.Y.Z      Set a specific newer semantic version
  --test               Run the Swift tests before building
  --show-version       Print current app version and build number
  -h, --help           Show this help

Version changes update AppInfo.plist and increment CFBundleVersion by 1.
An existing DMG is never overwritten. All temporary staging files are removed.
This script builds an ad-hoc signed app; public notarization requires Developer ID.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump)
      [[ $# -ge 2 ]] || { echo "Missing value after --bump" >&2; exit 2; }
      [[ -z "$BUMP" && -z "$TARGET_VERSION" ]] || { echo "Choose either --bump or --version" >&2; exit 2; }
      BUMP="$2"; shift 2 ;;
    --version)
      [[ $# -ge 2 ]] || { echo "Missing value after --version" >&2; exit 2; }
      [[ -z "$BUMP" && -z "$TARGET_VERSION" ]] || { echo "Choose either --bump or --version" >&2; exit 2; }
      TARGET_VERSION="$2"; shift 2 ;;
    --test) RUN_TESTS=1; shift ;;
    --show-version) SHOW_VERSION=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -f "$PLIST" ]] || { echo "Missing $PLIST: place this script next to AppInfo.plist and run.sh" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required (install Xcode Command Line Tools)" >&2; exit 1; }

read -r CURRENT_VERSION CURRENT_BUILD < <(python3 - "$PLIST" <<'PY'
import plistlib, re, sys
with open(sys.argv[1], 'rb') as f:
    info = plistlib.load(f)
v = str(info.get('CFBundleShortVersionString', ''))
b = str(info.get('CFBundleVersion', ''))
if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', v):
    sys.exit('Invalid CFBundleShortVersionString (expected X.Y.Z): ' + v)
if not b.isdecimal():
    sys.exit('Invalid CFBundleVersion (expected a nonnegative integer): ' + b)
print(v, b)
PY
)

if [[ "$SHOW_VERSION" == 1 ]]; then
  [[ -z "$BUMP" && -z "$TARGET_VERSION" && "$RUN_TESTS" == 0 ]] || {
    echo "--show-version cannot be combined with build or version options" >&2; exit 2;
  }
  printf 'PixNab %s (build %s)\n' "$CURRENT_VERSION" "$CURRENT_BUILD"
  exit 0
fi

case "$BUMP" in
  ''|patch|minor|major) ;;
  *) echo "Invalid bump: $BUMP (expected patch, minor or major)" >&2; exit 2 ;;
esac

NEW_VERSION="$(python3 - "$CURRENT_VERSION" "$BUMP" "$TARGET_VERSION" <<'PY'
import re, sys
current, bump, requested = sys.argv[1:]
pattern = r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
a, b, c = (int(x) for x in current.split('.'))
if requested:
    if not re.fullmatch(pattern, requested):
        sys.exit('Invalid --version: use X.Y.Z without v prefix')
    next_version = tuple(int(x) for x in requested.split('.'))
    if next_version <= (a, b, c):
        sys.exit('Requested version must be newer than ' + current)
    print(requested)
elif bump == 'major':
    print(f'{a+1}.0.0')
elif bump == 'minor':
    print(f'{a}.{b+1}.0')
elif bump == 'patch':
    print(f'{a}.{b}.{c+1}')
else:
    print(current)
PY
)"

OUTPUT="$ROOT/dist/PixNab-v${NEW_VERSION}.dmg"
[[ ! -e "$OUTPUT" ]] || { echo "DMG already exists; refusing to overwrite: $OUTPUT" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || { echo "DMG creation requires macOS" >&2; exit 1; }
[[ -f "$ROOT/run.sh" ]] || { echo "Missing $ROOT/run.sh" >&2; exit 1; }
for tool in codesign ditto hdiutil shasum; do
  command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2; exit 1; }
done
mkdir -p "$ROOT/dist"
WORKDIR="$(mktemp -d "$ROOT/dist/.release-dmg.XXXXXXXX")"
PLIST_BACKUP="$WORKDIR/AppInfo.plist.original"
cp "$PLIST" "$PLIST_BACKUP"
VERSION_WAS_CHANGED=0
FINISHED=0
cleanup() {
  status=$?
  trap - EXIT
  if [[ "$FINISHED" != 1 && "$VERSION_WAS_CHANGED" == 1 ]]; then
    # Do not leave a partially prepared version number after a failed build.
    cp "$PLIST_BACKUP" "$PLIST"
    echo "Restored AppInfo.plist after unsuccessful release." >&2
  fi
  rm -rf "$WORKDIR"   # Includes the temporary dmg-stage directory.
  exit "$status"
}
trap cleanup EXIT

if [[ "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
  python3 - "$PLIST" "$NEW_VERSION" <<'PY'
import os, plistlib, sys, tempfile
path, version = sys.argv[1:]
with open(path, 'rb') as f:
    info = plistlib.load(f)
info['CFBundleShortVersionString'] = version
info['CFBundleVersion'] = str(int(info['CFBundleVersion']) + 1)
# Write to an adjacent file, then atomically replace.
fd, temp = tempfile.mkstemp(prefix='.AppInfo.', suffix='.plist', dir=os.path.dirname(path))
try:
    with os.fdopen(fd, 'wb') as out:
        plistlib.dump(info, out, fmt=plistlib.FMT_XML, sort_keys=False)
    os.chmod(temp, os.stat(path).st_mode & 0o777)
    os.replace(temp, path)
finally:
    if os.path.exists(temp):
        os.unlink(temp)
PY
  VERSION_WAS_CHANGED=1
  echo "Version updated: $CURRENT_VERSION -> $NEW_VERSION (build $((10#$CURRENT_BUILD + 1)))"
fi

cd "$ROOT"
if [[ "$RUN_TESTS" == 1 ]]; then
  echo 'Running PixNab tests...'
  ./run.sh --test
fi

echo 'Building PixNab.app (release)...'
./run.sh --build
APP="$ROOT/dist/PixNab.app"
[[ -d "$APP" ]] || { echo "Build did not create $APP" >&2; exit 1; }

# Check the assembled bundle's actual version, not just the source plist.
ACTUAL_VERSION="$(python3 - "$APP/Contents/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    print(plistlib.load(f).get('CFBundleShortVersionString', ''))
PY
)"
[[ "$ACTUAL_VERSION" == "$NEW_VERSION" ]] || {
  echo "Built app version mismatch: expected $NEW_VERSION, found $ACTUAL_VERSION" >&2; exit 1;
}
codesign --verify --verbose=2 "$APP"

STAGE="$WORKDIR/dmg-stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/PixNab.app"
ln -s /Applications "$STAGE/Applications"

TEMP_DMG="$WORKDIR/PixNab-v${NEW_VERSION}.dmg"
echo "Creating PixNab-v${NEW_VERSION}.dmg..."
hdiutil create \
  -volname 'PixNab' \
  -srcfolder "$STAGE" \
  -format UDZO \
  -ov \
  "$TEMP_DMG"
hdiutil verify "$TEMP_DMG"

mv "$TEMP_DMG" "$OUTPUT"
FINISHED=1
printf '\nCreated: %s\n' "$OUTPUT"
shasum -a 256 "$OUTPUT"
printf '\nNote: App signature is ad hoc; this DMG is not notarized by Apple.\n'
if [[ "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
  printf 'AppInfo.plist was updated. Review and commit that file before tagging a GitHub release.\n'
fi
