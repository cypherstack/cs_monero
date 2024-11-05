<p align="center">
  <a href="https://pub.dev/packages/cs_monero_flutter_libs">
    <img src="https://img.shields.io/pub/v/cs_monero_flutter_libs?label=pub.dev&labelColor=333940&logo=dart">
  </a>
  <a href="https://github.com/invertase/melos">
    <img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square">
  </a>
</p>

# `cs_monero_flutter_libs`
A wrapper for platform-specific implementations of the binaries required to use 
the [`cs_monero` package](https://pub.dev/packages/cs_monero).  Refer to the 
main monorepo at https://github.com/cypherstack/cs_monero for more context.

Modelled after the federated platform plugin interface used by 
[`url_launcher`](https://github.com/flutter/packages/tree/main/packages/url_launcher).

## Usage
`flutter pub add cs_monero_flutter_libs` will automatically include the 
appropriate endorsed plugin interface for your platform as needed.

## Optional
This package and its endorsed platform-specific plugin interfaces are not 
required to use `cs_monero`, but they are provided as a quick and convenient way 
to start coding with the library.  Refer to `cs_monero`'s documentation for more 
information on building the libraries from source.  Use this package and its 
platform-specific children as templates or examples for bundling the binaries 
required.
