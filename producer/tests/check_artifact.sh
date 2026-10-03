#!/usr/bin/env bash
set -euo pipefail

archive="${1:?usage: check_artifact.sh <rootfs.tar.zst>}"
archive_dir="$(cd "$(dirname "$archive")" && pwd)"
archive_name="$(basename "$archive")"
command -v zstd >/dev/null
command -v docker >/dev/null
(
    cd "$archive_dir"
    sha256sum --check SHA256SUMS
)
listing="$(mktemp)"
image=''
cleanup() {
    rm -f "$listing"
    if [[ -n "$image" ]]; then docker image rm "$image" >/dev/null; fi
}
trap cleanup EXIT
tar --zstd -tf "$archive" > "$listing"
for path in ./usr/bin/bash ./usr/bin/apt-get ./usr/bin/dpkg \
    ./usr/lib/aarch64-linux-gnu/libc.so.6 ./var/lib/dpkg/status \
    ./usr/share/scarlet/dpkg-packages.tsv ./usr/share/scarlet/source-packages.tsv \
    ./usr/share/scarlet/producer-LICENSE ./usr/share/scarlet/ATTRIBUTION.md; do
    grep -Fxq "$path" "$listing"
done
# Import the archive itself, so the smoke test includes export/packaging effects.
image="$(zstd -dc "$archive" | docker import --platform linux/arm64 -)"
docker run --rm --network none --platform linux/arm64 "$image" \
    /bin/bash /usr/share/scarlet/smoke_rootfs.sh
if grep -Fxq ./usr/share/scarlet/smoke_wine.sh "$listing"; then
    docker run --rm --network none --platform linux/arm64 "$image" \
        /bin/bash /usr/share/scarlet/smoke_wine.sh
fi
if grep -Fxq ./usr/share/scarlet/smoke_graphics.sh "$listing"; then
    docker run --rm --network none --platform linux/arm64 "$image" \
        /bin/sh /usr/share/scarlet/smoke_graphics.sh
    source_archive="$archive_dir/${archive_name/rootfs-/sources-}"
    test -s "$source_archive"
    tar --zstd -tf "$source_archive" > "$listing"
    for path in ./upstream/linux-graphics/manifest.json \
        ./upstream/linux-graphics/producer/producer/sources.lock.json \
        ./upstream/linux-graphics/upstream/mesa/docs/license.rst \
        ./upstream/linux-graphics/upstream/sdl/LICENSE.txt \
        ./upstream/linux-graphics/cargo-vendor-sgfx-config.toml \
        ./upstream/linux-graphics/cargo-vendor-sws-config.toml; do
        grep -Fxq "$path" "$listing"
    done
fi
echo "Artifact OK: $archive_name"
