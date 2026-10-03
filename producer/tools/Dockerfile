ARG PROFILE=base
ARG GRAPHICS=enabled

# The digest pins the official multi-architecture Debian base image.
FROM debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a AS base-packages
COPY producer/tools/debian.sources /etc/apt/sources.list.d/debian.sources
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash ca-certificates coreutils curl file libgcc-s1 libstdc++6 zstd

FROM base-packages AS box64-build
RUN apt-get install -y --no-install-recommends build-essential cmake python3
COPY producer/tools/build_box64.sh /tmp/build_box64.sh
RUN bash /tmp/build_box64.sh

FROM base-packages AS wine-packages
# Keep Debian metadata intact for both architectures so source collection covers
# Wine and every native/emulated dependency, including matching binNMU versions.
RUN dpkg --add-architecture amd64 && apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        wine64:amd64 libgcc-s1:amd64 libstdc++6:amd64 fonts-liberation \
        libfreetype6:arm64 libfontconfig1:arm64 libgnutls30t64:arm64 \
        libx11-6:arm64 libxext6:arm64 libxrender1:arm64 libxrandr2:arm64 \
        libxi6:arm64 libxcursor1:arm64 libxfixes3:arm64 libxkbcommon0:arm64 \
        libasound2t64:arm64 libpulse0:arm64 libudev1:arm64 libvulkan1:arm64 \
        libgl1:arm64 libwayland-client0:arm64 libwayland-egl1:arm64 \
        libxkbregistry0:arm64 libgstreamer1.0-0:arm64 \
        libgstreamer-plugins-base1.0-0:arm64 libsdl2-2.0-0:arm64 \
        libusb-1.0-0:arm64 libcups2t64:arm64 libcairo2:arm64 \
        libcairo-gobject2:arm64 libgdk-pixbuf-2.0-0:arm64 \
        libpango-1.0-0:arm64 libpangocairo-1.0-0:arm64 libpangoft2-1.0-0:arm64 \
        libharfbuzz0b:arm64 liblcms2-2:arm64 libgomp1:arm64 libnuma1:arm64 \
        libssh-4:arm64 libva-drm2:arm64 libva-x11-2:arm64 libvdpau1:arm64 \
        libvpx9:arm64 libvorbisfile3:arm64 ocl-icd-libopencl1:arm64
COPY --from=box64-build /out/ /
COPY --chmod=755 producer/wrappers/wine producer/wrappers/wineserver /usr/local/bin/
# Wine tries the adjacent wineserver before WINESERVER/PATH. Debian's selector
# is a native shell script, so its exec of wineserver64 would bypass Box64.
# Preserve it with a dpkg diversion, including across later package upgrades.
RUN dpkg-divert --local --rename --add \
        --divert /usr/lib/wine/wineserver.debian /usr/lib/wine/wineserver && \
    ln -s /usr/local/bin/wineserver /usr/lib/wine/wineserver
COPY producer/tests/smoke_wine.sh /usr/share/scarlet/smoke_wine.sh

# The independent producer receives this Debian build environment. Its sources,
# pins and recipes are supplied as a verified additional build context.
FROM base-packages AS graphics-build
COPY --from=graphics /producer/ /graphics-producer/producer/
COPY --from=graphics /runtime/ /graphics-producer/runtime/
COPY --from=graphics /tests/ /graphics-producer/tests/
COPY --from=graphics /LICENSE /ATTRIBUTION.md /README.md /graphics-producer/
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    $(cat /graphics-producer/producer/build-packages.txt)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --profile minimal --default-toolchain nightly-2025-12-31
ENV PATH="/root/.cargo/bin:${PATH}"
ARG GRAPHICS_REVISION
ARG GRAPHICS_CACHE_ID=local
ARG BUILD_JOBS=4
RUN --mount=type=cache,id=scarlet-linux-graphics-registry,target=/root/.cargo/registry \
    --mount=type=cache,id=scarlet-linux-graphics-git,target=/root/.cargo/git \
    --mount=type=cache,id=scarlet-linux-graphics-work-${GRAPHICS_CACHE_ID},target=/graphics-work,sharing=locked \
    GRAPHICS_REVISION="$GRAPHICS_REVISION" BUILD_JOBS="$BUILD_JOBS" bash /graphics-producer/producer/build.sh /out

FROM ${PROFILE}-packages AS packages-disabled
FROM packages-disabled AS packages-enabled
COPY --from=graphics /producer/runtime-packages.txt /tmp/graphics-runtime-packages.txt
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    $(cat /tmp/graphics-runtime-packages.txt) && rm /tmp/graphics-runtime-packages.txt
COPY --from=graphics-build /out/runtime/ /
RUN sh /usr/share/scarlet/smoke_graphics.sh

FROM scratch AS disabled-sources
FROM scratch AS enabled-sources
COPY --from=graphics-build /out/sources/ /linux-graphics/
COPY --from=graphics-build /out/source-files.sha256 /linux-graphics-source-files.sha256
FROM ${GRAPHICS}-sources AS graphics-sources

FROM packages-${GRAPHICS} AS packages
RUN mkdir -p /usr/share/scarlet && \
    dpkg-query -W -f='${db:Status-Status}\t${binary:Package}\t${Version}\t${Architecture}\t${source:Package}\t${source:Version}\n' | \
        awk -F '\t' '$1 == "installed" {print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6}' | \
        LC_ALL=C sort > /usr/share/scarlet/dpkg-packages.tsv && \
    cut -f4,5 /usr/share/scarlet/dpkg-packages.tsv | LC_ALL=C sort -u > /usr/share/scarlet/source-packages.tsv
COPY LICENSE /usr/share/scarlet/producer-LICENSE
COPY ATTRIBUTION.md /usr/share/scarlet/ATTRIBUTION.md
COPY producer/tests/smoke_rootfs.sh /usr/share/scarlet/smoke_rootfs.sh

FROM packages AS sources
COPY producer/tools/collect_sources.sh /tmp/collect_sources.sh
RUN bash /tmp/collect_sources.sh
RUN if [ -d /usr/share/doc/box64 ]; then \
        mkdir -p /sources/upstream && cp -a /usr/share/doc/box64 /sources/upstream/; \
    fi
COPY --from=graphics-sources / /sources/upstream/
COPY producer /sources/producer
COPY .github /sources/.github
COPY .dockerignore /sources/.dockerignore
COPY LICENSE ATTRIBUTION.md README.md /sources/

FROM packages AS rootfs
ARG VERSION
ARG REVISION
ARG PROFILE
ARG GRAPHICS
RUN printf 'Debian trixie (%s)\nVersion: %s\nProducer revision: %s\nGraphics: %s\n' "$PROFILE" "$VERSION" "$REVISION" "$GRAPHICS" > /usr/share/scarlet/build.txt && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/log/* && \
    mkdir -p /dev /proc /sys /tmp /root /home /shared /scarlet && \
    chmod 1777 /tmp && chmod 700 /root
