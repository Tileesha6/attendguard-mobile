import 'package:flutter_test/flutter_test.dart';
import 'package:attendguard/services/beacon_parser.dart';

void main() {
  test('accepts the handoff sample payload for code 12345678', () {
    expect(BeaconParser.parse({0xFFFF: [0xA7, 0x00, 0xBC, 0x61, 0x4E]}), '12345678');
  });

  test('preserves leading zeroes', () {
    expect(BeaconParser.parse({0xFFFF: [0xA7, 0, 0, 0, 42]}), '00000042');
  });

  test('ignores unknown manufacturer IDs and marker', () {
    expect(BeaconParser.parse({0x1234: [0xA7, 0, 0, 0, 42]}), isNull);
    expect(BeaconParser.parse({0xFFFF: [0xB7, 0, 0, 0, 42]}), isNull);
  });
}
