import "dart:async";

import "package:alphchemy/model/feature_set/feature_set.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/utils.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class FeatureSetEvent {
  const FeatureSetEvent();
}

class SubscribeToFeatureSet extends FeatureSetEvent {
  final int id;

  const SubscribeToFeatureSet({required this.id});
}

class UpdateFeatureSet extends FeatureSetEvent {
  final Map<String, dynamic> row;

  const UpdateFeatureSet({required this.row});
}

class ShowFeatureSetError extends FeatureSetEvent {
  final String message;

  const ShowFeatureSetError({required this.message});
}

class AddFeature extends FeatureSetEvent {
  final NodeType nodeType;

  const AddFeature({required this.nodeType});
}

class DeleteFeature extends FeatureSetEvent {
  final String nodeId;

  const DeleteFeature({required this.nodeId});
}

class UpdateStartTimestamp extends FeatureSetEvent {
  final double value;

  const UpdateStartTimestamp({required this.value});
}

class UpdateEndTimestamp extends FeatureSetEvent {
  final double value;

  const UpdateEndTimestamp({required this.value});
}

class UpdateFeature extends FeatureSetEvent {
  final String nodeId;
  final NodeData feature;

  const UpdateFeature({required this.nodeId, required this.feature});
}

class RenameFeatureSet extends FeatureSetEvent {
  final String title;

  const RenameFeatureSet({required this.title});
}

class RequestValues extends FeatureSetEvent {
  const RequestValues();
}

sealed class FeatureSetState {
  const FeatureSetState();
}

class FeatureSetInitial extends FeatureSetState {
  const FeatureSetInitial();
}


class FeatureSetError extends FeatureSetState {
  final String message;

  const FeatureSetError({required this.message});
}

class FeatureSetLoaded extends FeatureSetState {
  final FeatureSet featureSet;
  final bool stale;
  final String? errorMessage;

  const FeatureSetLoaded({required this.featureSet, required this.stale, this.errorMessage});
}

class FeatureSetBloc extends Bloc<FeatureSetEvent, FeatureSetState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  FeatureSetBloc({required this.client}) : super(const FeatureSetInitial()) {
    on<SubscribeToFeatureSet>(_onSubscribe);
    on<UpdateFeatureSet>(_onUpdate);
    on<ShowFeatureSetError>(_onError);
    on<AddFeature>(_onAddFeature);
    on<DeleteFeature>(_onDeleteFeature);
    on<UpdateStartTimestamp>(_onUpdateStartTimestamp);
    on<UpdateEndTimestamp>(_onUpdateEndTimestamp);
    on<UpdateFeature>(_onUpdateFeature);
    on<RenameFeatureSet>(_onRename);
    on<RequestValues>(_onRequest);
  }

  Future<void> _onSubscribe(SubscribeToFeatureSet event, Emitter<FeatureSetState> emit) async {
    await _streamSubscription?.cancel();

    try {
      final table = client.from("feature_sets");
      final stream = table.stream(primaryKey: ["id"]);
      final filtered = stream.eq("id", event.id);
      final single = filtered.limit(1);

      _streamSubscription = single.listen(
        (rows) {
          if (rows.isEmpty) {
            add(const ShowFeatureSetError(message: "Feature set not found or not visible"));
            return;
          }


          add(UpdateFeatureSet(row: rows.first));
        },
        onError: (error) {
          final event = ShowFeatureSetError(message: error.toString());
          add(event);
        }
      );
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onUpdate(UpdateFeatureSet event, Emitter<FeatureSetState> emit) {
    try {
      final featureSet = FeatureSet.fromJson(event.row);
      final errorMessage = featureSet.values?.error;
      final newState = FeatureSetLoaded(featureSet: featureSet, stale: false, errorMessage: errorMessage);
      emit(newState);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onError(ShowFeatureSetError event, Emitter<FeatureSetState> emit) {
    _emitError(emit: emit, error: event.message);
  }

  void _onAddFeature(AddFeature event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    try {
      final loaded = state as FeatureSetLoaded;
      final newFeatureSet = loaded.featureSet.copy();
      newFeatureSet.feats.add(event.nodeType.emptyNode());

      _emitFeatureSet(emit: emit, featureSet: newFeatureSet, stale: true, errorMessage: loaded.errorMessage);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onDeleteFeature(DeleteFeature event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    try {
      final loaded = state as FeatureSetLoaded;
      final newFeatureSet = loaded.featureSet.copy();

      bool matchesId(NodeData feat) => feat.nodeId == event.nodeId;
      newFeatureSet.feats.removeWhere(matchesId);

      _emitFeatureSet(emit: emit, featureSet: newFeatureSet, stale: true, errorMessage: loaded.errorMessage);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onUpdateStartTimestamp(UpdateStartTimestamp event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    try {
      final loaded = state as FeatureSetLoaded;
      final newFeatureSet = loaded.featureSet.copy();
      newFeatureSet.startTimestamp = event.value;
      _emitFeatureSet(emit: emit, featureSet: newFeatureSet, stale: true, errorMessage: loaded.errorMessage);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onUpdateEndTimestamp(UpdateEndTimestamp event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    try {
      final loaded = state as FeatureSetLoaded;
      final newFeatureSet = loaded.featureSet.copy();
      newFeatureSet.endTimestamp = event.value;
      _emitFeatureSet(emit: emit, featureSet: newFeatureSet, stale: true, errorMessage: loaded.errorMessage);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onUpdateFeature(UpdateFeature event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    try {
      final loaded = state as FeatureSetLoaded;
      final newFeatureSet = loaded.featureSet.copy();

      final feats = newFeatureSet.feats;
      bool matchesId(NodeData feat) => feat.nodeId == event.nodeId;
      final idx = feats.indexWhere(matchesId);
      if (idx == -1) {
        _emitError(emit: emit, error: "Feature not found");
        return;
      }

      feats[idx] = event.feature;

      _emitFeatureSet(emit: emit, featureSet: newFeatureSet, stale: true, errorMessage: loaded.errorMessage);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onRename(RenameFeatureSet event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    try {
      final loaded = state as FeatureSetLoaded;
      final newFeatureSet = loaded.featureSet.copy();
      newFeatureSet.title = cleanTitle(event.title);

      _emitFeatureSet(emit: emit, featureSet: newFeatureSet, stale: true, errorMessage: loaded.errorMessage);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onRequest(RequestValues event, Emitter<FeatureSetState> emit) async {
    if (state is! FeatureSetLoaded) return;
    try {
      final newFeatureSet = _copyFeatureSet();

      newFeatureSet.status = FeatureSetStatus.working;
      _emitFeatureSet(emit: emit, featureSet: newFeatureSet, stale: false);

      await client.from("feature_sets").update({
        "title": newFeatureSet.title,
        "features": newFeatureSet.featsToJson(),
        "start_timestamp": newFeatureSet.startTimestamp.round(),
        "end_timestamp": newFeatureSet.endTimestamp.round(),
        "values": null,
        "status": "working",
        "last_edited": DateTime.now().toUtc().toIso8601String()
      }).eq("id", newFeatureSet.id);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  FeatureSet _copyFeatureSet() {
    return (state as FeatureSetLoaded).featureSet.copy();
  }

  void _emitFeatureSet({required Emitter<FeatureSetState> emit, required FeatureSet featureSet, required bool stale, String? errorMessage}) {
    final newState = FeatureSetLoaded(featureSet: featureSet, stale: stale, errorMessage: errorMessage);
    emit(newState);
  }

  void _emitError({required Emitter<FeatureSetState> emit, required Object error}) {
    if (state is FeatureSetLoaded) {
      final loaded = state as FeatureSetLoaded;
      final newState = FeatureSetLoaded(
        featureSet: loaded.featureSet.copy(),
        stale: loaded.stale,
        errorMessage: error.toString()
      );
      emit(newState);
      return;
    }

    final newState = FeatureSetError(message: error.toString());
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
