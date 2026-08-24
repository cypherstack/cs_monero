# Reproducible native builds

The Nix flake builds the Linux `libmonero_libwallet2_api_c.so` consumed by
`cs_monero_flutter_libs_linux`. It pins `monero_c`, all recursively nested
Monero submodules, the four submodules changed or added by the `monero_c`
patch series, nixpkgs, and every build tool in `flake.lock`. Network access is
not available during the build.

```sh
nix build .#cs-monero
./nix/verify-reproducible.sh
```

The verifier performs a second Nix build with `--rebuild` and compares the
library bytes. The resulting library and C header are under `result/lib` and
`result/include`.

This currently covers native Linux on x86-64 and AArch64. Android, Windows,
macOS, and iOS need separate pinned SDK/cross-toolchain derivations before
their checked-in release binaries can be replaced reproducibly.
