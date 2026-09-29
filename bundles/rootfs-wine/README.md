# Debian with Box64 and Wine64

The `wine` CI profile publishes a complete AArch64 Debian rootfs with a native
Box64 build and Debian's amd64 Wine64 packages. It targets 64-bit Windows
applications. Use this bundle instead of `bundles/rootfs`, not on top of it.

The release job writes `bundle.toml` here only after validating and uploading
both the binary and corresponding-source archives. See the repository README
for the Scarlet bring-up commands and current limitations.
