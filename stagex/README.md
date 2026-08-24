# StageX build

This StageX `user` package builds the Linux Monero wallet C API from source.
It locks the wrapper, Monero core, every nested source dependency, Unbound,
and the direct StageX image inputs. Compilation runs with networking disabled.

Use StageX commit `9bdf430d09ce2ba53932df0182faef00d4feecd1`:

```sh
cp -R stagex /path/to/stagex/packages/user/stack-wallet-cs-monero
cd /path/to/stagex
git add packages/user/stack-wallet-cs-monero
make fetch PKG=stack-wallet-cs-monero
make user-stack-wallet-cs-monero NOCACHE=1
python3 src/package-digests.py user-stack-wallet-cs-monero
```

Build from clean checkouts on two independent builders and compare the OCI
manifest digest. The StageX artifact targets musl Linux and is independent of
the glibc-linked Nix artifact; compare like-for-like artifacts within a build
system, not Nix bytes to StageX bytes.
