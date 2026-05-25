import "dart:convert";

import "package:alphchemy/env.dart";
import "package:alphchemy/model/docs/doc_index.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;

sealed class DocsEvent {
  const DocsEvent();
}

class LoadDocs extends DocsEvent {
  const LoadDocs();
}

class SelectDoc extends DocsEvent {
  final String id;

  const SelectDoc({required this.id});
}

sealed class DocsState {
  const DocsState();
}

class DocsInitial extends DocsState {
  const DocsInitial();
}

class DocsError extends DocsState {
  final String message;

  const DocsError({required this.message});
}

class DocsLoaded extends DocsState {
  final DocsIndex index;
  final String activeId;
  final String body;

  const DocsLoaded({required this.index, required this.activeId, required this.body});
}

class DocsBloc extends Bloc<DocsEvent, DocsState> {
  final http.Client httpClient;

  DocsBloc({required this.httpClient}) : super(const DocsInitial()) {
    on<LoadDocs>(_onLoad);
    on<SelectDoc>(_onSelect);
  }

  Future<void> _onLoad(LoadDocs event, Emitter<DocsState> emit) async {
    try {
      final indexUri = Uri.parse("$docsServerUrl/index");
      final indexResp = await httpClient.get(indexUri);
      if (indexResp.statusCode != 200) {
        final errorState = DocsError(message: "Index HTTP ${indexResp.statusCode}");
        emit(errorState);
        return;
      }
      final indexText = utf8.decode(indexResp.bodyBytes);
      final indexJson = jsonDecode(indexText) as Map<String, dynamic>;
      final docsIndex = DocsIndex.fromJson(indexJson);

      final firstDocId = docsIndex.groups.entries.first.value.first;

      final bodyUri = Uri.parse("$docsServerUrl/doc/$firstDocId");
      final bodyResp = await httpClient.get(bodyUri);
      if (bodyResp.statusCode != 200) {
        _emitError(emit: emit, error: "HTTP ${bodyResp.statusCode} $firstDocId");
        return;
      }
      final body = utf8.decode(bodyResp.bodyBytes);

      final newState = DocsLoaded(index: docsIndex, activeId: firstDocId, body: body);
      emit(newState);
    } catch (error) {
      final errorState = DocsError(message: error.toString());
      emit(errorState);
    }
  }

  Future<void> _onSelect(SelectDoc event, Emitter<DocsState> emit) async {
    if (state is! DocsLoaded) {
      return;
    }
    try {
      final uri = Uri.parse("$docsServerUrl/doc/${event.id}");
      final response = await httpClient.get(uri);
      if (response.statusCode != 200) {
        _emitError(emit: emit, error: "HTTP ${response.statusCode} ${event.id}");
        return;
      }
      final body = utf8.decode(response.bodyBytes);

      final loaded = DocsLoaded(
        index: (state as DocsLoaded).index.copy(),
        activeId: event.id,
        body: body
      );
      emit(loaded);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _emitError({required Emitter<DocsState> emit, required Object error}) {
    final newState = DocsError(message: error.toString());
    emit(newState);
  }
}
