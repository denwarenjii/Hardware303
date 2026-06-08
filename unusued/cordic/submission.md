---
documentclass: extarticle
fontsize: 8pt
geometry:
- top=.5in
- bottom=.5in
- left=.3in
- right=.3in
linestretch: 1
mainfont: "DejaVu Serif"
monofont: "DejaVu Sans Mono"
---

# System Functionality and Documentation (60 points)

See attached zip file. The directory structure is as follows: 

```

├── sim
├── sim_pipeline_three
├── sim_pipelined
├── synth
├── synth_pipeline_three
└── synth_pipelined

```

Each sim directory has a Makefile that can be used to simulate the design using `Make run`. Debug info can be increased by uncommented the `SetLogEnable` calls in `Cordic.vhd` and `Cordic_TB.vhd` in each directory. The synth directories contain mostly the same files as their corresponding sim directories, but with a few modifications because Xilinx ISE 14.7 does not support the full VHDL-2008 standard. The printout contains only the files from the `sim_pipeline_three` directory. The rest of the directories are also not as fully commented as this.


# System Quality factor (25 points)

- Pipelined quality factor: $10\frac{f'_{\text{max}}}{f_{\text{max}}}-l^{2}$ where $f'_{\text{max}}$ is the max frequency of the pipelined system, $f_{\text{max}}$ is the max frequency of the original system, and $l^2$ is the latency in clocks.


## Stats:

| Pipelining Stages    | Size (slices)       | Slice Registers Used |  Minimum Clock Speed | Frequency  | Latency   | Throughput           | Quality Factor | 
|----------------------|---------------------|----------------------|----------------------|------------|-----------|----------------------|----------------|
| None                 | 3,917 / 8,672 (44%) | 91  / 17,344 (1%)    | 172/175 nS           | 5.808 MHz  | 1 clock   | 5.808 million ops/s  |  N/A           |
| 1                    | 2,531 / 8,672 (29%) | 158 / 17,344 (1%)    | 89.022 nS            | 11.233 MHz | 2 clocks  | 11.233 million ops/s | 15.340         |
| 3                    | 2,173 / 8,672 (25%) | 304 / 17,344 (1%)    | 45.681 nS            | 21.890     | 4 clocks  | 21.890 million ops/s | 21.689         |

- All timing values are from post-PAR (place-and-route) reports.

# System Size (15 points)

Surprisingly, the pipelined designs used less slices than the non-pipelined designs. I suspect that inserting DFFs in between stages somehow allowed the compiler/synthesizer to reuse large amounts of logic. This would make sense because a lot of the signals (such as the internal signals) are generated only for a small part of the cordic stages and then stored in DFFs. For example, in the three-stage pipelined Cordic design, the muxxes associated with generating the internal signals only need to generate the signals for 4 cordic stages and then save them in DFFs for the next stage of the pipeline, rather than make generate them for all 16 cordic stages. We do see an increase in slice DFFs used, with each pipelining stage adding about  60 - 70 DFFs. This is expected because we need to latch 3 * 22 bits for the outputs/inputs of each stage of pipelining we add, along with the select lines/internal signals. For each stage of pipelining we add, we need to latch:

- XInputBus(k) (22 bits)
- YInputBus(k) (22 bits)
- ZInputBus(k) (22 bits)
- Func         (5 bits)
- CordSystem   (2 bits)
- Mode         (1 bit)

This total to 74 DFFs per pipelining stage, but the actual increase is less than that, likely due to compiler/routing optimizations and trimming.
