#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="${ARCH:-aarch64}"
PROFILE="${PROFILE:-base}"
GRAPHICS="${GRAPHICS:-enabled}"
GAMES="${GAMES:-none}"
VERSION="${VERSION:-v0.1.0}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${REPO_ROOT}/producer/artifacts}"
CACHE_DIR="${CACHE_DIR:-${REPO_ROOT}/producer/cache}"
case "$ARCH" in aarch64) docker_platform=linux/arm64 ;; *) echo "Unsupported ARCH=$ARCH" >&2; exit 2 ;; esac
case "$PROFILE" in base|wine) ;; *) echo "Unsupported PROFILE=$PROFILE; choose base or wine" >&2; exit 2 ;; esac
case "$GRAPHICS" in enabled|disabled) ;; *) echo 'GRAPHICS must be enabled or disabled' >&2; exit 2 ;; esac
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'VERSION must look like v0.1.0' >&2; exit 2
fi
command -v docker >/dev/null
mkdir -p "$CACHE_DIR" "$ARTIFACT_DIR"
ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd)"
stage="$(mktemp -d "${CACHE_DIR}/rootfs-${ARCH}-${PROFILE}.XXXXXXXX")"
rootfs_name="rootfs-${ARCH}-${PROFILE}-${VERSION}.tar.zst"
sources_name="sources-${ARCH}-${PROFILE}-${VERSION}.tar.zst"
for filename in "$rootfs_name" "$sources_name" SHA256SUMS bundle.toml; do
    if [[ -e "${ARTIFACT_DIR}/${filename}" ]]; then
        echo "Refusing to overwrite ${ARTIFACT_DIR}/${filename}" >&2; exit 2
    fi
done
container=''
cleanup() {
    if [[ -n "$container" ]]; then docker rm "$container" >/dev/null; fi
}
trap cleanup EXIT
revision="$(git -C "$REPO_ROOT" rev-parse HEAD)"
graphics_arguments=(--build-arg "GRAPHICS=$GRAPHICS")
if [[ "$GRAPHICS" == enabled ]]; then
    graphics_source="$(python3 "$REPO_ROOT/producer/tools/prepare_graphics.py" "$CACHE_DIR")"
    graphics_revision="$(git -C "$graphics_source" rev-parse HEAD)"
    graphics_input_key="$(shasum -a 256 "$graphics_source/producer/sources.lock.json" | cut -d ' ' -f 1)"
    graphics_arguments+=(--build-context "graphics=$graphics_source" \
        --build-arg "GRAPHICS_REVISION=$graphics_revision" --build-arg "GRAPHICS_CACHE_ID=$graphics_input_key" \
        --build-arg "BUILD_JOBS=${BUILD_JOBS:-4}")
fi

# The context contains package lists/provenance only, never game runtime files.
game_arguments=(--build-arg "GAMES=$GAMES" --build-arg GAME_DEPENDENCIES=disabled)
if [[ "$GAMES" != none ]]; then
    game_context="$(python3 "$REPO_ROOT/producer/tools/prepare_games.py" "$CACHE_DIR" "$stage/games-context" \
        --games "$GAMES" --graphics "$GRAPHICS")"
    game_arguments=(--build-arg "GAMES=$GAMES" --build-arg GAME_DEPENDENCIES=enabled --build-context "games=$game_context")
fi

# Fail early on Wine startup before collecting and compressing sources. The
# exported archive is checked separately, including ownership/symlink effects.
docker build --platform "$docker_platform" --target rootfs --build-arg PROFILE="$PROFILE" \
    "${graphics_arguments[@]}" \
    "${game_arguments[@]}" \
    --build-arg VERSION="$VERSION" --build-arg REVISION="$revision" \
    --iidfile "$stage/rootfs.id" -f "$REPO_ROOT/producer/tools/Dockerfile" "$REPO_ROOT"
rootfs_image="$(cat "$stage/rootfs.id")"
if [[ "$PROFILE" == wine ]]; then
    docker run --rm --network none --platform "$docker_platform" "$rootfs_image" \
        /bin/bash /usr/share/scarlet/smoke_wine.sh
fi
if [[ "$GRAPHICS" == enabled ]]; then
    docker run --rm --network none --platform "$docker_platform" "$rootfs_image" \
        /bin/sh /usr/share/scarlet/smoke_graphics.sh
fi
# Verify dpkg ownership/status before collecting matching Debian source packages.
if [[ "$GAMES" != none ]]; then
    docker run --rm --network none --platform "$docker_platform" "$rootfs_image" \
        /bin/sh /usr/share/scarlet/smoke_game_dependencies.sh
fi
# Both targets reuse the same binary-installation layer and APT indexes.
# Sources are mandatory, including for non-release CI builds.
docker build --platform "$docker_platform" --target sources --build-arg PROFILE="$PROFILE" \
    "${graphics_arguments[@]}" \
    "${game_arguments[@]}" \
    --iidfile "$stage/sources.id" -f "$REPO_ROOT/producer/tools/Dockerfile" "$REPO_ROOT"
source_image="$(cat "$stage/sources.id")"

docker run --rm --network none --platform "$docker_platform" \
    --mount "type=bind,src=${ARTIFACT_DIR},dst=/artifacts" \
    -e SOURCES_NAME="$sources_name" "$source_image" sh -eu -c '
        cp /sources/dpkg-packages.tsv /sources/source-packages.tsv /artifacts/
        tar -C /sources --sort=name --mtime=@0 --numeric-owner \
            -I "zstd -T2 -9" -cf "/artifacts/${SOURCES_NAME}" .
    '
container="$(docker create --platform "$docker_platform" "$rootfs_image")"
# Extract inside a container to preserve Linux ownership, modes and symlinks.
docker export "$container" | docker run --rm -i --network none --platform "$docker_platform" \
    --mount "type=bind,src=${ARTIFACT_DIR},dst=/artifacts" \
    -e ROOTFS_NAME="$rootfs_name" "$rootfs_image" sh -eu -c '
        mkdir /rootfs
        tar -C /rootfs -xf -
        rm -f /rootfs/.dockerenv /rootfs/etc/resolv.conf /rootfs/etc/hostname /rootfs/etc/hosts
        ln -s /scarlet/etc/resolv.conf /rootfs/etc/resolv.conf
        printf "scarlet\n" > /rootfs/etc/hostname
        printf "127.0.0.1 localhost scarlet\n::1 localhost ip6-localhost\n" > /rootfs/etc/hosts
        tar -C /rootfs --sort=name --mtime=@0 --numeric-owner \
            -I "zstd -T2 -9" -cf "/artifacts/${ROOTFS_NAME}" .
    '
docker run --rm --network none --platform "$docker_platform" \
    --mount "type=bind,src=${ARTIFACT_DIR},dst=/artifacts" \
    -e ROOTFS_NAME="$rootfs_name" -e SOURCES_NAME="$sources_name" \
    -e VERSION="$VERSION" "$rootfs_image" sh -eu -c '
        cd /artifacts
        sha256sum "$ROOTFS_NAME" "$SOURCES_NAME" dpkg-packages.tsv source-packages.tsv > SHA256SUMS
        hash=$(sha256sum "$ROOTFS_NAME")
        hash=${hash%% *}
        printf "# Experimental AArch64 Debian Linux view for Scarlet.\n\n[[layers]]\nkind = \"archive\"\nurl = \"https://github.com/petitstrawberry/scarlet-bundle-debian/releases/download/%s/%s\"\nsha256 = \"sha256:%s\"\nformat = \"tar-zst\"\nstrip_components = 1\nto = \"/systems/linux-aarch64\"\n" \
            "$VERSION" "$ROOTFS_NAME" "$hash" > bundle.toml
    '
echo "Artifacts: $ARTIFACT_DIR"
