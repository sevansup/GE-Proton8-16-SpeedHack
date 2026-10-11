#!/usr/bin/env bash
# Run inside the exact Steam Runtime SDK used by GE-Proton8-16.
set -euo pipefail
bits=${1:?32 or 64}
case "$bits" in 32|64) ;; *) exit 2 ;; esac
project=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$project/work/ge/wine"
ge="$project/work/ge"
obj="$project/work/build$bits"
overlay="$project/output/overlay$bits"
mkdir -p "$obj" "$overlay/files"
trap 'rc=$?; if [[ $rc != 0 && -f "$obj/config.log" ]]; then tail -180 "$obj/config.log"; fi' EXIT
export CCACHE_DISABLE=1

cd "$source_dir"
autoreconf -fiv
# GE regenerates these in its normal source preparation.
python3 dlls/winevulkan/make_vulkan -x vk.xml

if [[ "$bits" == 64 ]]; then
  host=x86_64-linux-gnu
  cross=x86_64-w64-mingw32
  arch=x86_64
  pkg_host=x86_64-linux-gnu
  pkg_cross=x86_64-w64-mingw32
  lib=lib64
  extra=(--enable-win64)
  arch_flags=-mcmodel=small
else
  host=i686-linux-gnu
  cross=i686-w64-mingw32
  arch=i386
  pkg_host=i386-linux-gnu
  pkg_cross=i386-w64-mingw32
  lib=lib
  extra=()
  arch_flags=-mstackrealign
fi
flags="-ggdb -ffunction-sections -fdata-sections -fno-omit-frame-pointer -O2 -march=nocona -mtune=core-avx2 -mfpmath=sse -fwrapv -fno-strict-aliasing $arch_flags"
export CC="$host-gcc" CXX="$host-g++" AR="$host-ar" RANLIB="$host-ranlib"
export CROSSCC="$cross-gcc" CROSSCXX="$cross-g++" CROSSAR="$cross-ar"
export CROSSRANLIB="$cross-ranlib" CROSSLD="$cross-ld"
export CFLAGS="$flags" CXXFLAGS="$flags -std=c++17" CPPFLAGS="$flags"
export CROSSCFLAGS="$flags" CROSSCXXFLAGS="$flags -std=c++17"
export CROSSLDFLAGS="-Wl,--file-alignment,4096"
export PKG_CONFIG="$host-pkg-config"
export PKG_CONFIG_LIBDIR="/usr/lib/$pkg_host/pkgconfig:/usr/share/pkgconfig"
export CROSSPKG_CONFIG_LIBDIR="/usr/lib/$pkg_cross/pkgconfig:/usr/share/pkgconfig"

cd "$obj"
"$source_dir/configure" --prefix="$obj/install" --libdir="$obj/install/$lib" \
  --host="$host" --with-mingw --disable-tests "${extra[@]}"

# Build only the affected modules, their build tools, and helper import libraries.
targets=(dlls/ntdll/all tools/winegcc/all dlls/winecrt0/libwinecrt0.a)
imports=(ucrtbase ntdll kernel32 user32 advapi32 shell32 comdlg32 gdi32 shlwapi msi ole32)
for module in "${imports[@]}"; do
  targets+=("dlls/$module/lib$module.a")
done
if [[ "$bits" == 64 ]]; then targets+=(server/all dlls/wow64/all); fi
# The external Steam helper includes generated COM headers that module-only
# builds do not otherwise request. Generate the public IDL headers first.
while IFS= read -r header; do targets+=("$header"); done < <(
  python3 - <<'HEADERS'
import re
from pathlib import Path
for line in Path("Makefile").read_text().splitlines():
    match = re.match(r"^(include/[^\s:]+\.h):", line)
    if match:
        print(match.group(1))
HEADERS
)
make -j"$(nproc)" "${targets[@]}"

# Compile GE's own steam helper with the original speedhack addition.
helper="$project/work/helper$bits"
mkdir -p "$helper"
cp -a "$ge/steam_helper/." "$helper/"
cd "$helper"
import_flags=()
for module in "${imports[@]}" winecrt0; do import_flags+=("-L$obj/dlls/$module"); done
"$obj/tools/winegcc/wineg++" -m"$bits" -mwindows -mno-cygwin \
  --winebuild "$obj/tools/winebuild/winebuild" \
  -I"$obj/include" -I"$source_dir/include" -I"$source_dir/include/wine" \
  -I"$ge/lsteamclient/steamworks_sdk_142" -I"$ge/openvr/headers" \
  $flags -std=c++17 -Wno-attributes \
  steam.cpp jsoncpp.cpp "${import_flags[@]}" -L"$helper/$bits" \
  -lsteam_api -lshlwapi -lmsi -lole32 -ldl -static-libgcc -static-libstdc++ \
  -o steam.exe

unix_dest="$overlay/files/$lib/wine/$arch-unix"
pe_dest="$overlay/files/$lib/wine/$arch-windows"
mkdir -p "$unix_dest" "$pe_dest"
install -m 755 "$obj/dlls/ntdll/ntdll.so" "$unix_dest/ntdll.so"
install -m 644 "$obj/dlls/ntdll/$arch-windows/ntdll.dll" "$pe_dest/ntdll.dll"
install -m 755 "$helper/steam.exe.so" "$unix_dest/steam.exe.so"
if [[ "$bits" == 64 ]]; then
  mkdir -p "$overlay/files/bin"
  install -m 755 "$obj/server/wineserver" "$overlay/files/bin/wineserver"
  install -m 644 "$obj/dlls/wow64/x86_64-windows/wow64.dll" "$pe_dest/wow64.dll"
fi
find "$overlay" -type f -exec strip --strip-debug '{}' +

# A small Windows program exercises the new exported function and timer behavior.
mkdir -p "$project/output/tests"
"$cross-gcc" -O2 "$project/scripts/timer-test.c" -o "$project/output/tests/timer$bits.exe"
tar -czf "$project/output/overlay$bits.tar.gz" -C "$overlay" .
printf 'Built %s-bit speedhack components\n' "$bits"
