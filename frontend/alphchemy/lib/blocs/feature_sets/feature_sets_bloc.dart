/*
import "package:alphchemy/model/feature_set/feature_set.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/utils.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class FeatureSetsEvent {
  const FeatureSetsEvent();
}

class LoadFeatureSets extends FeatureSetsEvent {
  const LoadFeatureSets();
}

class CreateFeatureSet extends FeatureSetsEvent {
  final String title;
  final void Function(int id) onCreated;

  const CreateFeatureSet({required this.title, required this.onCreated});
}

class DeleteFeatureSet extends FeatureSetsEvent {
  final int id;

  const DeleteFeatureSet({required this.id});
}

sealed class FeatureSetsState {
  const FeatureSetsState();
}

class FeatureSetsInitial extends FeatureSetsState {
  const FeatureSetsInitial();
}

class FeatureSetsLoaded extends FeatureSetsState {
  final List<FeatureSetSummary> summaries;
  final String? errorMessage;

  const FeatureSetsLoaded({required this.summaries, this.errorMessage});
}

class FeatureSetsError extends FeatureSetsState {
  final String message;

  const FeatureSetsError({required this.message});
}

class FeatureSetsBloc extends Bloc<FeatureSetsEvent, FeatureSetsState> {
  final SupabaseClient client;

  FeatureSetsBloc({required this.client}) : super(const FeatureSetsInitial()) {
    on<LoadFeatureSets>(_onLoad);
    on<CreateFeatureSet>(_onCreate);
    on<DeleteFeatureSet>(_onDelete);
  }

  Future<void> _onLoad(LoadFeatureSets event, Emitter<FeatureSetsState> emit) async {
    try {
      await _loadAndEmit(emit: emit);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onCreate(CreateFeatureSet event, Emitter<FeatureSetsState> emit) async {
    try {
      final cleanedTitle = cleanTitle(event.title);
      final featureSet = FeatureSet(title: cleanedTitle);

      final table = client.from("feature_sets");
      final insert = table.insert({
        "title": featureSet.title,
        "features": featureSet.featsToJson(),
        "values": null,
        "status": FeatureSetStatus.idle.name,
        "start_timestamp": featureSet.startTimestamp.round(),
        "end_timestamp": featureSet.endTimestamp.round()
      });
      final row = await insert.select("id").single();
      event.onCreated(row["id"] as int);

      await _loadAndEmit(emit: emit);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onDelete(DeleteFeatureSet event, Emitter<FeatureSetsState> emit) async {
    try {
      final table = client.from("feature_sets");
      await table.delete().eq("id", event.id);
      await _loadAndEmit(emit: emit);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _loadAndEmit({required Emitter<FeatureSetsState> emit}) async {
    final table = client.from("feature_sets");
    final query = table.select("id, last_edited, title, status");
    final rows = await query.order("last_edited", ascending: false);

    final summaries = <FeatureSetSummary>[];
    for (final row in rows) {
      final summary = FeatureSetSummary.fromJson(row);
      summaries.add(summary);
    }

    final newState = FeatureSetsLoaded(summaries: summaries);
    emit(newState);
  }

  void _emitError({required Emitter<FeatureSetsState> emit, required Object error}) {
    final message = error.toString();
    late final FeatureSetsState newState;

    if (state is FeatureSetsLoaded) {
      newState = FeatureSetsLoaded(
        summaries: [...(state as FeatureSetsLoaded).summaries],
        errorMessage: message
      );
    } else {
      newState = FeatureSetsError(message: message);
    }

    emit(newState);
  }

}
*/
