import "package:alphchemy/objects/param_space.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class ParamSpaceEvent {
  const ParamSpaceEvent();
}

class LoadParams extends ParamSpaceEvent {
  final Map<String, List<dynamic>> searchSpace;

  const LoadParams({required this.searchSpace});
}

class AddParam extends ParamSpaceEvent {
  final ParamDef param;

  const AddParam({required this.param});
}

class UpdateParam extends ParamSpaceEvent {
  final String oldName;
  final ParamDef param;

  const UpdateParam({required this.oldName, required this.param});
}

class RemoveParam extends ParamSpaceEvent {
  final String name;

  const RemoveParam({required this.name});
}

class ParamSpaceState {
  final Map<String, ParamDef> params;

  const ParamSpaceState({this.params = const {}});

  Map<String, List<dynamic>> toSearchSpace() {
    final result = <String, List<dynamic>>{};
    for (final entry in params.entries) {
      result[entry.key] = entry.value.values;
    }
    return result;
  }

  List<ParamDef> paramsOfType(ParamType type) {
    final matching = params.values.where((def) => def.type == type);
    return matching.toList();
  }
}

class ParamSpaceBloc extends Bloc<ParamSpaceEvent, ParamSpaceState> {
  ParamSpaceBloc() : super(const ParamSpaceState()) {
    on<LoadParams>(_onLoad);
    on<AddParam>(_onAdd);
    on<UpdateParam>(_onUpdate);
    on<RemoveParam>(_onRemove);
  }

  void _onLoad(LoadParams event, Emitter<ParamSpaceState> emit) {
    final params = <String, ParamDef>{};
    for (final entry in event.searchSpace.entries) {
      final type = inferParamType(entry.value);
      params[entry.key] = ParamDef(
        name: entry.key,
        type: type,
        values: entry.value
      );
    }
    emit(ParamSpaceState(params: params));
  }

  void _onAdd(AddParam event, Emitter<ParamSpaceState> emit) {
    final updated = Map<String, ParamDef>.from(state.params);
    updated[event.param.name] = event.param;
    emit(ParamSpaceState(params: updated));
  }

  void _onUpdate(UpdateParam event, Emitter<ParamSpaceState> emit) {
    final updated = Map<String, ParamDef>.from(state.params);
    updated.remove(event.oldName);
    updated[event.param.name] = event.param;
    emit(ParamSpaceState(params: updated));
  }

  void _onRemove(RemoveParam event, Emitter<ParamSpaceState> emit) {
    final updated = Map<String, ParamDef>.from(state.params);
    updated.remove(event.name);
    emit(ParamSpaceState(params: updated));
  }
}
