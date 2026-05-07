import "package:alphchemy/model/results_data.dart";
import "package:alphchemy/repositories/results_repository.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class ResultsEvent {
  const ResultsEvent();
}

class LoadResults extends ResultsEvent {
  const LoadResults();
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
  final ResultsRepository repository;

  ResultsBloc({required this.repository})
      : super(const ResultsInitial()) {
    on<LoadResults>(_onLoad);
    on<SelectFold>(_onSelectFold);
  }

  Future<void> _onLoad(LoadResults event, Emitter<ResultsState> emit) async {
    late ResultsState newState;

    try {
      final record = await repository.load();
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
