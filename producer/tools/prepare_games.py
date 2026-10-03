#!/usr/bin/env python3
"""Resolve selected games' Debian dependencies from an exact clean producer."""
import argparse
import json
import os
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("cache", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
parser.add_argument("--games", required=True)
parser.add_argument("--graphics", choices=["enabled", "disabled"], required=True)
args = parser.parse_args()
if args.games == "none":
    parser.error("No games selected; do not fetch a games context")
lock = json.loads((root / "producer/games.lock.json").read_text())
if lock["schema"] != 1 or not re.fullmatch(r"[0-9a-f]{40}", lock["revision"]):
    parser.error("Invalid games producer lock")
override = os.environ.get("GAMES_SOURCE")
directory = pathlib.Path(override).resolve() if override else args.cache.resolve() / ("games-" + lock["revision"])
if not override and not (directory / ".git").exists():
    directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "--quiet", str(directory)], check=True)
    subprocess.run(["git", "-C", str(directory), "remote", "add", "origin", lock["url"]], check=True)
    subprocess.run(["git", "-C", str(directory), "fetch", "--depth", "1", "origin", lock["revision"]], check=True)
    subprocess.run(["git", "-C", str(directory), "checkout", "--quiet", "--detach", "FETCH_HEAD"], check=True)
actual = subprocess.check_output(["git", "-C", str(directory), "rev-parse", "HEAD"], text=True).strip()
if actual != lock["revision"]:
    raise SystemExit("Games producer revision mismatch (including local override)")
if subprocess.check_output(["git", "-C", str(directory), "status", "--porcelain"]):
    raise SystemExit("Games producer checkout is dirty")
output = args.output.resolve()
if output.exists():
    raise SystemExit("Choose a fresh games dependency output directory")
subprocess.run(["python3", str(directory / "producer/resolve_dependencies.py"), "--games", args.games,
                "--output", str(output), "--revision", actual], check=True)
selection = json.loads((output / "selection.json").read_text())
if selection["requires_graphics"] and args.graphics != "enabled":
    raise SystemExit("Selected games require GRAPHICS=enabled")
(output / "source").mkdir()
with subprocess.Popen(["git", "-C", str(directory), "archive", "HEAD"], stdout=subprocess.PIPE) as archive:
    subprocess.run(["tar", "-xf", "-", "-C", str(output / "source")], stdin=archive.stdout, check=True)
    archive.stdout.close()
    if archive.wait():
        raise SystemExit("Games dependency source archive failed")
print(output)
