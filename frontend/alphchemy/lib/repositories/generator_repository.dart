import "package:alphchemy/model/generator/mock_data.dart";
import "package:alphchemy/model/generator_data.dart";
import "package:alphchemy/model/generator_summary.dart";
import "package:uuid/uuid.dart";

const _uuid = Uuid();

class GeneratorRepository {
  final Map<String, _StoredGenerator> _store = {};

  GeneratorRepository() {
    final seedId = _uuid.v4();
    final seedData = GeneratorData.fromJson(mockWrapperJson);
    _store[seedId] = _StoredGenerator(
      summary: GeneratorSummary(
        id: seedId,
        title: "Experiment",
        createdAt: DateTime.now()
      ),
      data: seedData
    );
  }

  Future<List<GeneratorSummary>> loadAll() async {
    final summaries = _store.values.map((stored) => stored.summary);
    return summaries.toList();
  }

  Future<GeneratorData> load(String id) async {
    final stored = _store[id];
    if (stored == null) {
      throw Exception("Generator not found: $id");
    }
    return stored.data;
  }
  
  Future<void> save(String id, GeneratorData data) async {
    final title = data.generator["title"] as String? ?? "Untitled";
    final existing = _store[id];
    final createdAt = existing?.summary.createdAt ?? DateTime.now();
    _store[id] = _StoredGenerator(
      summary: GeneratorSummary(
        id: id,
        title: title,
        createdAt: createdAt
      ),
      data: data
    );
  }

  Future<void> delete(String id) async {
    _store.remove(id);
  }
}

class _StoredGenerator {
  final GeneratorSummary summary;
  final GeneratorData data;

  const _StoredGenerator({required this.summary, required this.data});
}
