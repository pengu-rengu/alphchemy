import "package:alphchemy/model/results.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class ResultsEvent {
  const ResultsEvent();
}

class LoadResults extends ResultsEvent {
  final int experimentId;

  const LoadResults({required this.experimentId});
}

class SelectFold extends ResultsEvent {
  final int foldIdx;

  const SelectFold({required this.foldIdx});
}

class ShowResultsError extends ResultsEvent {
  final String message;

  const ShowResultsError({required this.message});
}

sealed class ResultsState {
  const ResultsState();
}

class ResultsInitial extends ResultsState {
  const ResultsInitial();
}

class ResultsLoaded extends ResultsState {
  final int experimentId;
  final ExperimentResults results;
  final int foldIdx;
  final String? errorMessage;

  const ResultsLoaded({
    required this.experimentId,
    required this.results,
    required this.foldIdx,
    this.errorMessage
  });
}

class ResultsError extends ResultsState {
  final String message;

  const ResultsError({required this.message});
}

class ResultsBloc extends Bloc<ResultsEvent, ResultsState> {
  final SupabaseClient client;

  ResultsBloc({required this.client}) : super(const ResultsInitial()) {
    on<LoadResults>(_onLoad);
    on<SelectFold>(_onSelectFold);
    on<ShowResultsError>(_onShowError);
  }

  Future<void> _onLoad(LoadResults event, Emitter<ResultsState> emit) async {
    try {
      final table = client.from("experiments");
      final query = table.select("title, results, source");
      final json = await query.eq("id", event.experimentId).single();

      final results =  ExperimentResults.fromJson(json);
      _emitLoaded(emit: emit, experimentId: event.experimentId, results: results, foldIdx: 0);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onShowError(ShowResultsError event, Emitter<ResultsState> emit) {
    _emitError(emit: emit, error: event.message);
  }

  void _onSelectFold(SelectFold event, Emitter<ResultsState> emit) {
    if (state is! ResultsLoaded) return;

    final loaded = state as ResultsLoaded;
    _emitLoaded(emit: emit, experimentId: loaded.experimentId, results: loaded.results, foldIdx: event.foldIdx);
  }

  void _emitLoaded({required Emitter<ResultsState> emit, required int experimentId, required ExperimentResults results, required int foldIdx}) {
    
    final folds = results.folds;
    if (folds.elementAtOrNull(foldIdx) == null) {
      _emitError(emit: emit, error: "fold index out of range: $foldIdx");
    } else {
      final newState = ResultsLoaded(
        experimentId: experimentId,
        results: results,
        foldIdx: foldIdx
      );
      emit(newState);
    }
  }

  void _emitError({required Emitter<ResultsState> emit, required Object error}) {
    late final ResultsState newState;

    if (state is ResultsLoaded) {
      final loaded = state as ResultsLoaded;
      newState = ResultsLoaded(
        experimentId: loaded.experimentId,
        results: loaded.results,
        foldIdx: loaded.foldIdx,
        errorMessage: error.toString()
      );
    } else {
      newState = ResultsError(message: error.toString());
    }

    emit(newState);
  }
}
