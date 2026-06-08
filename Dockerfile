# FROM ubuntu:26.04 AS builder
#
# ARG GCC_VERSION 12
# ARG DEBIAN_FRONTEND=noninteractive
#
# WORKDIR /proj
#
# # See https://ghdl.github.io/ghdl/development/building/GCC.html#build-gcc
# RUN apt-get update && apt-get install -y \
#     build-essential \
#     gnat \
#     git \
#     wget \
#     flex \
#     bison \
#     libgnat-14-dev \
#     libgmp-dev \
#     libmpfr-dev \
#     libmpc-dev \
#     zlib1g-dev \
#     tcl \
#     pv \
#     texinfo \
#     && rm -rf /var/lib/apt/lists/*
#
# WORKDIR /ghdl-build
# RUN wget -qO- https://mirrors.ocf.berkeley.edu/gnu/gcc/gcc-12.5.0/gcc-12.5.0.tar.gz \
#   | pv -s 110M \
#   | tar -xz
#
# RUN git clone --depth 1 https://github.com/ghdl/ghdl
#
# WORKDIR /ghdl-build/ghdl
# RUN mkdir build && cd build \
#     && ../configure --with-gcc=/ghdl-build/gcc-12.5.0 --prefix=/usr/local \
#     && make copy-sources
#
# WORKDIR /ghdl-build
# RUN mkdir gcc-objs
# WORKDIR /ghdl-build/gcc-objs
# RUN /ghdl-build/gcc-12.5.0/configure \
#     --prefix=/usr/local        \
#     --enable-languages=c,vhdl  \
#     --disable-bootstrap        \
#     --disable-lto              \
#     --disable-multilib         \
#     --disable-libssp           \
#     --disable-libgomp          \
#     --disable-libquadmath      \
#     --enable-default-pie       \
#     --enable-static            \
#     LDFLAGS="$LDFLAGS -static"
#
# WORKDIR /ghdl-build/gcc-objs
# RUN make -j$(nproc) && make install
#
# WORKDIR /ghdl-build/ghdl/build
# RUN make ghdllib && make install
#
# WORKDIR /
# RUN git clone --recursive "https://github.com/OSVVM/OsvvmLibraries.git"
#
# WORKDIR /OsvvmLibraries/osvvm
# COPY build_osvvm.sh .
# RUN chmod +x build_osvvm.sh && ./build_osvvm.sh
# RUN mkdir -p $HOME/VHDL_LIBS/GHDL-7.0.0/osvvm/v08
# RUN cp work/* $HOME/VHDL_LIBS/GHDL-7.0.0/osvvm/v08
#
# WORKDIR /Hardware303
# COPY nco .
# RUN make
#
# FROM scratch AS export
# COPY --from=builder /usr/local/bin/ghdl /ghdl-7-dev
# FROM ubuntu:24.04 AS toolchain
#
# ARG GCC_VERSION=12
# ARG DEBIAN_FRONTEND=noninteractive
#
# WORKDIR /proj
#
# RUN apt-get update && apt-get install -y \
#     build-essential \
#     gnat \
#     git \
#     wget \
#     flex \
#     bison \
#     libgnat-14 \
#     libgmp-dev \
#     libmpfr-dev \
#     libmpc-dev \
#     zlib1g-dev \
#     tcl \
#     pv \
#     texinfo \
#     && rm -rf /var/lib/apt/lists/*
#
# WORKDIR /ghdl-build
# RUN wget -qO- https://mirrors.ocf.berkeley.edu/gnu/gcc/gcc-12.5.0/gcc-12.5.0.tar.gz \
#   | pv -s 110M \
#   | tar -xz
#
# RUN git clone --depth 1 https://github.com/ghdl/ghdl
#
# WORKDIR /ghdl-build/ghdl
# RUN mkdir build && cd build \
#     && ../configure --with-gcc=/ghdl-build/gcc-12.5.0 --prefix=/usr/local \
#     && make copy-sources
#
# WORKDIR /ghdl-build
# RUN mkdir gcc-objs
# WORKDIR /ghdl-build/gcc-objs
# RUN /ghdl-build/gcc-12.5.0/configure \
#     --prefix=/usr/local        \
#     --enable-languages=c,vhdl  \
#     --disable-bootstrap        \
#     --disable-lto              \
#     --disable-multilib         \
#     --disable-libssp           \
#     --disable-libgomp          \
#     --disable-libquadmath      \
#     --enable-default-pie       \
#     --enable-static            \
#     LDFLAGS="$LDFLAGS -static"
#
# WORKDIR /ghdl-build/gcc-objs
# RUN make -j$(nproc) && make install
#
# WORKDIR /ghdl-build/ghdl/build
# RUN make ghdllib && make install
#
# # ── OSVVM stage ────────────────────────────────────────────────────────────────
# FROM toolchain AS osvvm
#
# WORKDIR /
# RUN git clone --recursive "https://github.com/OSVVM/OsvvmLibraries.git"
#
# WORKDIR /OsvvmLibraries/osvvm
# COPY build_osvvm.sh .
# RUN chmod +x build_osvvm.sh && ./build_osvvm.sh
# RUN mkdir -p $HOME/VHDL_LIBS/GHDL-7.0.0/osvvm/v08
# RUN cp work/* $HOME/VHDL_LIBS/GHDL-7.0.0/osvvm/v08
#
# # ── Project stage ──────────────────────────────────────────────────────────────
# FROM osvvm AS project
#
# WORKDIR /Hardware303
# COPY nco .
# RUN make
#
# # ── Export stage ───────────────────────────────────────────────────────────────
# FROM scratch AS export
# COPY --from=project /usr/local/bin/ghdl /ghdl-7-dev

FROM ghdl/ghdl:7.0.0-dev-gcc-ubuntu-24.04 AS osvvm

RUN apt-get update && apt-get install -y \
    git \
    make \
    pandoc \
    python3 \
    python3-matplotlib \
    python3-numpy \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /
RUN git clone --recursive "https://github.com/OSVVM/OsvvmLibraries.git"

WORKDIR /OsvvmLibraries/osvvm
COPY build_osvvm.sh .
RUN chmod +x build_osvvm.sh && ./build_osvvm.sh
RUN mkdir -p $HOME/VHDL_LIBS/GHDL-7.0.0/osvvm/v08
RUN cp work/* $HOME/VHDL_LIBS/GHDL-7.0.0/osvvm/v08

FROM osvvm AS project

WORKDIR /Hardware303
COPY nco .
RUN make

FROM scratch AS export
COPY --from=project /Hardware303/nco/**.vcd ./nco/
COPY --from=project /Hardware303/nco/**.txt ./nco/
