ASM = acme
# Leave the following defines to the user: -DPLUS4=1 -DENABLE_OPTIMIZATIONS=1
ASMFLAGS = -Dwic64_build_report=1 -Dwic64_optimize_for_size=0 -v3 --color -Wno-label-indent
EMU ?= x64sc
EMUFLAGS ?=
