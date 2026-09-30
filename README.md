# dc-kos-toolchain-rs

KallistiOS Dreamcast toolchain with Rust (`rustc_codegen_gcc`).

The stock `sh-elf` GCC from `kallistios/dc-kos-toolchain` stays in `/opt/toolchains/dc`. Rust uses a second GCC with `libgccjit` and a `libpthread` KallistiOS built with `-m4-single`, both under `/opt/toolchains/dc/rust`.

Docker Hub: [hldtux/dc-kos-toolchain-rs](https://hub.docker.com/r/hldtux/dc-kos-toolchain-rs)

## Use

```bash
docker run --platform linux/amd64 --rm -it -v "$PWD":/src hldtux/dc-kos-toolchain-rs kos-cargo build
```

`kos-rustc` is on `PATH`. If a crate needs `libc`, point Cargo at the KallistiOS fork:

```toml
[patch.crates-io]
libc = { path = "/opt/toolchains/dc/rust/libc" }
```

## Build

```bash
docker build --platform linux/amd64 -t dc-kos-toolchain-rs .
```

GCC and the Rust sysroot take several hours. `JOBS` sets parallelism (default `2`).
