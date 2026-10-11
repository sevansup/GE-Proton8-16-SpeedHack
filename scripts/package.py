#!/usr/bin/env python3
"""Overlay only the eight rebuilt binaries and audit every other upstream file."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE_NAME = "GE-Proton8-16"
NAME = "GE-Proton8-16-SpeedHack"
BASE = ROOT / "work/base" / BASE_NAME
DEST = ROOT / "output/package" / NAME
BINARY_PATHS = {
    "files/bin/wineserver",
    "files/lib64/wine/x86_64-windows/wow64.dll",
}
for lib, arch in (("lib", "i386"), ("lib64", "x86_64")):
    BINARY_PATHS.update({
        f"files/{lib}/wine/{arch}-unix/ntdll.so",
        f"files/{lib}/wine/{arch}-unix/steam.exe.so",
        f"files/{lib}/wine/{arch}-windows/ntdll.dll",
    })
ALLOWED = BINARY_PATHS | {"proton", "version", "compatibilitytool.vdf", "speedhack.json"}


def fingerprint(path):
    if path.is_symlink():
        return {"symlink": os.readlink(path)}
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return {"sha256": digest.hexdigest(), "mode": stat.S_IMODE(path.stat().st_mode)}


def inventory(folder):
    return {str(p.relative_to(folder)): fingerprint(p)
            for p in sorted(folder.rglob("*")) if p.is_symlink() or p.is_file()}


def main():
    if DEST.exists():
        raise SystemExit(f"Refusing to overwrite {DEST}")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    before = inventory(BASE)
    shutil.copytree(BASE, DEST, symlinks=True)
    for bits in (32, 64):
        overlay = ROOT / f"work/overlay{bits}"
        overlay.mkdir(parents=True, exist_ok=False)
        subprocess.run(["tar", "-xzf", str(ROOT / f"output/overlay{bits}.tar.gz"),
                        "-C", str(overlay)], check=True)
        for path in overlay.rglob("*"):
            if not path.is_file():
                continue
            relative = str(path.relative_to(overlay))
            if relative not in BINARY_PATHS:
                raise SystemExit(f"Unexpected overlay file: {relative}")
            target = DEST / relative
            target.chmod(0o644)
            shutil.copy2(path, target)

    # Apply the launcher diff to the release's byte-identical GE launcher.
    sections = re.split(r"(?=^diff --git )", (ROOT / "patches/proton-speedhack.patch").read_text(),
                        flags=re.MULTILINE)
    for filename in ("proton", "speedhack.json.template"):
        matching = [s for s in sections if s.startswith(f"diff --git a/{filename} b/{filename}\n")]
        if len(matching) != 1:
            raise SystemExit(f"Missing or duplicate patch section: {filename}")
        subprocess.run(["patch", "--batch", "--no-backup-if-mismatch", "--fuzz=0", "-p1"], input=matching[0],
                       text=True, cwd=DEST, check=True)
    (DEST / "speedhack.json.template").rename(DEST / "speedhack.json")
    for filename in ("compatibilitytool.vdf", "version"):
        p = DEST / filename
        p.write_text(p.read_text().replace(BASE_NAME, NAME))
    after = inventory(DEST)
    changed = {p for p in before.keys() | after.keys() if before.get(p) != after.get(p)}
    if changed - ALLOWED:
        raise SystemExit(f"Unexpected changes: {sorted(changed - ALLOWED)}")
    if not BINARY_PATHS.issubset(changed):
        raise SystemExit(f"Expected rebuilt binaries missing: {sorted(BINARY_PATHS - changed)}")
    if any(p not in after for p in before):
        raise SystemExit("An upstream file was removed")
    compile((DEST / "proton").read_text(), "proton", "exec")
    report = {"base": BASE_NAME, "variant": NAME,
              "unchanged_files": len(before) - len(changed & before.keys()),
              "changes": {p: {"before": before.get(p), "after": after.get(p)}
                          for p in sorted(changed)}}
    (ROOT / "output/changed-files.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Audited {len(before)} upstream files; exactly {len(changed)} allowed changes.")


if __name__ == "__main__":
    main()
