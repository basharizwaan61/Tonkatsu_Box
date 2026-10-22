import 'package:flutter_test/flutter_test.dart';
import 'package:mediabox/features/search/utils/filter_value_utils.dart';

void main() {
  group('readFilterStringList', () {
    test('returns the string elements of a list', () {
      expect(readFilterStringList(<Object?>['a', 'b']), <String>['a', 'b']);
    });

    test('keeps only the string elements of a mixed list', () {
      expect(
        readFilterStringList(<Object?>['a', 1, null, 'b']),
        <String>['a', 'b'],
      );
    });

    test('wraps a single string in a list', () {
      expect(readFilterStringList('a'), <String>['a']);
    });

    test('returns an empty list for an empty list', () {
      expect(readFilterStringList(<Object?>[]), <String>[]);
    });

    test('returns null for null', () {
      expect(readFilterStringList(null), isNull);
    });

    test('returns null for a non-string, non-list value', () {
      expect(readFilterStringList(42), isNull);
    });
  });
}
