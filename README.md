# About
 - A simplified Flutter/Dart Monero (and Wownero) wallet library.
 - Depends on https://github.com/MrCyjaneK/monero_c/
 - Abstracts the wallet2 spaghetti
 - Refactored and organized version of flutter_libmonero based on https://github.com/cypherstack/flutter_libmonero/tree/heavy-refactor

## Usage
1. Add this repo as a git submodule.
2. Add `cs_monero`, `cs_monero_flutter_libs`, (and `compat` if needed) to your pubspec.yaml as relative dependencies.
3. Choose an option below

#### Option 1: Build from source
1. [Build](README.md#building-monero_c) the platforms you want.
2. Run `tools/copy_outputs_to_cs_monero_flutter_libs_package.sh` to copy the binaries to where Flutter can find them.

#### Option 2: Use precompiled binaries (at your own risk!!!)
1. Run `tools/use_precompiled_at_your_own_risk.sh` (or .bat on windows) to copy the precompiled binaries so Flutter can find them.

## Building monero_c
Run the `build_<platform>.sh` script in `tools/build_scripts` to generate the platform specific outputs for each platform wanted.

##### Building instructions
- This repo just has some wrapper scripts. For details and requirements see https://github.com/MrCyjaneK/monero_c/
- To do a clean/fresh build, just the delete the top level `build` dir

## Known Limitations
 - No iOS simulator support
 - No Android i686 support

## TODO
 - Tests? (at least what is possible)
 - Accounts API?
 - Use FFI project skeleton for libs vs Platform Plugin?
 - Cleaner/more user friendly API
 - Remove cs_monero's compat dependency (aka add get height by date functionality to cs_monero)
 - Use `BigInt` for money values where ever its not used yet (such as balances)