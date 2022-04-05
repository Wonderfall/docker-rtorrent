# Build-time variables
ARG ALPINE_VERSION=edge
ARG RTORRENT_VERSION=0.9.8-r15
ARG UNRAR_VERSION=6.1.6
ARG FINDUTILS_VERSION=4.9.0


# Build rTorrent
FROM alpine:${ALPINE_VERSION} as build-rtorrent

ARG RTORRENT_VERSION

RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
 && apk --no-cache add \
    bash \
    bazel@testing \
    build-base \
    coreutils \
    gcompat \
    git \
    linux-headers \
    python2@testing \
    python3 \
 && git clone --depth 1 --branch v${RTORRENT_VERSION} https://github.com/jesec/rtorrent/ && cd rtorrent \
 && sed -i 's/architecture = \"all\"/architecture = \"amd64\"/' BUILD.bazel \
 && bazel build rtorrent-deb --features=fully_static_link --verbose_failures


# Build unrar
FROM alpine:${ALPINE_VERSION} as build-unrar

ARG UNRAR_VERSION

RUN apk --no-cache add make g++ \
 && wget -q -O /tmp/unrar.tar.gz https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz \
 && cd /tmp && tar xzf unrar.tar.gz && cd unrar \
 && sed -i -e 's/LDFLAGS=-pthread/LDFLAGS=-static -pthread/g' makefile \
 && make


# Build find
FROM alpine:${ALPINE_VERSION} as build-find

ARG FINDUTILS_VERSION

RUN apk --no-cache add build-base \
 && wget -q -O /tmp/find.tar.xz https://ftp.gnu.org/gnu/findutils/findutils-${FINDUTILS_VERSION}.tar.xz \
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
