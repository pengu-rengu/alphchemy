import "package:flutter_bloc/flutter_bloc.dart";

sealed class EditorEvent {
  const EditorEvent();
}

class UpdateExperimentSource extends EditorEvent {
  final String text;

  const UpdateExperimentSource({required this.text});
}

class ShowEditorError extends EditorEvent {
  final String message;

  const ShowEditorError({required this.message});
}

class EditorState {
  final String source;
  final String? errorMessage;

  const EditorState({required this.source, this.errorMessage});
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({String? source}) : super(EditorState(source: source ?? "")) {
    on<UpdateExperimentSource>(_onUpdateSource);
    on<ShowEditorError>(_onShowError);
  }

  void _onUpdateSource(UpdateExperimentSource event, Emitter<EditorState> emit) {
    final newState = EditorState(source: event.text);
    emit(newState);
  }

  void _onShowError(ShowEditorError event, Emitter<EditorState> emit) {
    final newState = EditorState(source: state.source, errorMessage: event.message);
    emit(newState);
  }
}
