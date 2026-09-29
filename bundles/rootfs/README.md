# Debian rootfs bundle

The release job commits the generated `bundle.toml` here with the release URL
and actual rootfs SHA-256, after uploading both the binary and corresponding
source archives to a draft. It then publishes the release. Build-only runs
generate a candidate manifest in the workflow artifact instead.
