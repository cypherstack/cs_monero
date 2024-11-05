# `cs_monero`
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

A [Melos](https://github.com/invertase/melos) monorepo for the
[`cs_monero` package](https://pub.dev/packages/cs_monero) and its children.

# About
- A simplified Flutter/Dart Monero (and Wownero) wallet library.
- Depends on https://github.com/MrCyjaneK/monero_c/
- Abstracts the wallet2 spaghetti.
- Refactored and organized version of flutter_libmonero based on
  https://github.com/cypherstack/flutter_libmonero/tree/heavy-refactor.

## Getting started
[Install Melos](https://melos.invertase.dev/~melos-latest/getting-started) (`dart pub global activate melos`) and 
run `melos bootstrap` (or `melos bs`) in this root directory to get started.

### Example
Launch the example with `melos example` (or `flutter run` in `example_app`).

## Build libraries from source (optional but recommended)
By default, `cs_monero_flutter_libs` will automatically include and download the
appropriate platform-specific binaries when you run `flutter pub get`.  Use
these at your own risk.  To build the libraries yourself:

1. Add this repo as a sub module or something to your project and add `cs_monero` 
   and `cs_monero_flutter_libs` to your pubspec.yaml as relative
   dependencies.  If you're migrating from `flutter_libmonero` to `cs_monero`,
   also add `compat`.

2. Install [Melos](https://pub.dev/packages/melos)
   (`dart pub global activate melos`) and run `melos bootstrap` (or `melos bs`).
3. Build the platform you want using one of the following commands:
    - `melos build:android`
    - `melos build:ios`
    - `melos build:linux`
    - `melos build:macos`
    - `melos build:windows`
4. Run `melos copyLibs` to copy the binaries to where Flutter can find them.

### Building notes
- This repo's build scripts are just wrappers around `monero_c`'s build scripts.
  For details and requirements see https://github.com/MrCyjaneK/monero_c/
- To do a clean/fresh build, just the delete the top level `build` dir.

## TODO
- Tests? (at least what is possible)
- Accounts API?
- Use FFI project skeleton for libs vs Platform Plugin?
- Cleaner/more user friendly API
- Use `Big