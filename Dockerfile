# KallistiOS + Rust for Dreamcast.
#
# kallistios/dc-kos-toolchain ships sh-elf GCC and KallistiOS, but upstream
# rustc (LLVM) does not emit SuperH. The dreamcast.rs flow uses
# rustc_codegen_gcc, which needs:
#   - a second sh-elf GCC with libgccjit (rustc-dev profile)
#   - KallistiOS with libpthread, built with -m4-single
#   - the nightly pinned in rust-for-dreamcast/misc/install-rust.sh
#
# The base image sh-elf toolchain and KOS stay in /opt/toolchains/dc.
# The Rust toolchain lives in /opt/toolchains/dc/rust and comes first on PATH.
#
#   docker build --platform linux/amd64 -t dc-kos-toolchain-rs .
#   docker build --platform linux/amd64 --build-arg JOBS=8 -t dc-kos-toolchain-rs .
#
# Building GCC and the Rust sysroot takes several hours and tens of GB.

FROM kallistios/dc-kos-toolchain:latest

ARG JOBS=2

ENV PLATFORM=dreamcast \
    RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH="/opt/cargo/bin:/opt/toolchains/dc/rust/bin:/opt/toolchains/dc/rust/sh-elf/bin:/opt/toolchains/dc/bin:/opt/toolchains/dc/sh-elf/bin:/opt/toolchains/dc/arm-eabi/bin:/opt/toolchains/dc/kos/utils/build_wrappers:${PATH}"

SHELL ["/bin/bash", "-c"]

RUN apk add --no-cache \
        zip \
        build-base \
        bash \
        bison \
        flex \
        patch \
        texinfo \
        gawk \
        diffutils \
        coreutils \
        gmp-dev \
        mpfr-dev \
        mpc1-dev \
        zlib-dev \
        elfutils-dev \
        gettext-dev \
        curl \
        ca-certificates \
        wget \
        git \
        python3 \
        pkgconf \
    && git config --system --add safe.directory '*' \
    && chmod -R a+rX /opt/toolchains

# Musl host: rustup's gnu binaries do not run on this Alpine image.
RUN arch="$(uname -m)" \
    && case "${arch}" in \
         x86_64) rust_host=x86_64-unknown-linux-musl ;; \
         aarch64) rust_host=aarch64-unknown-linux-musl ;; \
         *) echo "no musl Rust host for architecture: ${arch}" >&2; exit 1 ;; \
       esac \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y \
            --default-host "${rust_host}" \
            --default-toolchain none \
            --profile minimal \
            --no-modify-path

RUN git clone --depth 1 https://github.com/dreamcast-rs/rust-for-dreamcast.git /opt/toolchains/dc/rust \
    && git clone --depth 1 https://github.com/dreamcast-rs/KallistiOS.git /opt/toolchains/dc/rust/kos

RUN /opt/toolchains/dc/rust/misc/install-toolchain.sh -j"${JOBS}"

RUN set -e \
    && source /opt/toolchains/dc/rust/misc/environ.sh \
    && make -C "$${KOS_BASE}" -j"${JOBS}" \
    && /opt/toolchains/dc/rust/misc/install-rust.sh \
    && rm -rf \
        /opt/toolchains/dc/rust/kos/utils/dc-chain/build \
        /opt/toolchains/dc/rust/kos/utils/dc-chain/unpack \
        /opt/toolchains/dc/rust/kos/utils/dc-chain/download \
        /opt/toolchains/dc/rust/sysroot \
        /opt/cargo/registry \
        /opt/cargo/git \
    && find /opt/toolchains/dc/rust -name .git -type d -prune -print0 | xargs -0 rm -rf \
    && chmod -R a+rX /opt/toolchains /opt/cargo /opt/rustup

RUN cat > /usr/local/bin/rust-kos-entry.sh <<'EOF'
#!/bin/bash
. /opt/toolchains/dc/rust/misc/environ.sh
export LD_LIBRARY_PATH="${KOS_CC_BASE}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$@"
EOF
RUN chmod a+x /usr/local/bin/rust-kos-entry.sh \
    && touch /root/.bashrc \
    && printf '\n# Rust for Dreamcast overrides the stock KOS environ.\n. /opt/toolchains/dc/rust/misc/environ.sh\nexport LD_LIBRARY_PATH="${KOS_CC_BASE}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n' >> /root/.bashrc \
    && printf '\n. /opt/toolchains/dc/rust/misc/environ.sh\nexport LD_LIBRARY_PATH="${KOS_CC_BASE}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n' >> /etc/profile

WORKDIR /src
ENTRYPOINT ["/usr/local/bin/rust-kos-entry.sh"]
CMD ["bash"]
