# GE-Proton8-16 with Proton-SpeedHack8.0-5

This project builds a minimally changed GE-Proton8-16 compatibility tool for Steam Deck.
Builds run on GitHub Actions. No Linux, WSL, or Docker installation is required on your PC.

**Status:** both architecture builds, the 7,231-file audit, and 32-bit/64-bit timer tests passed.
[Validated build](https://github.com/sevansup/GE-Proton8-16-SpeedHack/actions/runs/38167735048).
An installable download is produced only after both architecture builds, the unchanged-file audit,
and the timer tests succeed. A Steam Deck game test is still required afterward.

## Exact inputs

- GE-Proton8-16: `614f8bebd889eac7a2cf0da9f79826a1b56b4550`
- GE Wine: `a20f0c78bb36bfccd5e1e4b079aef06a22672745`, with GE's own staging/game patches
- GE Wine Staging: `e9f69afcab7a6143abb54854945bdbf7f091c60c`
- Proton-SpeedHack8.0-5: `4bee057455757c631befda38f78fc9aecb176567`
- SpeedHack Wine patch: `812d73129db959eb704f60e5ec88476d911663de`
- Build SDK: GE's original `registry.gitlab.steamos.cloud/proton/sniper/sdk:0.20230905.59202-0`

Sources: [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom/tree/GE-Proton8-16),
[Proton-SpeedHack](https://github.com/LtSquigs/Proton-SpeedHack/tree/proton-speedhack-8.0-5),
[SpeedHack Wine](https://github.com/LtSquigs/wine/commit/812d73129db959eb704f60e5ec88476d911663de).

## Scope

The two patches contain the original speedhack additions only. They do not upgrade GE,
DXVK, VKD3D, GStreamer, codecs, game fixes, or other components. GE's existing patch preparation
is retained. Generated Wine protocol files are regenerated to match the new request.

The build starts with the checksum-verified official GE-Proton8-16 release and replaces only:

- 32-bit and 64-bit `ntdll.dll`, `ntdll.so`, and `steam.exe.so`
- 64-bit `wow64.dll` and `wineserver`
- `proton` (speedhack configuration loading)
- `compatibilitytool.vdf` and `version` (a distinct variant name)

It adds the original `speedhack.json` template. Every other upstream file and symlink is
checked for identical content; file modes are also compared. `changed-files.json` records
the exact differences and hashes. The archive retains GE's original licenses.

No extra speedhack fixes or refactoring are included. Inherited quirks in the original
speedhack remain; use launch options for configuration. The original loader has known
JSON key/toggle parsing inconsistencies and incorrect mappings for the letters K–N.
The default Page Up hotkey and the launch options below avoid those particular issues.

## Build and download

1. Open **Actions → Build GE-Proton8-16 SpeedHack → Run workflow**.
2. After success, download **GE-Proton8-16-SpeedHack-download**.
3. Unzip the downloaded Actions artifact to find `GE-Proton8-16-SpeedHack.zip`.
4. On the Steam Deck, extract that inner ZIP into
   `~/.steam/root/compatibilitytools.d/` with a Linux archive tool that preserves symlinks
   and executable permissions. The resulting folder is `GE-Proton8-16-SpeedHack`.
5. Restart Steam and select **GE-Proton8-16-SpeedHack** in the game's Compatibility settings.

Example launch options (3× speed, toggle with Page Up):

```text
SPEEDHACK_SPEED=3 SPEEDHACK_TOGGLE=1 SPEEDHACK_KEYS=page_up %command%
```

Map a Steam Input button to Page Up. Set `SPEEDHACK_TOGGLE=0` for hold-to-accelerate.
The speedhack changes game timing; it does not add audio time stretching.

## Validation

The workflow tests 32-bit and 64-bit Windows programs against the assembled Wine runtime.
Each test measures the performance counter against unscaled wall time at 1×, 3×, and 1× again.
This verifies the timing export and return to normal speed. It does not establish compatibility
with every game, graphics workload, media cutscene, or the Steam Input hotkey path.

Build automation is separate from runtime changes. `scripts/prepare.py` retrieves the pinned
upstream sources and applies the patches. Both upstream projects retain their original licenses;
the patch files are modifications to those projects under their respective licenses.
