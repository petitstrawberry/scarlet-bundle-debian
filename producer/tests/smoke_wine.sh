#!/usr/bin/env bash
set -euo pipefail

# Run on Linux CI after importing the actual release archive. On Scarlet, start
# with the individual version probes before attempting prefix initialization.
test "$(dpkg-query -W -f='${Architecture}' wine64:amd64)" = amd64
file /usr/local/bin/box64 | grep -q 'ARM aarch64'
file /usr/lib/wine/wine64 | grep -q 'x86-64'
test -s /usr/share/doc/box64/copyright
test -s /usr/share/doc/box64/build-source.tar.gz
test ! -e /usr/lib/box64-x86_64-linux-gnu
/usr/local/bin/box64 --version
/usr/local/bin/wine --version
/usr/local/bin/wineserver --version

export WINEPREFIX
WINEPREFIX="$(mktemp -d /tmp/scarlet-wine.XXXXXXXX)"
export WINEDLLOVERRIDES='mscoree,mshtml='
export WINEDEBUG=-all
cleanup() {
    timeout 10 /usr/local/bin/wineserver -k || true
    rm -rf "$WINEPREFIX"
}
trap cleanup EXIT
# Exercise Windows loading and Wine's server subprocess, not just --version.
timeout 120 /usr/local/bin/wine cmd /d /c 'echo SCARLET_WINE64_OK' > "$WINEPREFIX/result.txt"
tr -d '\r' < "$WINEPREFIX/result.txt" | grep -Fx SCARLET_WINE64_OK
timeout 30 /usr/local/bin/wineserver -w
echo SCARLET_DEBIAN_WINE_OK
