# Debian rootfs bundle

After a tested release is published, its generated `bundle.toml` is committed
here with the release URL and actual rootfs SHA-256. CI generates the candidate
manifest alongside the rootfs and corresponding-source archives; it is not a
usable remote bundle until those release assets are published.
