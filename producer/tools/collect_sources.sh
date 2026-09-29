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
        test "$(sed -n 's/^Source: //p' "$descriptor")" = "$source"
        test "$(sed -n 's/^Version: //p' "$descriptor")" = "$version"
        awk '/^Checksums-Sha256:/ {checksums=1; next} checksums && /^ / {print $1 "  " $3; next} checksums {exit}' \
            "$descriptor" > SHA256SUMS
        test -s SHA256SUMS
        sha256sum --check SHA256SUMS
    )
done < /sources/source-packages.tsv
