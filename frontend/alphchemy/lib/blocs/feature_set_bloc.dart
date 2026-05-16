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

class DisplayFeatureSetError extends FeatureSetEvent {
  final String message;

  const DisplayFeatureSetError({required this.message});
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

class FeatureSetLoading extends FeatureSetState {
  const FeatureSetLoading();
}

class FeatureSetError extends FeatureSetState {
  final String message;

  const FeatureSetError({required this.message});
}

class FeatureSetLoaded extends FeatureSetState {
  final FeatureSet featureSet;

  const FeatureSetLoaded({required this.featureSet});
}

class FeatureSetBloc extends Bloc<FeatureSetEvent, FeatureSetState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  FeatureSetBloc({required this.client}) : super(const FeatureSetInitial()) {
    on<SubscribeToFeatureSet>(_onSubscribe);
    on<UpdateFeatureSet>(_onUpdate);
    on<DisplayFeatureSetError>(_onError);
    on<AddFeature>(_onAddFeature);
    on<DeleteFeature>(_onDeleteFeature);
    on<UpdateStartTimestamp>(_onUpdateStartTimestamp);
    on<UpdateEndTimestamp>(_onUpdateEndTimestamp);
    on<UpdateFeature>(_onUpdateFeature);
    on<RenameFeatureSet>(_onRename);
    on<RequestValues>(_onRequest);
  }

  Future<void> _onSubscribe(SubscribeToFeatureSet event, Emitter<FeatureSetState> emit) async {
    emit(const FeatureSetLoading());
    await _streamSubscription?.cancel();

    try {
      final table = client.from("feature_sets");
      final stream = table.stream(primaryKey: ["id"]);
      final filtered = stream.eq("id", event.id);
      final single = filtered.limit(1);

      _streamSubscription = single.listen(
        (rows) {
          if (rows.isEmpty) {
            add(const DisplayFeatureSetError(message: "Feature set not found or not visible"));
            return;
          }


          add(UpdateFeatureSet(row: rows.first));
        },
        onError: (error) {
          final event = DisplayFeatureSetError(message: error.toString());
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
      _emitFeatureSet(emit: emit, featureSet: featureSet);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onError(DisplayFeatureSetError event, Emitter<FeatureSetState> emit) {
    final newState = FeatureSetError(message: event.message);
    emit(newState);
  }

  void _onAddFeature(AddFeature event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    final newFeatureSet = (state as FeatureSetLoaded).featureSet.copy();
    newFeatureSet.feats.add(event.nodeType.emptyNode());

    _emitFeatureSet(emit: emit, featureSet: newFeatureSet);
  }

  void _onDeleteFeature(DeleteFeature event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    final newFeatureSet = _copyFeatureSet();

    bool matchesId(NodeData feat) => feat.nodeId == event.nodeId;
    newFeatureSet.feats.removeWhere(matchesId);

    _emitFeatureSet(emit: emit, featureSet: newFeatureSet);
  }

  void _onUpdateStartTimestamp(UpdateStartTimestamp event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }

    final newFeatureSet = _copyFeatureSet();
    newFeatureSet.startTimestamp = event.value;
    _emitFeatureSet(emit: emit, featureSet: newFeatureSet);
  }

  void _onUpdateEndTimestamp(UpdateEndTimestamp event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }

    final newFeatureSet = _copyFeatureSet();
    newFeatureSet.endTimestamp = event.value;
    _emitFeatureSet(emit: emit, featureSet: newFeatureSet);
  }

  void _onUpdateFeature(UpdateFeature event, Emitter<FeatureSetState> emit) {
    if (state is! FeatureSetLoaded) {
      return;
    }
    final newFeatureSet = _copyFeatureSet();

    final feats = newFeatureSet.feats;
    bool matchesId(NodeData feat) => feat.nodeId == event.nodeId;
    final idx = feats.indexWhere(matchesId);
    feats[idx] = event.feature;

    _emitFeatureSet(emit: emit, featureSet: newFeatureSet);
  }

  Future<void> _onRename(RenameFeatureSet event, Emitter<FeatureSetState> emit) async {
    if (state is! FeatureSetLoaded) {
      return;
    }
    final loaded = state as FeatureSetLoaded;
    final cleanedTitle = cleanTitle(event.title);

    try {
      await client.from("feature_sets").update({"title": cleanedTitle}).eq("id", loaded.featureSet.id);
    } catch (error) {
      final newState = FeatureSetError(message: error.toString());
      emit(newState);
    }
  }

  Future<void> _onRequest(RequestValues event, Emitter<FeatureSetState> emit) async {
    if (state is! FeatureSetLoaded) return;
    final newFeatureSet = _copyFeatureSet();

    newFeatureSet.status = FeatureSetStatus.working;
    _emitFeatureSet(emit: emit, featureSet: newFeatureSet);

    try {
      await client.from("feature_sets").update({
        "features": newFeatureSet.featsToJson(),
        "start_timestamp": newFeatureSet.startTimestamp.round(),
        "end_timestamp": newFeatureSet.endTimestamp.round(),
        "values": null,
        "status": "working"
      }).eq("id", newFeatureSet.id);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  FeatureSet _copyFeatureSet() {
    return (state as FeatureSetLoaded).featureSet.copy();
  }

  void _emitFeatureSet({required Emitter<FeatureSetState> emit, required FeatureSet featureSet}) {
    final newState = FeatureSetLoaded(featureSet: featureSet);
    emit(newState);
  }

  void _emitError({required Emitter<FeatureSetState> emit, required Object error}) {
    final newState = FeatureSetError(message: error.toString());
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
