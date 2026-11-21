PLUS4 ?= 0

ASM = acme
ASMFLAGS = -DPLUS4=$(PLUS4) -Dwic64_build_report=1 -Dwic64_optimize_for_size=0 -v3 --color -Wno-label-indent
EMU ?= x64sc
EMUFLAGS ?=