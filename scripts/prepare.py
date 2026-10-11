#!/usr/bin/env python3
"""Prepare exact upstream sources; never operate on an existing user checkout."""
import argparse
import pathlib
import subprocess

GE = "614f8bebd889eac7a2cf0da9f79826a1b56b4550"
CONFIG_REVERT = "e813ca5771658b00875924ab88d525322e50d39f"
ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(*args, cwd=None):
    subprocess.run(args, cwd=cwd, check=True)


def prepare(destination):
    ge = pathlib.Path(destination).resolve()
    if ge.exists():
        raise SystemExit(f"Refusing to overwrite existing directory: {ge}")
    run("git", "clone", "--depth", "1", "--branch", "GE-Proton8-16",
        "https://github.com/GloriousEggroll/proton-ge-custom.git", str(ge))
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ge, text=True).strip()
    if actual != GE:
        raise SystemExit(f"GE tag changed: expected {GE}, got {actual}")
    run("git", "submodule", "update", "--init", "--depth", "1",
        "wine", "wine-staging", "openvr", cwd=ge)
    run("git", "fetch", "--depth", "2", "origin", CONFIG_REVERT, cwd=ge / "wine")

    # Reproduce GE's stock Wine patch preparation. The omitted initial block
    # only resets unrelated DXVK/vkd3d sources and applies the Steam helper patch.
    # Apply that helper patch explicitly. No GE Wine patch is omitted.
    with (ge / "patches/steam_helper/6555.patch").open("rb") as patch:
        subprocess.run(["patch", "--batch", "-Np1"], cwd=ge, stdin=patch, check=True)
    original = (ge / "patches/protonprep-valve-staging.sh").read_text()
    wine_only = original[original.index("### (2) WINE PATCHING ###"):]
    # Regenerate after the speedhack patch, rather than twice.
    wine_only = wine_only.replace('DESTDIR="." --all', 'DESTDIR="." --no-autoconf --all')
    run("bash", "-e", "-c", wine_only, cwd=ge)
    run("git", "apply", "--check", str(ROOT / "patches/proton-speedhack.patch"), cwd=ge)
    run("git", "apply", str(ROOT / "patches/proton-speedhack.patch"), cwd=ge)
    run("git", "apply", "--check", str(ROOT / "patches/wine-speedhack.patch"), cwd=ge / "wine")
    run("git", "apply", str(ROOT / "patches/wine-speedhack.patch"), cwd=ge / "wine")
    run("perl", "tools/make_requests", cwd=ge / "wine")
    compile((ge / "proton").read_text(), str(ge / "proton"), "exec")
    print(f"Prepared GE-Proton8-16 + Proton-SpeedHack8.0-5 in {ge}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("destination")
    prepare(parser.parse_args().destination)
