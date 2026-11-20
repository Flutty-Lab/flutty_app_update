import 'package:flutty_app_update/flutty_app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('parses segments and optional build', () {
      expect(AppVersion.tryParse('1.2.3')?.segments, [1, 2, 3]);
      expect(AppVersion.tryParse('1.2.3')?.build, isNull);
      expect(AppVersion.tryParse('1.2.3+45')?.build, 45);
    });

    test('trims surrounding whitespace', () {
      expect(AppVersion.tryParse(' 1.2 ')?.segments, [1, 2]);
    });

    test('rejects unreadable values', () {
      for (final raw in ['', '   ', 'abc', '1.x', '1.-2', '1.2+x', '1.2+-1']) {
        expect(AppVersion.tryParse(raw), isNull, reason: raw);
      }
    });
  });

  group('AppVersion.compareTo', () {
    test('missing segments count as 0', () {
      expect(
        AppVersion.tryParse('1.2')!.compareTo(AppVersion.tryParse('1.2.0')!),
        0,
      );
    });

    test('compares segment by segment', () {
      expect(
        AppVersion.tryParse('1.2.9')! < AppVersion.tryParse('1.2.10')!,
        isTrue,
      );
      expect(
        AppVersion.tryParse('2.0')! < AppVersion.tryParse('1.9.9')!,
        isFalse,
      );
    });

    test('build breaks a tie only when both carry one', () {
      expect(
        AppVersion.tryParse('1.3.0+4')!
            .compareTo(AppVersion.tryParse('1.3.0+5')!),
        -1,
      );
      expect(
        AppVersion.tryParse('1.3.0')!
            .compareTo(AppVersion.tryParse('1.3.0+5')!),
        0,
      );
    });
  });

  group('isVersionBelow', () {
    test('true only when strictly below the floor', () {
      expect(isVersionBelow(current: '1.2.9', reference: '1.3.0'), isTrue);
      expect(isVersionBelow(current: '1.3.0', reference: '1.3.0'), isFalse);
      expect(isVersionBelow(current: '1.3.1', reference: '1.3.0'), isFalse);
    });

    test('unreadable or empty values never match', () {
      expect(isVersionBelow(current: '1.0.0', reference: ''), isFalse);
      expect(isVersionBelow(current: '', reference: '1.3.0'), isFalse);
      expect(isVersionBelow(current: 'junk', reference: '1.3.0'), isFalse);
      expect(isVersionBelow(current: '1.0.0', reference: 'junk'), isFalse);
    });
  });
}
