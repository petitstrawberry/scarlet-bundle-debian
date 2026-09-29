Experimental Debian trixie AArch64 rootfs with Box64 v0.4.4 and Debian's amd64 Wine64 packages.

The `wine` and `wineserver` launchers invoke Box64 explicitly. This initial profile targets 64-bit Windows applications; it does not include Wine32, Box86, a WoW64 build, DXVK, Mono or Gecko. GUI, audio and GPU integration on Scarlet remain unverified.

CI builds Box64 from pinned source on a native AArch64 Linux runner. After importing the exported rootfs, it checks the Debian package inventory, licenses, Box64/Wine versions and `wine cmd /c echo SCARLET_WINE64_OK`. This validates the bundle on Linux, not Scarlet's Linux ABI implementation.

Known limitation in v0.2.0: the console smoke passes and exits normally, but multimedia initialization still reports unresolved OpenCL, OpenMP and Zstd wrapper symbols. Media playback and full native-library coverage remain open work. On Scarlet, invoke the shell launcher as `abi-run linux-aarch64 /bin/sh /usr/local/bin/wine --version`; `abi-run` directly opens an ELF image.

Both architectures' exact Debian source packages, copyright notices, Box64's build input sources and configuration, and the producer scripts accompany the binaries in `sources-aarch64-wine-*.tar.zst`. Box64's bundled third-party prebuilt libraries are excluded. Dependencies come from signed Debian repositories and retain their own licenses. `SHA256SUMS` covers both archives and package inventories. See ATTRIBUTION.md in the source archive.
