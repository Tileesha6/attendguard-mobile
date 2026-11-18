/// Manufacturer 0xFFFF, marker 0xA7, unsigned big-endian uint32 code.
class BeaconParser {
  static String? parse(Map<int, List<int>> manufacturerData) {
    final raw = manufacturerData[0xFFFF];
    if (raw == null) return null;

    List<int> payload;
    if (raw.length == 5 && raw[0] == 0xA7) {
      payload = raw;
    } else if (raw.length == 7 && raw[0] == 0xFF &&
        raw[1] == 0xFF && raw[2] == 0xA7) {
      payload = raw.sublist(2);
    } else {
      return null;
    }

    final code = ((payload[1] & 0xFF) << 24) |
        ((payload[2] & 0xFF) << 16) |
        ((payload[3] & 0xFF) << 8) |
        (payload[4] & 0xFF);
    if (code <= 0 || code > 99999999) return null;
    return code.toString().padLeft(8, '0');
  }
}
