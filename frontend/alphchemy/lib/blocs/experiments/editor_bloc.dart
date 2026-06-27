import "package:flutter_bloc/flutter_bloc.dart";

sealed class EditorEvent {
  const EditorEvent();
}

class UpdateExperimentJson extends EditorEvent {
  final String text;

  const UpdateExperimentJson({required this.text});
}

class ShowEditorError extends EditorEvent {
  final String message;

  const ShowEditorError({required this.message});
}

class EditorState {
  final String jsonText;
  final String? errorMessage;

  const EditorState({required this.jsonText, this.errorMessage});
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({String? experiment}) : super(EditorState(jsonText: experiment ?? "{}")) {
    on<UpdateExperimentJson>(_onUpdateJson);
    on<ShowEditorError>(_onShowError);
  }

  void _onUpdateJson(UpdateExperimentJson event, Emitter<EditorState> emit) {
    final newState = EditorState(jsonText: event.text);
    emit(newState);
  }

  void _onShowError(ShowEditorError event, Emitter<EditorState> emit) {
    final newState = EditorState(jsonText: state.jsonText, errorMessage: event.message);
    emit(newState);
  }
}
