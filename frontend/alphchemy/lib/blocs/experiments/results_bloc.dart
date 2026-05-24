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

class ResultsLoading extends ResultsState {
  const ResultsLoading();
}

class ResultsLoaded extends ResultsState {
  final int experimentId;
  final ExperimentResults results;
  final int selectedFoldIdx;

  const ResultsLoaded({
    required this.experimentId,
    required this.results,
    required this.selectedFoldIdx
  });
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
    on<ShowResultsError>(_onShowError);
  }

  Future<void> _onLoad(LoadResults event, Emitter<ResultsState> emit) async {
    emit(const ResultsLoading());

    try {
      final results = await _loadResults(event.experimentId);
      final newState = ResultsLoaded(
        experimentId: event.experimentId,
        results: results,
        selectedFoldIdx: 0
      );
      emit(newState);
    } catch (error) {
      final newState = ResultsError(message: error.toString());
      emit(newState);
    }
  }

  Future<ExperimentResults> _loadResults(int experimentId) async {
    final table = client.from("experiments");
    final query = table.select("title, results, experiment");
    final filtered = query.eq("id", experimentId);
    final json = await filtered.single();
    return ExperimentResults.fromJson(json);
  }

  void _onShowError(ShowResultsError event, Emitter<ResultsState> emit) {
    final newState = ResultsError(message: event.message);
    emit(newState);
  }

  void _onSelectFold(SelectFold event, Emitter<ResultsState> emit) {
    if (state is! ResultsLoaded) {
      return;
    }

    final loaded = state as ResultsLoaded;
    final folds = loaded.results.folds;
    if (folds == null) {
      return;
    }
    
    final newState = ResultsLoaded(
      experimentId: loaded.experimentId,
      results: loaded.results,
      selectedFoldIdx: event.foldIdx
    );
    emit(newState);
  }
}
