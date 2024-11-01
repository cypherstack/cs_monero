# About
 - A simplified Flutter/Dart Monero (and Wownero) wallet library.
 - Depends on https://github.com/MrCyjaneK/monero_c/
 - Abstracts the wallet2 spaghetti.
 - Refactored and organized version of flutter_libmonero based on 
   https://github.com/cypherstack/flutter_libmonero/tree/heavy-refactor.

## Usage
1. Add this repo as a git submodule.
2. Add `cs_monero` and `cs_monero_flutter_libs` to your pubspec.yaml as relative 
  dependencies.  If you're migrating from `flutter_libmonero` to `cs_monero`, 
  also add `compat`.

## Build libraries from source (optional but recommended)
By default, `cs_monero_flutter_libs` will automatically include and download the 
appropriate platform-specific binaries when you run `flutter pub get`.  Use 
these at your own risk.  To build the libraries yourself:

1. Install [Melos](https://pub.dev/packages/melos) 
   (`dart pub global activate melos`) and run `melos bootstrap` (or `melos bs`).
2. Build the platform you want using one of the following commands:
   - `melos build:android`
   - `melos build:ios`
   - `melos build:linux`
   - `melos build:macos`
   - `melos build:windows`
3. Run `melos copyLibs` to copy the binaries to where Flutter can find them.

### Building notes
- This repo's build scripts are just wrappers around `monero_c`'s build scripts.
  For details and requirements see https://github.com/MrCyjaneK/monero_c/
- To do a clean/fresh build, just the delete the top level `build` dir.

## Known Limitations
 - No iOS simulator support
 - No Android i686 support

## TODO
 - Tests? (at least what is possible)
 - Accounts API?
 - Use FFI project skeleton for libs vs Platform Plugin?
 - Cleaner/more user friendly API
 - Use `BigInt` for money values where ever its not used yet (such as balances)