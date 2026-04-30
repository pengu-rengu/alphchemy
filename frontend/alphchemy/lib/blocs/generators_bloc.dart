import "package:alphchemy/model/generator_data.dart";
import "package:alphchemy/model/generator_summary.dart";
import "package:alphchemy/repositories/generator_repository.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class GeneratorsEvent {
  const GeneratorsEvent();
}

class LoadGenerators extends GeneratorsEvent {
  const LoadGenerators();
}

class CreateGenerator extends GeneratorsEvent {
  final String id;

  const CreateGenerator({required this.id});
}

class DeleteGenerator extends GeneratorsEvent {
  final String id;

  const DeleteGenerator({required this.id});
}

sealed class GeneratorsState {
  const GeneratorsState();
}

class GeneratorsInitial extends GeneratorsState {
  const GeneratorsInitial();
}

class GeneratorsLoaded extends GeneratorsState {
  final List<GeneratorSummary> generators;

  const GeneratorsLoaded({required this.generators});
}

class GeneratorsError extends GeneratorsState {
  final String message;

  const GeneratorsError({required this.message});
}

class GeneratorsBloc extends Bloc<GeneratorsEvent, GeneratorsState> {
  final GeneratorRepository repository;

  GeneratorsBloc({required this.repository})
      : super(const GeneratorsInitial()) {
    on<LoadGenerators>(_onLoad);
    on<CreateGenerator>(_onCreate);
    on<DeleteGenerator>(_onDelete);
  }

  Future<void> _onLoad(LoadGenerators event, Emitter<GeneratorsState> emit) async {
    try {
      final generators = await repository.loadAll();
      emit(GeneratorsLoaded(generators: generators));
    } catch (err) {
      emit(GeneratorsError(message: err.toString()));
    }
  }

  Future<void> _onCreate(
    CreateGenerator event,
    Emitter<GeneratorsState> emit
  ) async {
    final defaultData = GeneratorData.blank("Untitled");
    try {
      await repository.save(event.id, defaultData);
      final generators = await repository.loadAll();
      emit(GeneratorsLoaded(generators: generators));
    } catch (err) {
      emit(GeneratorsError(message: err.toString()));
    }
  }

  Future<void> _onDelete(DeleteGenerator event, Emitter<GeneratorsState> emit) async {
    try {
      await repository.delete(event.id);
      final generators = await repository.loadAll();
      emit(GeneratorsLoaded(generators: generators));
    } catch (err) {
      emit(GeneratorsError(message: err.toString()));
    }
  }
}
