#!/usr/bin/env python3
"""Resolve a clean, revision-pinned graphics producer build context."""
import json
import os
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
lock = json.loads((root / "producer/graphics.lock.json").read_text())
if lock["schema"] != 1 or not re.fullmatch(r"[0-9a-f]{40}", lock["revision"]):
    raise SystemExit("Invalid graphics producer lock")
override = os.environ.get("GRAPHICS_SOURCE")
directory = pathlib.Path(override).resolve() if override else pathlib.Path(sys.argv[1]).resolve() / ("graphics-" + lock["revision"])
if not override and not (directory / ".git").exists():
    directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "--quiet", str(directory)], check=True, stdout=sys.stderr)
    subprocess.run(["git", "-C", str(directory), "remote", "add", "origin", lock["url"]], check=True, stdout=sys.stderr)
    subprocess.run(["git", "-C", str(directory), "fetch", "--depth", "1", "origin", lock["revision"]], check=True, stdout=sys.stderr)
    subprocess.run(["git", "-C", str(directory), "checkout", "--quiet", "--detach", "FETCH_HEAD"], check=True, stdout=sys.stderr)
actual = subprocess.check_output(["git", "-C", str(directory), "rev-parse", "HEAD"], text=True).strip()
if actual != lock["revision"]:
    raise SystemExit("Graphics producer revision mismatch (including local override)")
if subprocess.check_output(["git", "-C", str(directory), "status", "--porcelain"]):
    raise SystemExit("Graphics producer checkout is dirty")
print(directory)
