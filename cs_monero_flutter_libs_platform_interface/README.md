# `cs_monero_flutter_libs_platform_interface`
A common platform interface for the 
[`cs_monero`](https://pub.dev/packages/cs_monero) plugin.

# Usage
To implement a new platform-specific implementation of `cs_monero`, extend 
`CsMoneroFlutterLibsPlatform` with an implementation that performs the 
platform-specific behavior, and when you register your plugin, set the default 
`CsMoneroFlutterLibsPlatform` by calling 
`CsMoneroFlutterLibsPlatform.instance = CsMoneroFlutterLibsPlatform()`.
