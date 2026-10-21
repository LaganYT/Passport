#!/bin/bash
# Takes Passport's hook out of Steam and removes the compatibility tool. The Voile runtime stays in
# ~/Library/Application Support/Passport; move that folder to the Trash to free the space.
set -euo pipefail

support="$HOME/Library/Application Support/Passport"
steam_app=${STEAM_APP:-/Applications/Steam.app}

pgrep -x steam_osx >/dev/null && { echo "Quit Steam first." >&2; exit 1; }
[ -f "$support/Info.plist.orig" ] || { echo "No saved Info.plist, so there is nothing to restore." >&2; exit 1; }

cp "$support/Info.plist.orig" "$steam_app/Contents/Info.plist"
rm -f "$steam_app/Contents/MacOS/passport.dylib"
codesign -f -s - "$steam_app"
rm -rf "$HOME/Library/Application Support/Steam/compatibilitytools.d/passport"
echo "Passport removed from Steam."
