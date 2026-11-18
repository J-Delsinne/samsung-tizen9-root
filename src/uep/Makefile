# Kernel module Makefile.
# Build against the Tizen 9 kernel headers you extracted from the firmware package.
# See ../../docs/TECHNICAL.md for the extraction procedure.
#
# Usage:
#   make KDIR=/path/to/tizen9-kernel-headers ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
# or, from the repo root, just run ./build/build-all.sh uep (uses dockcross).

obj-m += uep31.o

KDIR ?= /lib/modules/$(shell uname -r)/build
ARCH ?= arm
CROSS_COMPILE ?= arm-linux-gnueabi-

.PHONY: all clean

all:
	$(MAKE) -C $(KDIR) M=$(PWD) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
