import 'package:flutter_test/flutter_test.dart';
import 'package:attendguard/services/beacon_parser.dart';

void main() {
  test('accepts the documented 5-byte handoff sample', () {
    expect(BeaconParser.parse({0xFFFF: [0xA7, 0x00, 0xBC, 0x61, 0x4E]}), '12345678');
  });
  test('preserves leading zeroes', () {
    expect(BeaconParser.parse({0xFFFF: [0xA7, 0, 0, 0, 42]}), '00000042');
  });
  test('accepts prefixed 7-byte representation', () {
    expect(BeaconParser.parse({0xFFFF: [0xFF, 0xFF, 0xA7, 0, 0xBC, 0x61, 0x4E]}), '12345678');
  });
  test('rejects zero, malformed, wrong IDs, wrong markers and overflow', () {
    expect(BeaconParser.parse({0xFFFF: [0xA7, 0, 0, 0, 0]}), isNull);
    expect(BeaconParser.parse({0xFFFF: [0xA7, 0xFF, 0xFF, 0xFF, 0xFF]}), isNull);
    expect(BeaconParser.parse({0xFFFF: [0xA7, 0, 0, 0]}), isNull);
    expect(BeaconParser.parse({0xFFFF: [0xFF, 0xFF, 0xA7, 0, 0, 0]}), isNull);
    expect(BeaconParser.parse({0x1234: [0xA7, 0, 0, 0, 42]}), isNull);
    expect(BeaconParser.parse({0xFFFF: [0xB7, 0, 0, 0, 42]}), isNull);
  });
}
