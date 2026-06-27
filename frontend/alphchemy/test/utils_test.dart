import "package:alphchemy/utils.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("format iso date omits seconds and milliseconds", () {
    final withSeconds = formatIsoDate("2023-01-02T03:04:05Z");
    final withMilliseconds = formatIsoDate("2023-01-02T03:04:05.678Z");

    expect(withSeconds, "Jan 2, 2023 03:04");
    expect(withMilliseconds, "Jan 2, 2023 03:04");
  });
}
