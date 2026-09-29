# scarlet-bundle-debian

Debian GNU/Linux userspace producer for
[Scarlet](https://github.com/petitstrawberry/Scarlet), using the same repository
layout and archive-layer format as `scarlet-bundle-alpine`.
The first target is a minimal AArch64 glibc rootfs based on Debian 13 (trixie).
It includes bash, coreutils, apt/dpkg, CA certificates, curl, and the GCC/C++
runtimes as a starting point for glibc applications such as Box64.

## CI builds

Pushes validate the scripts. Run the **Build Debian rootfs** workflow manually
with `version=v0.1.0` to build on GitHub's native `ubuntu-24.04-arm` runner:

```sh
gh workflow run build.yml -f version=v0.1.0
```

CI builds the rootfs, obtains matching source packages, checks every package's
copyright notice, verifies source checksums, and executes the exported rootfs
in a Linux container. Download the `debian-base-aarch64` workflow artifact.
No local build is needed for this workflow.

For a separate Linux/Docker build environment, the equivalent producer entry
point is `ARCH=aarch64 PROFILE=base VERSION=v0.1.0 bash producer/tools/build_rootfs.sh`.
Only the base profile and AArch64 are currently supported.

## Artifacts and release

`producer/artifacts/` contains:

- `rootfs-aarch64-base-v0.1.0.tar.zst`: the Debian Linux view;
- `sources-aarch64-base-v0.1.0.tar.zst`: corresponding Debian sources, notices,
  and the producer scripts;
- `dpkg-packages.tsv` and `source-packages.tsv`: exact version inventories;
- `SHA256SUMS`: hashes for both archives and both inventories;
- `bundle.toml`: candidate hash-pinned release manifest.

The base container image is digest-pinned in `producer/tools/Dockerfile`.
Packages are updated from signed Debian repositories at build time; this is
not a bit-for-bit reproducible snapshot build. Published release bytes are
pinned by SHA-256 and accompanied by their exact corresponding sources.

Publish a tested binary archive and its matching source archive together on
the same versioned GitHub Release, along with the inventories and checksums.
Then copy the generated manifest to `bundles/rootfs/bundle.toml`. Do not
replace the bytes behind an already-pinned release.
See [ATTRIBUTION.md](ATTRIBUTION.md) for third-party licenses and source layout.

## Scarlet bring-up

The archive has `./`-prefixed paths, uses `tar-zst` with
`strip_components = 1`, and is installed at `/systems/linux-aarch64`.
It preserves Debian's merged `/usr` symlinks, package ownership and modes.
`/etc/resolv.conf` links to `/scarlet/etc/resolv.conf`, matching the Alpine view.
Scarlet supplies the native bindings for `/dev`, `/tmp`, `/home`, `/root` and
`/shared`.

Use the bundle in an alternative image configuration. Its filesystem occupies
the same Linux view as Alpine, so select one distro's rootfs for that view.
This repository does not change Scarlet's default `full-alpine` image.

Initial probes after integration:

```sh
abi-run linux-aarch64 /bin/true
abi-run linux-aarch64 /bin/bash /usr/share/scarlet/smoke_rootfs.sh
abi-run linux-aarch64 /usr/bin/apt-get --version
```

Linux-container smoke success does not establish Scarlet compatibility.
In particular, apt package installation, maintainer scripts, Box64, Wine,
GUI/audio/GPU integration and systemd boot are not validated here.
This first bundle has no Mozc or browser overlay.

## Repository layout

- `producer/tools/`: Docker build, source collection and rootfs packaging;
- `producer/tests/`: artifact and Linux execution checks;
- `producer/artifacts/`, `producer/cache/`: ignored build outputs;
- `bundles/rootfs/`: Scarlet's release-pinned archive layer;
- `.github/workflows/build.yml`: validation and manually triggered CI build.
