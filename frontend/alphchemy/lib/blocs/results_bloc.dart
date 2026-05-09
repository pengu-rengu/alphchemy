import "package:alphchemy/model/results_data.dart";
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
  final int foldIndex;

  const SelectFold({required this.foldIndex});
}

sealed class ResultsState {
  const ResultsState();
}

class ResultsInitial extends ResultsState {
  const ResultsInitial();
}

class ResultsLoaded extends ResultsState {
  final ExperimentResultsRecord record;
  final int selectedFoldIndex;

  const ResultsLoaded({
    required this.record,
    required this.selectedFoldIndex
  });

  ResultsLoaded copyWith({
    ExperimentResultsRecord? record,
    int? selectedFoldIndex
  }) {
    return ResultsLoaded(
      record: record ?? this.record,
      selectedFoldIndex: selectedFoldIndex ?? this.selectedFoldIndex
    );
  }
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
      final record = await _loadResults(event.experimentId);
      newState = ResultsLoaded(
        record: record,
        selectedFoldIndex: 0
      );
    } catch (err) {
      newState = ResultsError(message: err.toString());
    } finally {
      emit(newState);
    }
  }

  Future<ExperimentResultsRecord> _loadResults(int experimentId) async {
    final table = client.from("experiments");
    final query = table.select("results");
    final filtered = query.eq("id", experimentId);
    final row = await filtered.single();
    final json = Map<String, dynamic>.from(row);
    return ExperimentResultsRecord.fromJson(json);
  }

  void _onSelectFold(SelectFold event, Emitter<ResultsState> emit) {
    final currentState = state;
    if (currentState is! ResultsLoaded) {
      return;
    }

    final folds = currentState.record.folds;
    if (folds == null) {
      return;
    }

    final foldCount = folds.length;
    if (event.foldIndex < 0) {
      return;
    }
    if (event.foldIndex >= foldCount) {
      return;
    }

    final newState = currentState.copyWith(
      selectedFoldIndex: event.foldIndex
    );
    emit(newState);
  }
}
