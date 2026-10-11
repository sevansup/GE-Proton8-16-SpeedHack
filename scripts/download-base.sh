#!/usr/bin/env bash
set -euo pipefail
destination=${1:?Specify a destination directory}
mkdir -p "$destination"
archive="$destination/GE-Proton8-16.tar.gz"
curl --fail --location --retry 3 --silent --show-error \
  https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton8-16/GE-Proton8-16.tar.gz \
  --output "$archive"
printf '%s  %s\n' \
  7c34cb1005fb634a256db3ba47e71d04b41477ac03881ee4ab918fc3725142ffe9fff49f6ad8a5104a1cef86e8187274be3c6bcd9a66ce810c3db1a4632be5bb \
  "$archive" | sha512sum --check --strict
tar -xzf "$archive" -C "$destination"
