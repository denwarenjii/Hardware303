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

WORKDIR /Hardware303/nco
COPY nco .
RUN make run

WORKDIR /Hardware303/cordic
COPY cordic .
RUN make run

WORKDIR /Hardware303/wblock
COPY wblock .
RUN make run

WORKDIR /Hardware303/moogfilterstage
COPY moogfilterstage .
RUN make run

WORKDIR /Hardware303/moogfilter
COPY moogfilter .
RUN make run

FROM scratch AS export
COPY --from=project /Hardware303/nco/ ./nco/
COPY --from=project /Hardware303/cordic/ ./cordic/
COPY --from=project /Hardware303/wblock/ ./wblock/
COPY --from=project /Hardware303/moogfilterstage/ ./moogfilterstage/
COPY --from=project /Hardware303/moogfilter/ ./moogfilter/

# COPY --from=project /Hardware303/nco/**.vcd ./nco/
# COPY --from=project /Hardware303/nco/**.txt ./nco/
#
# COPY --from=project /Hardware303/cordic/**.vcd ./cordic/
# COPY --from=project /Hardware303/cordic/**.txt ./cordic/
#
# COPY --from=project /Hardware303/wblock/**.vcd ./wblock/
# COPY --from=project /Hardware303/wblock/**.txt ./wblock/
#
# COPY --from=project /Hardware303/moogfilterstage/**.vcd ./moogfilterstage/
# COPY --from=project /Hardware303/moogfilterstage/**.txt ./moogfilterstage/
#
# COPY --from=project /Hardware303/moogfilter/**.vcd ./moogfilter/
# COPY --from=project /Hardware303/moogfilter/**.txt ./moogfilter/
