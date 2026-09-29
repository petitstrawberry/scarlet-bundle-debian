#!/usr/bin/env bash
set -euo pipefail

# Runs inside the exported rootfs on Linux. Also usable later via Scarlet's
# abi-run, but CI does not establish Scarlet kernel compatibility.
test "$(dpkg --print-architecture)" = arm64
test -x /lib/ld-linux-aarch64.so.1
getconf GNU_LIBC_VERSION
/bin/true
/bin/bash -c 'test "$((6 * 7))" = 42'
apt-get --version
dpkg --audit > /tmp/dpkg-audit.txt
test ! -s /tmp/dpkg-audit.txt
curl --version
test -s /etc/ssl/certs/ca-certificates.crt
test -s /usr/share/common-licenses/GPL-3
test -s /usr/share/common-licenses/LGPL-2.1
dpkg-query -W -f='${db:Status-Status}\t${binary:Package}\t${Version}\t${Architecture}\t${source:Package}\t${source:Version}\n' | \
    awk -F '\t' '$1 == "installed" {print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6}' | \
    LC_ALL=C sort > /tmp/dpkg-packages.tsv
cmp /tmp/dpkg-packages.tsv /usr/share/scarlet/dpkg-packages.tsv
while IFS=$'\t' read -r package _version _arch _source _source_version; do
    test -s "/usr/share/doc/${package%%:*}/copyright"
done < /usr/share/scarlet/dpkg-packages.tsv
echo SCARLET_DEBIAN_ROOTFS_OK
