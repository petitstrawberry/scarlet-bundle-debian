#!/usr/bin/env bash
set -euo pipefail

# Rebuild only the server from the exact source of the installed Debian package.
# Runtime dependencies and the unused renderer remain distribution packages.
test "$(dpkg --print-architecture)" = arm64
source_version="$(dpkg-query -W -f='${source:Version}' mozc-server)"
mkdir -p /build/mozc /out/runtime/usr/lib/mozc \
    /out/runtime/usr/share/doc/scarlet-mozc-server /out/sources
cd /build/mozc
apt-get --download-only --only-source source "mozc=${source_version}"
shopt -s nullglob
descriptors=(*.dsc)
test "${#descriptors[@]}" -eq 1
descriptor="${descriptors[0]}"
test "$(awk '/^Source: / {print $2; exit}' "$descriptor")" = mozc
test "$(awk '/^Version: / {print $2; exit}' "$descriptor")" = "$source_version"
awk '/^Checksums-Sha256:/ {checksums=1; next} checksums && /^ / {print $1 "  " $3; next} checksums {exit}' \
    "$descriptor" > SHA256SUMS
test -s SHA256SUMS
sha256sum --check SHA256SUMS
dpkg-source -x "$descriptor" source
patch --batch --fuzz=0 -d source -p1 < /tmp/mozc-allow-root-server.patch

# Archive the exact patched input tree before generating build outputs. The
# normal source collector also exports the matching original Debian .dsc/files.
tar --sort=name --mtime=@0 --numeric-owner -I 'xz -T2' \
    -cf /out/sources/build-source.tar.xz source
(cd /out/sources && sha256sum build-source.tar.xz > SHA256SUMS)
doc=/out/runtime/usr/share/doc/scarlet-mozc-server
cp /tmp/mozc-allow-root-server.patch "$doc/"
cp /tmp/build_mozc_server.sh "$doc/build_mozc_server.sh"
cp source/debian/copyright "$doc/copyright"
cp SHA256SUMS "$doc/debian-source-SHA256SUMS"
dpkg-query -W > "$doc/build-packages.tsv"
printf 'Debian source: mozc=%s\nPatch: mozc-allow-root-server.patch\nTarget: server/server.gyp:mozc_server\nGYP_DEFINES: use_libprotobuf=1 use_libabseil=1\nConfiguration: Release, --noqt, Debian dpkg-buildflags, PYTHONPATH=src\nSource archive: upstream/scarlet-mozc-server/build-source.tar.xz\n' \
    "$source_version" > "$doc/build.txt"

cd source/src
export PYTHONPATH="$PWD"
export CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
CPPFLAGS="$(dpkg-buildflags --get CPPFLAGS)"
CFLAGS="$(dpkg-buildflags --get CFLAGS) ${CPPFLAGS}"
CXXFLAGS="$(dpkg-buildflags --get CXXFLAGS) ${CPPFLAGS}"
LDFLAGS="$(dpkg-buildflags --get LDFLAGS) -Wl,--as-needed"
GYP_DEFINES='use_libprotobuf=1 use_libabseil=1' \
    python3 build_mozc.py gyp --gypdir=/usr/bin --target_platform=Linux --noqt
ninja -C out_linux/Release -j "${MOZC_BUILD_JOBS:-4}" mozc_server
install -m755 out_linux/Release/mozc_server /out/runtime/usr/lib/mozc/mozc_server
strip /out/runtime/usr/lib/mozc/mozc_server
python3 /tmp/mozc_conversion.py /out/runtime/usr/lib/mozc/mozc_server
cp -a "$doc/." /out/sources/
cp /tmp/mozc_conversion.py /out/sources/
