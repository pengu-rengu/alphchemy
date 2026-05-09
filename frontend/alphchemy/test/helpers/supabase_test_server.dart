import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:supabase_flutter/supabase_flutter.dart";

class SupabaseTestResponse {
  final int statusCode;
  final Object? body;

  const SupabaseTestResponse({
    required this.body,
    this.statusCode = HttpStatus.ok
  });
}

class SupabaseTestRequest {
  final String method;
  final String path;
  final Map<String, String> query;
  final Object? body;

  const SupabaseTestRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body
  });
}

class SupabaseTestServer {
  final HttpServer _server;
  final Queue<SupabaseTestResponse> _responses;
  final List<SupabaseTestRequest> requests;

  SupabaseTestServer._({
    required HttpServer server,
    required Queue<SupabaseTestResponse> responses
  })  : _server = server,
        _responses = responses,
        requests = <SupabaseTestRequest>[];

  static Future<SupabaseTestServer> start(List<SupabaseTestResponse> responses) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final responseQueue = Queue<SupabaseTestResponse>.from(responses);
    final testServer = SupabaseTestServer._(
      server: server,
      responses: responseQueue
    );
    testServer._start();
    return testServer;
  }

  String get baseUrl {
    final host = _server.address.host;
    final port = _server.port;
    return "http://$host:$port";
  }

  SupabaseClient createClient() {
    return SupabaseClient(baseUrl, "test-key");
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  void _start() {
    _listen();
  }

  Future<void> _listen() async {
    await for (final request in _server) {
      await _handleRequest(request);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final bodyStream = utf8.decoder.bind(request);
    final bodyText = await bodyStream.join();
    final body = _decodeBody(bodyText);
    final query = Map<String, String>.from(request.uri.queryParameters);
    final testRequest = SupabaseTestRequest(
      method: request.method,
      path: request.uri.path,
      query: query,
      body: body
    );
    requests.add(testRequest);

    final response = _nextResponse();
    request.response.statusCode = response.statusCode;
    request.response.headers.contentType = ContentType.json;
    final responseBody = jsonEncode(response.body);
    request.response.write(responseBody);
    await request.response.close();
  }

  SupabaseTestResponse _nextResponse() {
    if (_responses.isEmpty) {
      return const SupabaseTestResponse(body: <Object>[]);
    }

    return _responses.removeFirst();
  }

  Object? _decodeBody(String bodyText) {
    if (bodyText.isEmpty) {
      return null;
    }

    return jsonDecode(bodyText) as Object?;
  }
}
