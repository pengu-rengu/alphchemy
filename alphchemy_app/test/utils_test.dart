import "package:alphchemy_app/utils.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("format iso date omits seconds and milliseconds", () {
    final withSeconds = formatIsoDate("2023-01-02T03:04:05Z");
    final withMilliseconds = formatIsoDate("2023-01-02T03:04:05.678Z");

    expect(withSeconds, "Jan 2 2023 03:04");
    expect(withMilliseconds, "Jan 2 2023 03:04");
  });

  test("format iso date treats timestamps without timezone as utc", () {
    final withoutTimezone = formatIsoDate("2026-02-28T23:00:00");
    final withZulu = formatIsoDate("2026-02-28T23:00:00Z");

    expect(withoutTimezone, "Feb 28 2026 23:00");
    expect(withZulu, "Feb 28 2026 23:00");
  });
}
