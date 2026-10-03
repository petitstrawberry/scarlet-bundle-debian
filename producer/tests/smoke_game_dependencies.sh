#!/bin/sh
set -eu
test -s /usr/share/scarlet/linux-games.json
test -s /usr/share/scarlet/linux-games-runtime-packages.txt
while IFS= read -r package; do
    test "$(dpkg-query -W -f='${db:Status-Status}' "$package")" = installed
done < /usr/share/scarlet/linux-games-runtime-packages.txt
echo SCARLET_GAME_DEPENDENCIES_OK
# The rootfs supplies dependencies only; the selected app bundle supplies games.
