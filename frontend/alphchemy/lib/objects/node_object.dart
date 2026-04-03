abstract class NodeObject {
  String get nodeType;
  final Map<String, String> paramRefs = {};

  void updateField(String fieldKey, String text);
  void updateFieldTyped(String fieldKey, dynamic value);
  String formatField(String fieldKey);

  static List<int> parseIntList(String text) {
    final parts = text.split(",");
    final result = <int>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final parsed = int.tryParse(trimmed);
      if (parsed == null) continue;
      result.add(parsed);
    }
    return result;
  }

  static List<String> parseStringList(String text) {
    final parts = text.split(",");
    final result = <String>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      result.add(trimmed);
    }
    return result;
  }

  static String formatList(List items) {
    return items.join(", ");
  }

  static String formatNullable(Object? value) {
    if (value == null) return "";
    return value.toString();
  }
}
