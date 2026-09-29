#!/usr/bin/env bash
set -euo pipefail

# Invoked only by the native AArch64 Linux CI build stage.
revision=2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a # v0.4.4
sha256=ce844041092de3f44316bd1c033a3cc10024e5f798c1a8e8a58f046c6d967981
url="https://codeload.github.com/ptitSeb/box64/tar.gz/${revision}"
curl --fail --location --retry 3 "$url" -o /tmp/box64.tar.gz
printf '%s  /tmp/box64.tar.gz\n' "$sha256" | sha256sum --check
mkdir -p /build/box64 /out/usr/local/bin /out/usr/share/doc/box64

# Extract just the build sources and their notices. Upstream also ships third-
# party prebuilt libraries and executable tests; none of those are redistributed.
tar -xf /tmp/box64.tar.gz --strip-components=1 -C /build/box64 \
    "box64-${revision}/CMakeLists.txt" "box64-${revision}/cmake_uninstall.cmake.in" \
    "box64-${revision}/rebuild_wrappers.py" "box64-${revision}/rebuild_wrappers_32.py" \
    "box64-${revision}/runTest.cmake" "box64-${revision}/tests/CMakeLists.txt" \
    "box64-${revision}/src" "box64-${revision}/external" "box64-${revision}/system" \
    "box64-${revision}/tools" "box64-${revision}/configurator" \
    "box64-${revision}/docs/gen" "box64-${revision}/gdbjit" \
    "box64-${revision}/LICENSE" "box64-${revision}/README.md" \
    "box64-${revision}/debian/copyright"

# Upstream unconditionally copies a prebuilt x86 bash during configure, even
# when only the box64 target is built. Remove just its three packaging rules.
python3 - <<'PY'
from pathlib import Path
p = Path('/build/box64/CMakeLists.txt')
lines = p.read_text().splitlines(keepends=True)
removed = [line for line in lines if '${CMAKE_SOURCE_DIR}/tests/box64-bash' in line]
assert len(removed) == 3, 'Upstream bash packaging changed; review source selection'
p.write_text(''.join(line for line in lines if line not in removed))
PY

# Keep the exact input tree before CMake generates files. Including this in the
# binary archive also retains per-file notices (khash, musl math, etc.).
tar -C /build --sort=name --mtime=@0 --numeric-owner \
    -I 'gzip -n' -cf /out/usr/share/doc/box64/build-source.tar.gz box64
cp /build/box64/LICENSE /out/usr/share/doc/box64/copyright
printf 'Box64 v0.4.4\nCommit: %s\nURL: %s\nUpstream SHA256: %s\nSources: build-source.tar.gz (build inputs only; bundled binaries excluded)\nPackaging patch: remove the three prebuilt box64-bash CMake rules\n' \
    "$revision" "$url" "$sha256" > /out/usr/share/doc/box64/build.txt
cmake -S /build/box64 -B /build/box64-build \
    -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DNOGIT=ON -DNO_LIB_INSTALL=ON -DNO_CONF_INSTALL=ON -DBOX32=OFF -DSAVE_MEM=ON
cmake --build /build/box64-build --target box64 --parallel "$(nproc)"
install -m755 /build/box64-build/box64 /out/usr/local/bin/box64
cp /build/box64-build/CMakeCache.txt /out/usr/share/doc/box64/
dpkg-query -W > /out/usr/share/doc/box64/build-packages.tsv
