# Third-party packages and corresponding source

The repository's MIT license covers its original producer scripts and
documentation only. The Debian binaries and source packages in the release
archives retain their individual licenses and copyright notices. The rootfs
as a whole is not relicensed under MIT.

Only Debian trixie `main`, `trixie-updates/main` and
`trixie-security/main` are enabled. Every rootfs retains:

- `/usr/share/doc/<package>/copyright`, including directories shared through
  Debian's package symlinks;
- `/usr/share/common-licenses/`, containing the license texts referenced by
  those copyright files;
- `/var/lib/dpkg/status` and `/usr/share/scarlet/dpkg-packages.tsv`, recording
  the exact installed binary package, version, architecture, source package
  and source version;
- `/usr/share/scarlet/source-packages.tsv`, recording unique source versions.

Each binary release is accompanied on the same GitHub Release by
`sources-aarch64-<profile>-<version>.tar.zst`. It contains the exact Debian source
packages for every installed package: `.dsc` descriptors, upstream source
archives, Debian patches and packaging/build rules. Native Debian packages
have their single source archive. Source versions are selected from dpkg
metadata, not inferred from binary filenames (which may have binNMU suffixes).
The build verifies all SHA-256 entries in each `.dsc` and fails if any source
version or package copyright notice cannot be obtained.

The source archive also contains copies of the package copyright notices,
common license texts, and this repository's producer scripts/configuration.
Debian package binaries are unmodified; rootfs-specific changes concern the
resolver link, hostname/hosts, directories, package metadata, and smoke script.
Shared libraries remain ordinary replaceable files in the rootfs.

## Box64/Wine profile

The `wine` profile includes Debian's amd64 Wine64 and its dependencies alongside
the ARM64 native libraries. The inventory and source collection cover packages
of both architectures. Wine's LGPL and other per-file terms are retained in
`/usr/share/doc/libwine/copyright`, common license texts and the matching Debian
source package. Wine, Mono, Gecko or Windows system DLLs are not downloaded from
third-party binary distribution sites.

Box64 v0.4.4 is built from upstream commit
`2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a`. Its MIT license, build provenance,
CMake configuration, tool versions and exact build input sources are installed
in `/usr/share/doc/box64/` and copied to `upstream/box64/` in the source archive.
The build source archive preserves the per-file notices for bundled source
components such as khash and musl math routines; those components retain their
own notices and terms. `producer/tools/build_box64.sh` records the upstream
archive's SHA-256, selected source paths and build options.

Debian's `/usr/lib/wine/wineserver` shell selector is preserved as
`wineserver.debian` using `dpkg-divert`. Its original path links to our Box64
launcher, so Wine's internal server startup also goes through the emulator.
The Wine ELF/PE binaries remain unmodified.

Upstream's prebuilt `x64lib`, `x86lib`, Android libraries and executable tests
are excluded from both exported archives. `NO_LIB_INSTALL` is enabled, and only
the newly compiled Box64 executable is installed. All additional runtime
libraries are Debian packages with matching sources collected as above.

Publish binary and corresponding-source archives together; retain both for
as long as the binary release is offered. A link to an upstream repository
alone is not used as the source-distribution mechanism here. Release
`SHA256SUMS` covers both archives and the package inventories.

References:

- [Debian copyright-file policy](https://www.debian.org/doc/debian-policy/ch-docs.html#copyright-information)
- [Debian license information](https://www.debian.org/legal/licenses/)
- [Debian source package format](https://www.debian.org/doc/debian-policy/ch-source.html)
- [Official Debian container artifact sources](https://github.com/debuerreotype/docker-debian-artifacts)

Debian is a registered trademark of Software in the Public Interest, Inc.
This is an independent userspace bundle for Scarlet, not an official Debian
or Debian Project release.
