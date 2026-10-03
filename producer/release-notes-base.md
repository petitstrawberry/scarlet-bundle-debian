Experimental Debian 13 (trixie) AArch64 userspace bundle for Scarlet.

Includes glibc, bash, coreutils, apt/dpkg, CA certificates, curl, GCC/C++ runtimes and a preinstalled Debian Mozc server with the OSS conversion dictionary. The server is rebuilt from the installed Debian source version with a Linux-server-only root-startup patch for Scarlet; the distribution binary is retained through dpkg-divert. The rootfs uses Scarlet's existing tar-zst archive-layer format and `/systems/linux-aarch64` layout.

Mozc validation includes root startup and `nihonn` → `日本` conversion over native IPC on Linux. The exact patched input tree, patch and build provenance are included in the accompanying source archive. This does not establish native Scarlet IME compatibility.

Validation: built on GitHub Actions' native AArch64 Linux runner; the exported archive passes command execution, dpkg inventory and copyright-notice checks. This release does not establish Scarlet runtime compatibility; Box64, Wine and package installation on Scarlet remain unverified.

The rootfs retains each Debian package's copyright notices and common license texts. The accompanying `sources-aarch64-base-*.tar.zst` asset contains the matching Debian source packages, including upstream archives, Debian patches/build rules, package notices and producer scripts. Sources for every installed package are selected by exact source version and checked against the `.dsc` SHA-256 entries before publication.

`SHA256SUMS` covers the binary/source archives and their package inventories. `bundle.toml` pins the rootfs archive for use by Scarlet. Debian package licenses apply individually; the repository's MIT license covers only its original producer code and documentation. See [ATTRIBUTION.md](https://github.com/petitstrawberry/scarlet-bundle-debian/blob/main/ATTRIBUTION.md).
