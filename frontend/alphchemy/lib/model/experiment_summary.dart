enum ExperimentStatus {
  queued, running, completed, errored;

  const ExperimentStatus();

  factory ExperimentStatus.fromJson(dynamic value) {
    return switch (value) {
      "queued" => ExperimentStatus.queued,
      "running" => ExperimentStatus.running,
      "completed" => ExperimentStatus.completed,
      "errored" => ExperimentStatus.errored,
      _ => throw StateError("invalid experiment status: $value")
    };
  }
}

class ExperimentSummary {
  final int id;
  final DateTime lastEdited;
  final String title;
  final ExperimentStatus status;
  final String? errorMessage;
  /*
  final String? network;
  final int? features;
  final int? nodes;
  final int? folds;
  */

  const ExperimentSummary({required this.id, required this.lastEdited, required this.title, required this.status, required this.errorMessage /*, required this.network, required this.features, required this.nodes, required this.folds */});

  factory ExperimentSummary.fromJson(Map<String, dynamic> json) {
    final lastEdited = DateTime.parse(json["last_edited"] as String);
    final title = json["title"] as String;
    final status = ExperimentStatus.fromJson(json["status"]);

    final results = json["results"];
    final errorMessage = results is Map<String, dynamic> ? results["error"] as String? : null;

    /*
    final experiment = json["experiment"] as Map<String, dynamic>?;
    final strategy = experiment?["strategy"] as Map<String, dynamic>?;
    final baseNet = strategy?["base_net"] as Map<String, dynamic>?;
    final feats = strategy?["feats"] as List<dynamic>?;
    final netNodes = baseNet?["nodes"] as List<dynamic>?;
    */

    return ExperimentSummary(
      id: json["id"] as int,
      lastEdited: lastEdited,
      title: title,
      status: status,
      errorMessage: errorMessage
      /*
      network: baseNet?["type"] as String?,
      features: feats?.length,
      nodes: netNodes?.length,
      folds: experiment?["cv_folds"] as int?
      */
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "last_edited": lastEdited.toIso8601String(),
      "title": title,
      "status": status.name,
      "error_message": errorMessage
      /*
      "network": network,
      "features": features,
      "nodes": nodes,
      "folds": folds
      */
    };
  }
}
