#!/bin/bash
set -eux pipefail
make clean
make moogfilterstage
make moogfilterstage_tb
make run_moogfilterstage_tb