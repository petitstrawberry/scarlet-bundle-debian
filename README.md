# scarlet-bundle-debian

Debian GNU/Linux userspace producer for
[Scarlet](https://github.com/petitstrawberry/Scarlet), using the same repository
layout and archive-layer format as `scarlet-bundle-alpine`.
Both profiles use an AArch64 glibc rootfs based on Debian 13 (trixie):

- `base`: bash, coreutils, apt/dpkg, CA certificates, curl, GCC/C++ runtimes,
  and a preinstalled Mozc server with its OSS conversion dictionary;
- `wine`: the base plus Box64 v0.4.4, Debian's amd64 Wine64 and dependencies.
  This initial profile supports 64-bit Windows programs; Wine32, Box86 and
  a WoW64 build are not included.

Both profiles include the shared Linux graphics overlay by default. Its
independent producer lives in `petitstrawberry/scarlet-linux-graphics`; the exact
commit is pinned in `producer/graphics.lock.json`. The Debian producer fetches
that clean checkout as a BuildKit additional context, installs its build/runtime
dependencies from the same signed Debian repositories, builds SGFX's Vulkan ICD,
Linux SWS binding, Mesa Zink and corrected SDL2, and copies the runtime into the
rootfs. Native SWS and Wayland bridge remain in Scarlet's desktop bundle.
OpenTTD and its base set remain separate application assets.

Set `GRAPHICS=disabled` (or disable the manual workflow's `graphics` input) for
the original console-only rootfs. Graphics builds require Docker with BuildKit
additional-context support, Git and Python 3. For a local producer checkout,
`GRAPHICS_SOURCE=/path/to/scarlet-linux-graphics` is accepted only when it is clean
and matches the locked commit; it cannot silently substitute different sources.
No graphics repo checkout is needed when graphics are disabled.

## Optional Linux game dependencies

Game applications are separate source-build bundles in
`petitstrawberry/scarlet-bundle-linux-games`, starting with `bundles/openttd`.
Set `GAMES=openttd` when building the Debian rootfs used with that bundle;
`GAMES=none` is the default and does not fetch a games checkout. Later catalog
entries can be selected with comma-separated names. Unknown names are rejected.
OpenTTD requires `GRAPHICS=enabled` for the common Zink/SGFX/SDL runtime.

```sh
ARCH=aarch64 PROFILE=base GRAPHICS=enabled GAMES=openttd VERSION=v0.3.0 \
  bash producer/tools/build_rootfs.sh
```

`producer/games.lock.json` fixes the dependency producer revision. A local
`GAMES_SOURCE` override must be clean and match that exact commit. The producer
resolves the selected games' `runtime-packages.txt` union and installs it with
APT before collecting the package inventory and exact Debian source packages.
This includes OpenTTD's `libpng16-16t64`; no manual library copying is required.
The rootfs records selection/pin/package provenance in
`/usr/share/scarlet/linux-games.json` and checks installed dpkg status.

The rootfs contains shared dependencies, not game binaries or base sets.
`bundles/openttd` separately installs the application, OpenGFX, Linux launcher
and desktop entry. Use the same pinned games producer revision for both sides.
Its application overlay does not replace Debian-owned shared libraries.
The rootfs source archive retains the dependency producer's exact Git tree and
selection/package manifests under `upstream/linux-games-dependencies/`.
Application and OpenGFX corresponding sources accompany the game bundle output.
The manual workflow accepts the same `games` selection.

For a non-publishing build, use a fresh artifact version and output directory:

```sh
ARCH=aarch64 PROFILE=base VERSION=v0.3.0 bash producer/tools/build_rootfs.sh
```

The source archive includes `upstream/linux-graphics/`: exact fork trees, both
Rust lockfiles, vendored Rust dependencies, licenses, producer recipes and build
provenance. The source-file checksum list is adjacent to that directory.
Runtime provenance is `/usr/share/doc/scarlet-linux-graphics/manifest.json`.
The normal package inventory/source collection includes graphics dependencies.
Archive validation runs `smoke_graphics.sh` from the exported rootfs and checks
the corresponding-source entries. These Linux checks validate loading and
dependency closure, not Scarlet GPU execution.

With a matching native bridge already running on the Scarlet desktop:

```sh
export XDG_RUNTIME_DIR=/tmp
export WAYLAND_DISPLAY=wayland-graphics
abi-run linux-aarch64 /bin/sh /usr/local/bin/scarlet-gl /path/to/linux-application
```

The launcher selects private `/opt/sgfx-zink` and `/opt/sgfx-sdl` libraries for
that process. Debian-owned SDL/Mesa files and desktop services are not replaced.
The integrated Debian base runtime was checked on 2026-10-03 in the dedicated
Scarlet AArch64 QEMU/VirGL snapshot. The fresh-context error gate, pixel readback
and Wayland swap passed; OpenTTD displayed a map and accepted pan/zoom and close
input with a Zink/SGFX renderer. The 117 transferred runtime files matched the
rootfs archive. Required Debian GLVND/Wayland EGL libraries were copied into the
guest's private validation directory. This does not establish boot of the full
new rootfs, physical hardware support or complete Vulkan conformance. OpenTTD's
fullscreen viewport issue remains unresolved; use windowed mode.

## CI builds

Pushes and pull requests validate the scripts. Producer/workflow changes on
`main` also build and check the graphics-enabled `base` rootfs with
`GAMES=openttd`, using version `v0.3.<workflow run number>`. After validation,
Actions publishes binaries and corresponding sources together, then updates
the archive download URL and SHA in `bundles/rootfs/bundle.toml`. Bundle-pin
and documentation-only changes do not trigger another run.

Run the **Build Debian rootfs** workflow manually
with a new version to build on GitHub's native `ubuntu-24.04-arm` runner:

```sh
gh workflow run build.yml -f version=v0.2.0 -f profile=wine
```

CI builds the rootfs, obtains matching source packages, checks every package's
copyright notice, verifies source checksums, and executes the exported rootfs
in a Linux container. By default, a successful manual run on `main` publishes
an experimental GitHub prerelease with binaries and corresponding sources,
then provides the hash-pinned bundle at `bundles/rootfs/bundle.toml` (`base`)
or `bundles/rootfs-wine/bundle.toml` (`wine`) via an automated commit.
The version must be new across both profiles; existing releases are never replaced.
Set `publish=false` for a build-only run and download the
`debian-<profile>-aarch64` workflow artifact. No local build is needed.

Updating Scarlet's Debian repository revision alone does not add a newly built
runtime: the selected `bundles/rootfs/bundle.toml` must point at a release
containing it. The old v0.1.0/v0.2.0 archives do not contain `scarlet-gl`.
After Actions updates that manifest, select its commit in Scarlet's
`bundles/full-debian/bundle.toml` and rebuild the image. Repository URLs remain
unchanged; only the archive URL/SHA and the consuming repository commit change.

For a separate Linux/Docker build environment, the equivalent producer entry
point is `ARCH=aarch64 PROFILE=base VERSION=v0.1.0 bash producer/tools/build_rootfs.sh`.
Set `PROFILE=wine` for Box64/Wine. Only AArch64 is currently supported.

## Artifacts and release

`producer/artifacts/` contains:

- `rootfs-aarch64-base-v0.1.0.tar.zst`: the Debian Linux view;
- `sources-aarch64-base-v0.1.0.tar.zst`: corresponding Debian sources, notices,
  and the producer scripts;
- `dpkg-packages.tsv` and `source-packages.tsv`: exact version inventories;
- `SHA256SUMS`: hashes for both archives and both inventories;
- `bundle.toml`: candidate hash-pinned release manifest.

The `wine` profile uses `wine` in place of `base` in archive names. Box64 is
built from a commit and SHA-256 pinned source archive with generic ARM64 dynarec
and the memory-saving jump table enabled. Its bundled prebuilt libraries are
excluded; Debian supplies the
native ARM64 and emulated AMD64 dependencies. Wine itself is an unmodified
Debian package. The build does not install a binfmt_misc handler.

The base container image is digest-pinned in `producer/tools/Dockerfile`.
Packages are updated from signed Debian repositories at build time; this is
not a bit-for-bit reproducible snapshot build. Published release bytes are
pinned by SHA-256 and accompanied by their exact corresponding sources.

The release job first uploads all assets to a draft and checks upload sizes.
It commits the verified manifest and only then makes the release public,
ensuring binaries and corresponding sources become available together.
If publication fails after draft creation, the draft is left for inspection;
there is no automatic overwrite or retry of an existing version.
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
In particular, apt installation/maintainer scripts and systemd boot are not
validated on Scarlet. Mozc is included in both rootfs profiles; no browser
overlay is included.

### Preinstalled Japanese conversion

Both `base` and `wine` install Debian's `mozc-server` and `mozc-data`. The server
at `/usr/lib/mozc/mozc_server` is rebuilt from the installed package's exact
Debian source version with one Scarlet patch: the Linux conversion server may
start as UID/EUID 0, which Scarlet's Linux ABI currently reports. The client and
renderer privilege checks remain unchanged. Dependencies use Debian's glibc
libraries; no Buildroot/musl runtime or separate dictionary overlay is needed.
The OSS conversion dictionary is compiled into the server; `mozc-data` is
primarily the icon assets.

The original binary is retained as `/usr/lib/mozc/mozc_server.debian` through
`dpkg-divert`, protecting the patched executable during package upgrades.
Rebuild the bundle to update the patched server. Build provenance and the patch
are under `/usr/share/doc/scarlet-mozc-server/`, and the matching patched input
sources accompany the release as described in [ATTRIBUTION.md](ATTRIBUTION.md).

The producer tests root startup and `nihonn` → `日本` conversion over Mozc IPC.
The exported-rootfs smoke check also verifies the installed server starts as
root and exposes its IPC socket. Scarlet's desktop already supplies the native
`mozc-server` launcher and `scarlet-mozc` SWS service; their integration with this
glibc server still needs a Scarlet runtime test.

### Box64 and Wine bring-up

Select `bundles/rootfs-wine` instead of `bundles/rootfs` in Scarlet's
`full-debian` bundle. This is a complete rootfs, not an overlay on `base`.
The profile keeps Debian's amd64 binaries at `/usr/lib/wine/` and supplies
explicit Box64 launchers at `/usr/local/bin/wine` and `wineserver`.
The internal `/usr/lib/wine/wineserver` selector is redirected to that launcher
using `dpkg-divert`, preserving Debian's original as `wineserver.debian`.
Box64 handles Wine's subsequent x86-64 exec calls; no kernel x86-64 loader
or binfmt_misc registration is required.
The launcher keeps OpenSSL 3 in amd64 emulation because Debian's FFmpeg uses
BIO callback getters absent from Box64 v0.4.4's native OpenSSL wrapper.

Run the probes in order on Scarlet. `abi-run` directly opens an ELF image,
so invoke the Wine shell launchers through `/bin/sh`:

```sh
abi-run linux-aarch64 /usr/local/bin/box64 --version
abi-run linux-aarch64 /bin/sh /usr/local/bin/wine --version
abi-run linux-aarch64 /bin/sh /usr/local/bin/wineserver --version
abi-run linux-aarch64 /usr/bin/env WINEDLLOVERRIDES=mscoree,mshtml= /bin/sh /usr/local/bin/wine cmd /c ver
```

The last command initializes `~/.wine` on first use and exercises Windows
loading, Wine's server, processes, threads and IPC. Mono/Gecko downloads are
disabled for this probe. An ordinary PE64 executable can then be invoked with
`abi-run linux-aarch64 /bin/sh /usr/local/bin/wine /shared/hello.exe`.
For interpreter-only diagnosis, put `/usr/bin/env BOX64_DYNAREC=0` before
`/bin/sh /usr/local/bin/wine`; the default uses dynarec.

CI checks the version probes and `wine cmd /c echo SCARLET_WINE64_OK` on the
exported rootfs with networking disabled and a temporary Wine prefix.
GUI/audio/GPU integration and Wine's runtime on Scarlet remain unverified.
The v0.2.0 Linux console smoke passes, but multimedia initialization still
reports unresolved OpenCL, OpenMP and Zstd wrapper symbols. This release is a
console bring-up baseline; media playback and full native-library coverage
remain open work.

## Repository layout

- `producer/tools/`: Docker build, source collection and rootfs packaging;
- `producer/tests/`: artifact and Linux execution checks;
- `producer/artifacts/`, `producer/cache/`: ignored build outputs;
- `bundles/rootfs/`, `bundles/rootfs-wine/`: release-pinned archive layers;
- `.github/workflows/build.yml`: validation, manually triggered CI build and
  automatic release publication.
