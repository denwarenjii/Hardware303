FROM ubuntu:26.04 AS builder

ARG GCC_VERSION 12
ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /proj

# See https://ghdl.github.io/ghdl/development/building/GCC.html#build-gcc
RUN apt-get update && apt-get install -y \
    build-essential \
    gnat \
    git \
    wget \
    flex \
    bison \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    zlib1g-dev \
    tcl \
    pv \
    texinfo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /ghdl-build
RUN wget -qO- https://mirrors.ocf.berkeley.edu/gnu/gcc/gcc-12.5.0/gcc-12.5.0.tar.gz \
  | pv -s 110M \
  | tar -xz

RUN git clone --depth 1 https://github.com/ghdl/ghdl

WORKDIR /ghdl-build/ghdl
RUN mkdir build && cd build \
    && ../configure --with-gcc=/ghdl-build/gcc-12.5.0 --prefix=/usr/local \
    && make copy-sources

WORKDIR /ghdl-build
RUN mkdir gcc-objs
WORKDIR /ghdl-build/gcc-objs
RUN /ghdl-build/gcc-12.5.0/configure \
    --prefix=/usr/local        \
    --enable-languages=c,vhdl  \
    --disable-bootstrap        \
    --disable-lto              \
    --disable-multilib         \
    --disable-libssp           \
    --disable-libgomp          \
    --disable-libquadmath

WORKDIR /ghdl-build/gcc-objs
RUN make -j$(nproc) && make install

WORKDIR /ghdl-build/ghdl/build
RUN make ghdllib && make install

WORKDIR /
RUN git clone --recursive "https://github.com/OSVVM/OsvvmLibraries.git"

WORKDIR /OsvvmLibraries/osvvm
COPY build_osvvm.sh /build_osvvm.sh
RUN chmod +x /build_osvvm.sh && /build_osvvm.sh


