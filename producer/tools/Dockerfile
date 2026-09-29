# The digest pins the official multi-architecture Debian base image.
FROM debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a AS packages
COPY producer/tools/debian.sources /etc/apt/sources.list.d/debian.sources
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash ca-certificates coreutils curl file libgcc-s1 libstdc++6 zstd && \
    mkdir -p /usr/share/scarlet && \
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
COPY producer /sources/producer
COPY .github /sources/.github
COPY .dockerignore /sources/.dockerignore
COPY LICENSE ATTRIBUTION.md README.md /sources/

FROM packages AS rootfs
ARG VERSION
ARG REVISION
RUN printf 'Debian trixie (base)\nVersion: %s\nProducer revision: %s\n' "$VERSION" "$REVISION" > /usr/share/scarlet/build.txt && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/log/* && \
    mkdir -p /dev /proc /sys /tmp /root /home /shared /scarlet && \
    chmod 1777 /tmp && chmod 700 /root
