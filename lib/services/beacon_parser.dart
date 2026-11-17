/// Protocol from Anti-Proxy Smart Attendance handoff rev 2:
/// Manufacturer company id 0xFFFF, followed by marker 0xA7 and big-endian uint32.
class BeaconParser {
  static String? parse(Map<int, List<int>> manufacturerData) {
    final payload = manufacturerData[0xFFFF];
    if (payload == null || payload.length != 5 || payload[0] != 0xA7) {
      return null;
    }
    final code = ((payload[1] & 0xFF) << 24) |
        ((payload[2] & 0xFF) << 16) |
        ((payload[3] & 0xFF) << 8) |
        (payload[4] & 0xFF);
    if (code < 0 || code > 99999999) return null;
    return code.toString().padLeft(8, '0');
  }
}
