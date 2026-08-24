# Reproducible precompiled binaries

This repository keeps its existing Melos prepare, build, and copy commands.
The reproducibility commands wrap those same scripts with a clean build,
stable build environment variables, canonical SHA-256 manifests, and build
provenance. They do not introduce a second packaging path.

The first host records a candidate baseline. A different physical host checks
out that exact commit and verifies it. A recorded hash is a target, not proof
of reproducibility; claim a platform reproducible only after the independent
verification passes.

## Commands

Bootstrap once:

```sh
dart pub get
dart run melos bootstrap
```

Then run one of:

```sh
dart run melos run repro:record:macos
dart run melos run repro:verify:macos
dart run melos run repro:record:windows
dart run melos run repro:verify:windows
```

Equivalent commands exist for `android`, `ios`, and `linux`. The Linux Nix
derivation has its own two-build comparison:

```sh
dart run melos run repro:nix
```

The record and verify commands:

1. remove only this clone's top-level `build/` and `built_outputs/`;
2. set `SOURCE_DATE_EPOCH=1`, `ZERO_AR_DATE=1`, `TZ=UTC`, and the C locale;
3. run the existing `prepare_monero_c.dart` pinned-source and patch step;
4. run the existing `build_libs.dart <platform>` native build;
5. run the existing `copy_libs.dart` publication-package copy step; and
6. hash every regular file in `built_outputs/<platform>/` using stable,
   platform-independent paths.

`record` writes `reproducibility/manifests/<platform>.sha256` and a provenance
file beside it. It refuses to overwrite an existing baseline. `verify` writes
its current manifest and provenance under the ignored
`reproducibility/results/` directory, then exits nonzero for changed,
missing, or unexpected files.

## macOS baseline

Use an Apple Silicon Mac with Xcode command-line tools and Homebrew:

```sh
brew install autoconf automake ccache cmake libtool unbound xz zeromq
dart pub get
dart run melos bootstrap
dart run melos run repro:record:macos
```

Review and commit the new macOS manifest and provenance together with the
updated precompiled package contents. Record the repository commit, Xcode
version, macOS version, Flutter version, and Homebrew package versions in the
handoff. The generated provenance file captures them as a cross-check.

On the second Apple Silicon Mac, check out that exact baseline commit and run:

```sh
dart pub get
dart run melos bootstrap
dart run melos run repro:verify:macos
```

## Windows baseline

The existing cs_monero Windows workflow is a MinGW cross-build under Ubuntu
24.04 in Windows 11 WSL2. It is not a native Windows or MSYS2 build. Install:

```sh
sudo apt-get update
sudo apt-get install -y \
  autoconf automake build-essential ccache cmake curl gperf \
  g++-mingw-w64-x86-64-posix gcc-mingw-w64-x86-64-posix \
  lbzip2 libtinfo6 libtool make patch pkg-config xz-utils
```

Keep the clone on the WSL Linux filesystem, not `/mnt/c`. Before invoking the
wrapper, remove entries containing spaces or parentheses from `PATH`, matching
the existing build note:

```sh
repro_path="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '[ ()]' | paste -sd: -)"
export PATH="$repro_path"
dart pub get
dart run melos bootstrap
dart run melos run repro:record:windows
```

Review and commit the Windows manifest, provenance, and updated precompiled
package contents. On the second Windows 11/WSL2 host, check out that exact
commit, repeat the dependency, PATH, and bootstrap steps, then run:

```sh
dart run melos run repro:verify:windows
```

## Release and CI use

After verification passes, the release owner may continue to use the familiar
`build:<platform>` and `copyLibs` commands. Running the matching
`repro:verify:<platform>` immediately before publishing additionally proves
that the package-bound files match the reviewed baseline.

`.github/workflows/reproducible-precompiled.yml` runs the manifest tool on
Linux, macOS, and Windows, verifies the Nix and StageX definitions, and runs the
legacy-compatible macOS ARM64 and Windows x64 cross-build jobs. While a
platform has no committed baseline, CI's `auto` mode records a candidate and
uploads the artifacts. Once the baseline exists, the same job verifies it.

If a comparison fails, preserve `reproducibility/results/` and compare its
provenance with the committed file before changing a baseline. Differences in
the pinned source, SDK, compiler, linker, archive tools, package versions, or
absolute build paths are evidence to investigate, not reasons to force an
overwrite.
