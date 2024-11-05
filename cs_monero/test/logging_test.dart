import 'package:cs_monero/cs_monero.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  group('Logging', () {
    tearDown(() {
      Logging.useLogger = false;
      Logging.log = null;
    });

    test('Default logging state is disabled', () {
      expect(Logging.useLogger, isFalse);
      expect(Logging.log, isNull);
    });

    test('Enabling logging sets up a Logger instance', () {
      Logging.useLogger = true;
      expect(Logging.useLogger, isTrue);
      expect(Logging.log, isNotNull);
      expect(Logging.log, isA<Logger>());
    });

    test('Disabling logging sets Logger instance to null', () {
      Logging.useLogger = true;
      expect(Logging.log, isNotNull);

      Logging.useLogger = false;
      expect(Logging.useLogger, isFalse);
      expect(Logging.log, isNull);
    });

    test('Can override Logger instance after enabling logging', () {
      Logging.useLogger = true;
      final customLogger = Logger(
        printer: PrettyPrinter(printEmojis: true),
      );

      Logging.log = customLogger;
      expect(Logging.log, equals(customLogger));
    });

    test('Custom Logger instance is not preserved when useLogger is modified',
        () {
      final customLogger = Logger(
        printer: PrettyPrinter(printEmojis: true),
      );

      Logging.useLogger = true;
      Logging.log = customLogger;
      expect(Logging.log, equals(customLogger));

      Logging.useLogger = true;
      expect(
        Logging.log,
        isNot(equals(customLogger)),
      ); // Re-enabling should reset Logger
    });
  });
}
