class DocsIndex {
  final Map<String, List<String>> groups;

  const DocsIndex({required this.groups});

  factory DocsIndex.fromJson(Map<String, dynamic> json) {
    final groups = <String, List<String>>{};
    for (final entry in json.entries) {
      final ids = entry.value as List<dynamic>;
      groups[entry.key] = ids.map((id) => id as String).toList();
    }
    return DocsIndex(groups: groups);
  }

  DocsIndex copy() => DocsIndex.fromJson(groups);

}
