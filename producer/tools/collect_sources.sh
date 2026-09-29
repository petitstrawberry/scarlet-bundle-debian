#!/usr/bin/env bash
set -euo pipefail

# Use the same signed APT indexes as the binary installation. Every installed
# source version must be available; missing sources fail the build.
mkdir -p /sources/packages /sources/copyright /sources/common-licenses
cp /usr/share/scarlet/*packages.tsv /sources/
cp -a /usr/share/common-licenses/. /sources/common-licenses/
while IFS=$'\t' read -r package _version _arch _source _source_version; do
    doc_package="${package%%:*}"
    copyright="/usr/share/doc/${doc_package}/copyright"
    test -s "$copyright" || { echo "Missing copyright: $package" >&2; exit 1; }
    cp -L "$copyright" "/sources/copyright/${package}.txt"
done < /sources/dpkg-packages.tsv

while IFS=$'\t' read -r source version; do
    directory="/sources/packages/${source}/${version}"
    mkdir -p "$directory"
    (
        cd "$directory"
        apt-get --download-only --only-source source "${source}=${version}"
        shopt -s nullglob
        descriptors=(*.dsc)
        test "${#descriptors[@]}" -eq 1
        descriptor="${descriptors[0]}"
        # A clearsigned .dsc may also have a "Version: GnuPG ..." header in
        # its signature block. Read the first control field, not every match.
        actual_source="$(awk '/^Source: / {print $2; exit}' "$descriptor")"
        actual_version="$(awk '/^Version: / {print $2; exit}' "$descriptor")"
        if [[ "$actual_source" != "$source" || "$actual_version" != "$version" ]]; then
            echo "Source mismatch: wanted $source=$version, got $actual_source=$actual_version" >&2
            exit 1
        fi
        awk '/^Checksums-Sha256:/ {checksums=1; next} checksums && /^ / {print $1 "  " $3; next} checksums {exit}' \
            "$descriptor" > SHA256SUMS
        test -s SHA256SUMS
        sha256sum --check SHA256SUMS
    )
done < /sources/source-packages.tsv
