#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
VERSION="${VERSION:?VERSION is required}"
BUILD_REVISION="${BUILD_REVISION:?BUILD_REVISION is required}"
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'VERSION must look like v0.1.0' >&2; exit 2
fi
test "$(git rev-parse HEAD)" = "$BUILD_REVISION"
rootfs="rootfs-aarch64-base-${VERSION}.tar.zst"
sources="sources-aarch64-base-${VERSION}.tar.zst"
for filename in "$rootfs" "$sources" dpkg-packages.tsv source-packages.tsv SHA256SUMS bundle.toml; do
    test -s "producer/artifacts/$filename"
done
(cd producer/artifacts && sha256sum --check SHA256SUMS)
python3 - <<'PY'
import hashlib
import os
from pathlib import Path
import tomllib

directory = Path('producer/artifacts')
version = os.environ['VERSION']
name = f'rootfs-aarch64-base-{version}.tar.zst'
with (directory / 'bundle.toml').open('rb') as file:
    manifest = tomllib.load(file)
with (directory / name).open('rb') as file:
    digest = hashlib.file_digest(file, 'sha256').hexdigest()
assert manifest == {'layers': [{
    'kind': 'archive',
    'url': f'https://github.com/petitstrawberry/scarlet-bundle-debian/releases/download/{version}/{name}',
    'sha256': f'sha256:{digest}',
    'format': 'tar-zst',
    'strip_components': 1,
    'to': '/systems/linux-aarch64',
}]}, 'Release manifest does not match the verified archive'
PY

# No clobber/update path: an existing version must never acquire different bytes.
if gh release view "$VERSION" >/dev/null 2>&1; then
    echo "Release $VERSION already exists; use a new version" >&2; exit 1
fi
# A draft keeps binaries private until the matching sources are fully uploaded.
gh release create "$VERSION" --draft --prerelease --target "$BUILD_REVISION" \
    --title "Debian trixie AArch64 ${VERSION}" --notes-file producer/release-notes.md \
    "producer/artifacts/$rootfs" "producer/artifacts/$sources" \
    producer/artifacts/dpkg-packages.tsv producer/artifacts/source-packages.tsv \
    producer/artifacts/SHA256SUMS producer/artifacts/bundle.toml
gh release view "$VERSION" --json assets > producer/artifacts/release-assets.json
python3 - <<'PY'
import json
from pathlib import Path

directory = Path('producer/artifacts')
assets = json.loads((directory / 'release-assets.json').read_text())['assets']
expected = {path.name: path.stat().st_size for path in directory.iterdir()
            if path.name != 'release-assets.json'}
assert {item['name']: item['size'] for item in assets} == expected, 'Incomplete release upload'
PY
cp producer/artifacts/bundle.toml bundles/rootfs/bundle.toml
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add bundles/rootfs/bundle.toml
git commit -m "Pin Debian rootfs ${VERSION}"
git push origin HEAD:main
gh release edit "$VERSION" --draft=false
