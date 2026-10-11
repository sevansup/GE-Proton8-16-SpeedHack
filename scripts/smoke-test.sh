#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")/.." && pwd)
files="$project/output/package/GE-Proton8-16-SpeedHack/files"
export LD_LIBRARY_PATH="$files/lib64:$files/lib:$files/lib64/wine/x86_64-unix:$files/lib/wine/i386-unix"
export WINESERVER="$files/bin/wineserver"
export WINEPREFIX="$project/work/test-prefix"
export WINEARCH=win64 WINEDEBUG=-all
export WINEDLLOVERRIDES='winemenubuilder.exe=d'
export WINEESYNC=0 WINEFSYNC=0
trap '"$WINESERVER" -k || true' EXIT
timeout 120 "$files/bin/wine64" "$project/output/tests/timer64.exe"
timeout 120 "$files/bin/wine" "$project/output/tests/timer32.exe"
"$WINESERVER" -w
