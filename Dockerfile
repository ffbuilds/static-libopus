# syntax=docker/dockerfile:1

# bump: opus /OPUS_VERSION=([\d.]+)/ https://github.com/xiph/opus.git|^1
# bump: opus after ./hashupdate Dockerfile OPUS $LATEST
# bump: opus link "Release notes" https://github.com/xiph/opus/releases/tag/v$LATEST
# bump: opus link "Source diff $CURRENT..$LATEST" https://github.com/xiph/opus/compare/v$CURRENT..v$LATEST
ARG OPUS_VERSION=1.3.1
ARG OPUS_URL="https://archive.mozilla.org/pub/opus/opus-$OPUS_VERSION.tar.gz"
ARG OPUS_SHA256=65b58e1e25b2a114157014736a3d9dfeaad8d41be1c8179866f144a2fb44ff9d

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG OPUS_URL
ARG OPUS_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O opus.tar.gz "$OPUS_URL" && \
  echo "$OPUS_SHA256  opus.tar.gz" | sha256sum --status -c - && \
  mkdir opus && \
  tar xf opus.tar.gz -C opus --strip-components=1 && \
  rm opus.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/opus/ /tmp/opus/
WORKDIR /tmp/opus
RUN \
  apk add --no-cache --virtual build \
    build-base pkgconf && \
  ./configure --disable-shared --enable-static --disable-extra-programs --disable-doc && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path opus && \
  ar -t /usr/local/lib/libopus.a && \
  readelf -h /usr/local/lib/libopus.a && \
  # Cleanup
  apk del build

FROM scratch
ARG OPUS_VERSION
COPY --from=build /usr/local/lib/pkgconfig/opus.pc /usr/local/lib/pkgconfig/opus.pc
COPY --from=build /usr/local/lib/libopus.a /usr/local/lib/libopus.a
COPY --from=build /usr/local/include/opus/ /usr/local/include/opus/
