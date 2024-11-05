import 'package:logger/logger.dart';

/// A singleton logging instance that provides some debug info. Disabled by default.
///
/// ### Usage
/// To enable logging, set [useLogger] to `true`. This initializes a default [Logger]
/// instance using a [PrefixPrinter] for prefixed logs and a [PrettyPrinter] for
/// formatted output.
///
/// ### Custom Logger
/// - The [Logger] instance can be customized by directly assigning a new instance
///   to [log]. Note that this should be done *after* enabling logging by setting
///   [useLogger] to `true`, as enabling it sets a default [Logger].
abstract class Logging {
  /// The static [Logger] instance used for logging messages.
  /// If logging is disabled, this will be `null`.
  static Logger? log;

  /// Internal flag to track whether logging is enabled (`true`) or disabled (`false`).
  static bool _useLogger = false;

  /// Returns `true` if logging is currently enabled; otherwise, returns `false`.
  static bool get useLogger => _useLogger;

  /// Enables or disables logging based on the [useLogger] parameter.
  /// - If `true`, initializes [log] with a default configuration.
  /// - If `false`, sets [log] to `null` and disables logging.
  ///
  /// Example:
  /// ```dart
  /// Logging.useLogger = true; // Enables logging
  /// Logging.log?.d("Debug message"); // Logs a debug message
  /// ```
  ///
  /// When logging is enabled, the default logger is configured to:
  /// - Exclude info and debug level messages from boxed formatting.
  /// - Disable emojis in log messages.
  /// - Skip method tracing for cleaner output.
  static set useLogger(bool useLogger) {
    if (useLogger) {
      log = Logger(
        printer: PrefixPrinter(
          PrettyPrinter(
            printEmojis: false, // Disable emoji symbols in log output
            methodCount: 0, // Disable method trace
            excludeBox: {
              Level.info: true, // Info level logs will not use boxed format
              Level.debug: true, // Debug level logs will not use boxed format
            },
          ),
        ),
      );
    } else {
      log = null; // Disables logging by setting log to null
    }
    _useLogger = useLogger;
  }
}
