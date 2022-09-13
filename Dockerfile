# Base emsdk image with environment variables.
FROM emscripten/emsdk:3.1.18 AS emsdk-base
ARG EXTRA_CFLAGS
ARG EXTRA_LDFLAGS
ARG FFMPEG_MT
ENV INSTALL_DIR=/src/build
ENV FFMPEG_VERSION=n5.1
ENV CFLAGS="$CFLAGS $EXTRA_CFLAGS"
ENV LDFLAGS="$LDFLAGS $CFLAGS $EXTRA_LDFLAGS"
ENV EM_PKG_CONFIG_PATH=$EM_PKG_CONFIG_PATH:$INSTALL_DIR/lib/pkgconfig:/emsdk/upstream/emscripten/system/lib/pkgconfig
ENV PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$EM_PKG_CONFIG_PATH
ENV FFMPEG_MT=$FFMPEG_MT

# Build x264
FROM emsdk-base AS x264-builder
RUN git clone \
      --branch stable \
      --depth 1 \
      https://github.com/ffmpegwasm/x264 \
      /src
COPY build/x264.sh /src/build.sh
RUN bash /src/build.sh

# Base ffmpeg image with dependencies and source code populated.
FROM emsdk-base AS ffmpeg-base
RUN apt-get update && \
      apt-get install -y pkg-config
RUN embuilder build sdl2
RUN git clone \
      --branch $FFMPEG_VERSION \
      --depth 1 \
      https://github.com/FFmpeg/FFmpeg \
      /src
COPY --from=x264-builder $INSTALL_DIR $INSTALL_DIR

# Build ffmpeg
FROM ffmpeg-base AS ffmpeg-builder
COPY build/ffmpeg.sh /src/build.sh
RUN bash /src/build.sh

# Build ffmpeg-core.wasm
FROM ffmpeg-builder AS ffmpeg-wasm-builder
COPY src/bind /src/wasm/bind
COPY src/fftools /src/wasm/fftools
RUN mkdir -p /src/dist
COPY build/ffmpeg-wasm.sh build.sh
# FIXME: find a way to export both entry points in one command.
RUN bash /src/build.sh -o dist/ffmpeg-core.cjs
RUN bash /src/build.sh -sEXPORT_ES6 -o dist/ffmpeg-core.js

# Export ffmpeg-core.wasm to dist/, use `docker buildx build -o . .` to get assets
FROM scratch AS exportor
COPY --from=ffmpeg-wasm-builder /src/dist /dist
