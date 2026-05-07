import "package:alphchemy/model/experiment/mock_data.dart";
import "package:alphchemy/model/experiment_data.dart";
import "package:alphchemy/model/experiment_summary.dart";
import "package:uuid/uuid.dart";

const _uuid = Uuid();

class ExperimentRepository {
  final Map<String, _StoredExperiment> _store = {};

  ExperimentRepository() {
    final seedId = _uuid.v4();
    final seedData = ExperimentData.fromJson(mockExperimentJson);
    _store[seedId] = _StoredExperiment(
      summary: ExperimentSummary(
        id: seedId,
        createdAt: DateTime.now()
      ),
      data: seedData
    );
  }

  Future<List<ExperimentSummary>> loadAll() async {
    final summaries = _store.values.map((stored) => stored.summary);
    return summaries.toList();
  }

  Future<ExperimentData> load(String id) async {
    final stored = _store[id];
    if (stored == null) {
      throw Exception("Experiment not found: $id");
    }
    return stored.data;
  }
  
  Future<void> save(String id, ExperimentData data) async {
    final existing = _store[id];
    final createdAt = existing?.summary.createdAt ?? DateTime.now();
    _store[id] = _StoredExperiment(
      summary: ExperimentSummary(
        id: id,
        createdAt: createdAt
      ),
      data: data
    );
  }

  Future<void> delete(String id) async {
    _store.remove(id);
  }
}

class _StoredExperiment {
  final ExperimentSummary summary;
  final ExperimentData data;

  const _StoredExperiment({required this.summary, required this.data});
}
