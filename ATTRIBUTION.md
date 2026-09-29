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
`sources-aarch64-base-<version>.tar.zst`. It contains the exact Debian source
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
