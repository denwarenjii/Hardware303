#!/bin/bash
set -eu pipefail
mkdir -p work

GHDL="/usr/local/bin/ghdl"
GHDL_FLAGS="--std=08 -Wuseless --work=osvvm --workdir=work"
SRCS=(
    "IfElsePkg.vhd"                    "OsvvmTypesPkg.vhd"
    "OsvvmScriptSettingsPkg.vhd"       "OsvvmScriptSettingsPkg_default.vhd"
    "OsvvmSettingsPkg.vhd"             "OsvvmSettingsPkg_default.vhd"
    "TextUtilPkg.vhd"                  "FileUtilPkg.vhd"
    "ResolutionPkg.vhd"                "NamePkg.vhd"
    "OsvvmGlobalPkg.vhd"               "CoverageVendorApiPkg_default.vhd"
    "TranscriptPkg.vhd"                "deprecated/LanguageSupport2019Pkg_c.vhd"
    "deprecated/FileLinePathPkg_c.vhd" "deprecated/AssertApiPkg_c.vhd"
    "AlertLogPkg.vhd"                  "TbUtilPkg.vhd"
    "NameStorePkg.vhd"                 "MessageListPkg.vhd"
    "SortListPkg_int.vhd"              "RandomBasePkg.vhd"
    "RandomPkg.vhd"                    "RandomProcedurePkg.vhd"
    "CoveragePkg.vhd"                  "DelayCoveragePkg.vhd"
    "ClockResetPkg.vhd"                "ResizePkg.vhd"
    "ScoreboardGenericPkg.vhd"         "ScoreboardPkg_IntV.vhd"
    "ScoreboardPkg_slv.vhd"            "ScoreboardPkg_int.vhd"
    "ScoreboardPkg_signed.vhd"         "ScoreboardPkg_unsigned.vhd"
    "MemorySupportPkg.vhd"             "MemoryGenericPkg.vhd"
    "MemoryPkg.vhd"                    "ReportPkg.vhd"
    "deprecated/RandomPkg2019_c.vhd"   "OsvvmContext.vhd"
)

mkdir -p work osvvm

for src in "${SRCS[@]}"; do
    echo "$GHDL -a $GHDL_FLAGS $src"
    $GHDL -a $GHDL_FLAGS "$src"
done
