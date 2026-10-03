#!/usr/bin/env bash
set -euo pipefail

# Test the installed server as root, just like Scarlet's native launcher.
test "$(id -u)" -eq 0
test -x /usr/lib/mozc/mozc_server
test -x /usr/lib/mozc/mozc_server.debian
test -s /usr/share/doc/scarlet-mozc-server/mozc-allow-root-server.patch
statuses="$(dpkg-query -W -f='${db:Status-Status}\n' mozc-server mozc-data)"
test "$statuses" = $'installed\ninstalled'
test "$(dpkg-divert --truename /usr/lib/mozc/mozc_server)" = /usr/lib/mozc/mozc_server.debian
profile="$(mktemp -d /tmp/scarlet-mozc.XXXXXXXX)"
pid=''
cleanup() {
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    rm -rf "$profile"
}
trap cleanup EXIT
mkdir -p "$profile/.config/mozc"
env HOME="$profile" XDG_CONFIG_HOME="$profile/.config" \
    /usr/lib/mozc/mozc_server --logtostderr > "$profile/server.log" 2>&1 &
pid=$!
ready=false
for _ in {1..100}; do
    if ! kill -0 "$pid" 2>/dev/null; then
        cat "$profile/server.log" >&2
        echo 'Mozc exited before IPC became ready' >&2
        exit 1
    fi
    if [[ -s "$profile/.config/mozc/.session.ipc" ]] && \
        grep -q 'tmp/\.mozc\..*\.session' /proc/net/unix; then
        ready=true
        break
    fi
    sleep 0.1
done
if [[ "$ready" != true ]]; then
    cat "$profile/server.log" >&2
    echo 'Mozc IPC startup timed out' >&2
    exit 1
fi
echo SCARLET_MOZC_ROOT_OK
