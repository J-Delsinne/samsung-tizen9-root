# Dockerfile for samsung-tizen9-root builds.
# Base: dockcross/linux-armv7-lts — matches the ABI of Tizen 9 user-space:
#   ARMv7, soft-float EABI (NOT -hf), glibc 2.30+, dynamic linker /lib/ld-linux.so.3.
#
# Produces: uep31.ko, dropbear (static ARM32 binary).
#
# Use via build-all.sh — not meant to be driven by hand.

FROM dockcross/linux-armv7-lts:latest

# Extra tools we need beyond what the base image ships
RUN apt-get update && apt-get install -y --no-install-recommends \
        bc \
        bison \
        flex \
        libssl-dev \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# dockcross sets up the toolchain env; nothing else to do.
WORKDIR /work
CMD ["/bin/bash"]
