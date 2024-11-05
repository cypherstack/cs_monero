# About
- A sado not trust the binaries hosted on https://pub.dev you can build from
source.  Refer to [`cs_monero/cs_monero/README.md`](https://github.com/cypherstack/cs_monero/tree/main/cs_monero/README.md)

## Quickstart
1. Add to pubspec.yaml
    ```yaml
    dependencies:
      cs_monero: 0.0.1
      cs_monero_flutter_libs: 0.0.1 # Contains native libs required by cs_monero.
    ```
2. Create a wallet
   ```dart
     final wallet = MoneroWallet.create(
     path: "somePath", // Path to wallet files will be saved,
     password: "SomeSecurePassword", // Your wallet files are only as secure as this password.  This cannot be recovered if lost!
     language: "English", // Seed language.
     seedType: MoneroSeedType.sixteen, // 16 word polyseed or MoneroSeedType.twentyFive for legacy seed format.
     networkType: 0, // Mainnet.
   );
    
   Address? address = wallet.getAddress();
   ```

## Known Limitations
- No iOS simulator support
- No Android i686 support
