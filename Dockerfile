# Build-time variables
ARG ALPINE_VERSION=edge
ARG RTORRENT_VERSION=0.9.8-r16
ARG UNRAR_VERSION=6.2.1
ARG FINDUTILS_VERSION=4.9.0

# Checksums (must be changed for each version version)
ARG UNRAR_CHECKSUM=5cc8f7ded262d27c29d01e7a119d2fd23edda427711820454f2eb667044a8900
ARG FINDUTILS_CHECKSUM=a2bfb8c09d436770edc59f50fa483e785b161a3b7b9d547573cb08065fd462fe

# GPG keys
ARG RTORRENT_GPG=A102C2F15053B4F7


# Build rTorrent
FROM alpine:${ALPINE_VERSION} as build-rtorrent

ARG RTORRENT_VERSION
ARG RTORRENT_GPG

RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
 && apk --no-cache add \
    bash \
    bazel@testing \
    build-base \
    coreutils \
    gcompat \
    git \
    linux-headers \
    pythonispython3 \
    python3 \
    gnupg \
 && git clone --depth 1 --branch v${RTORRENT_VERSION} https://github.com/jesec/rtorrent/ && cd rtorrent \
 && gpg --recv-keys ${RTORRENT_GPG} \
 && TAG=$(git describe --tags) \
 && git verify-tag ${TAG} || { git verify-tag --raw "${TAG}" 2>&1 | grep EXPKEYSIG; } \
 && sed -i 's/architecture = \"all\"/architecture = \"amd64\"/' BUILD.bazel \
 && bazel build rtorrent --features=fully_static_link --verbose_failures --copt="-Wno-error=deprecated-declarations"


# Build unrar
FROM alpine:${ALPINE_VERSION} as build-unrar

ARG UNRAR_VERSION
ARG UNRAR_CHECKSUM

RUN apk --no-cache add make g++ \
 && wget -q -O /tmp/unrar.tar.gz https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz \
 && CHECKSUM_STATE=$(echo -n $(echo "${UNRAR_CHECKSUM}  /tmp/unrar.tar.gz" | sha256sum -c) | tail -c 2) \
 && if [ "${CHECKSUM_STATE}" != "OK" ]; then echo "Error: checksum does not match" && exit 1; fi \
 && cd /tmp && tar xzf unrar.tar.gz && cd unrar \
 && sed -i -e 's/LDFLAGS=-pthread/LDFLAGS=-static -pthread/g' makefile \
 && make


# Build find
FROM alpine:${ALPINE_VERSION} as build-find

ARG FINDUTILS_VERSION
ARG FINDUTILS_CHECKSUM

RUN apk --no-cache add build-base \
 && wget -q -O /tmp/find.tar.xz https://ftp.gnu.org/gnu/findutils/findutils-${FINDUTILS_VERSION}.tar.xz \
 && CHECKSUM_STATE=$(echo -n $(echo "${FINDUTILS_CHECKSUM}  /tmp/find.tar.xz" | sha256sum -c) | tail -c 2) \
 && if [ "${CHECKSUM_STATE}" != "OK" ]; then echo "Error: checksum does not match" && exit 1; fi \
 && cd /tmp && mkdir find && tar xf find.tar.xz -C find --strip-components 1 && cd find \
 && ./configure LDFLAGS="-static" \
 && make


# Prepare rtunrar
FROM alpine:edge as get-rtunrar

COPY rtunrar.sh .

RUN chmod +x rtunrar.sh


# Build final image
FROM gcr.io/distroless/static as final

COPY --from=build-rtorrent /rtorrent/bazel-bin/rtorrent /usr/local/bin/
COPY --from=build-unrar /tmp/unrar/unrar /usr/local/bin/
COPY --from=build-find /tmp/find/find/find /usr/local/bin/
COPY --from=get-rtunrar /rtunrar.sh /usr/local/bin/rtunrar
COPY --from=gcr.io/distroless/static:debug /busybox/sh /bin/sh

ENV HOME=/config

USER 1000:1000

ENTRYPOINT ["rtorrent"]
