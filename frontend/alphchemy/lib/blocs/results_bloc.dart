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

sealed class ResultsState {
  const ResultsState();
}

class ResultsInitial extends ResultsState {
  const ResultsInitial();
}

class ResultsLoaded extends ResultsState {
  final ExperimentResults results;
  final int selectedFoldIdx;

  const ResultsLoaded({
    required this.results,
    required this.selectedFoldIdx
  });

  /*
  ResultsLoaded copyWith({ExperimentResults? results, int? selectedFoldIdx}) {
    return ResultsLoaded(
      results: results ?? this.results,
      selectedFoldIdx: selectedFoldIdx ?? this.selectedFoldIdx
    );
  }
  */
}

class ResultsError extends ResultsState {
  final String message;

  const ResultsError({required this.message});
}

class ResultsBloc extends Bloc<ResultsEvent, ResultsState> {
  final SupabaseClient client;

  ResultsBloc({required this.client})
      : super(const ResultsInitial()) {
    on<LoadResults>(_onLoad);
    on<SelectFold>(_onSelectFold);
  }

  Future<void> _onLoad(LoadResults event, Emitter<ResultsState> emit) async {
    late ResultsState newState;

    try {
      final results = await _loadResults(event.experimentId);
      newState = ResultsLoaded(results: results, selectedFoldIdx: 0);
    } catch (error) {
      newState = ResultsError(message: error.toString());
    } finally {
      emit(newState);
    }
  }

  Future<ExperimentResults> _loadResults(int experimentId) async {
    final table = client.from("experiments");
    final query = table.select("results, experiment");
    final json = await query.eq("id", experimentId).single();
    return ExperimentResults.fromJson(json);
  }

  void _onSelectFold(SelectFold event, Emitter<ResultsState> emit) {
    if (state is! ResultsLoaded) {
      return;
    }

    final loadedState = state as ResultsLoaded;
    final folds = loadedState.results.folds;
    if (folds == null) {
      return;
    }

    final foldIdx = event.foldIdx;
    if (foldIdx < 0) {
      return;
    }
    if (foldIdx >= folds.length) {
      return;
    }

    final newState = ResultsLoaded(results: loadedState.results, selectedFoldIdx: foldIdx);
    emit(newState);
  }
}
