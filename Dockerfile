FROM nvidia/cuda:11.4.2-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# FFmpegコンパイルに必要なものを導入
RUN apt-get update -qq && apt-get -y install \
      tzdata \
      autoconf \
      automake \
      build-essential \
      cmake \
      git-core \
      libass-dev \
      libfreetype6-dev \
      libgnutls28-dev \
      libssl-dev \
      libtool \
      libvorbis-dev \
      libsnappy-dev \
      meson \
      ninja-build \
      pkg-config \
      texinfo \
      wget \
      yasm \
      zlib1g-dev

# Let's Encryptルート証明書が期限切れ対策
RUN apt-get -y install --reinstall ca-certificates

# 作業ディレクトリ作成
RUN mkdir -p ~/ffmpeg_sources ~/bin

# NASM インストール
RUN cd ~/ffmpeg_sources && \
    wget https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.bz2 && \
    tar xjvf nasm-2.15.05.tar.bz2 && \
    cd nasm-2.15.05 && \
    ./autogen.sh && \
    PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
    make && \
    make install

# libx264 インストール
RUN cd ~/ffmpeg_sources && \
    git -C x264 pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
    cd x264 && \
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --enable-static --enable-pic && \
    PATH="$HOME/bin:$PATH" make && \
    make install

# libx265 インストール
RUN apt-get install libnuma-dev && \
    cd ~/ffmpeg_sources && \
    git -C x265_git pull 2> /dev/null || git clone https://bitbucket.org/multicoreware/x265_git && \
    cd x265_git/build/linux && \
    PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off ../../source && \
    PATH="$HOME/bin:$PATH" make && \
    make install

# libvpx インストール
RUN cd ~/ffmpeg_sources && \
    git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
    cd libvpx && \
    PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && \
    PATH="$HOME/bin:$PATH" make && \
    make install

# libfdk-aac インストール
RUN cd ~/ffmpeg_sources && \
    git -C fdk-aac pull 2> /dev/null || git clone --depth 1 https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && \
    autoreconf -fiv && \
    ./configure --prefix="$HOME/ffmpeg_build" --disable-shared && \
    make && \
    make install

# libmp3lame インストール
RUN cd ~/ffmpeg_sources && \
    wget -O lame-3.100.tar.gz https://netix.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz && \
    tar xzvf lame-3.100.tar.gz && \
    cd lame-3.100 && \
    PATH="$HOME/bin:$PATH" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" --disable-shared --enable-nasm && \
    PATH="$HOME/bin:$PATH" make && \
    make install

# libopus インストール
RUN cd ~/ffmpeg_sources && \
    git -C opus pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git && \
    cd opus && \
    ./autogen.sh && \
    ./configure --prefix="$HOME/ffmpeg_build" --disable-shared && \
    make && \
    make install

# libaom インストール
RUN cd ~/ffmpeg_sources && \
    git -C aom pull 2> /dev/null || git clone --depth 1 https://aomedia.googlesource.com/aom && \
    mkdir -p aom_build && \
    cd aom_build && \
    PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off -DENABLE_NASM=on ../aom && \
    PATH="$HOME/bin:$PATH" make && \
    make install

# libsvtav1 インストール
RUN cd ~/ffmpeg_sources && \
    git -C SVT-AV1 pull 2> /dev/null || git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    mkdir -p SVT-AV1/build && \
    cd SVT-AV1/build && \
    PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DCMAKE_BUILD_TYPE=Release -DBUILD_DEC=OFF -DBUILD_SHARED_LIBS=OFF .. && \
    PATH="$HOME/bin:$PATH" make && \
    make install

# NVIDIA codec API インストール
RUN cd ~/ffmpeg_sources && \
    git -C nv-codec-headers pull 2> /dev/null || git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers && \
    cd nv-codec-headers && \
    make && \
    make install PREFIX="$HOME/ffmpeg_build"

# FFmpeg インストール
RUN cd ~/ffmpeg_sources && \
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
    tar xjvf ffmpeg-snapshot.tar.bz2 && \
    cd ffmpeg && \
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
      --prefix="$HOME/ffmpeg_build" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$HOME/ffmpeg_build/include" \
      --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
      --enable-cuda-nvcc \
      --nvccflags="-gencode arch=compute_52,code=sm_52 -O2" \
      --enable-cuvid \
      --enable-nvenc \
      --enable-libnpp \
      --extra-cflags="-I/usr/local/cuda-11.4/include" \
      --extra-ldflags="-L/usr/local/cuda-11.4/lib64" \
      --extra-libs="-lpthread -lm" \
      --ld="g++" \
      --bindir="$HOME/bin" \
      --enable-openssl \
      --enable-gpl \
      --enable-libaom \
      --enable-libass \
      --enable-libfdk-aac \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libsvtav1 \
      --enable-libvorbis \
      --enable-libsnappy \
      --enable-libvpx \
      --enable-libx264 \
      --enable-libx265 \
      --enable-static \
      --enable-nonfree && \
    PATH="$HOME/bin:$PATH" make && \
    make install && \
    hash -r

ENV PATH $PATH:/root/bin
