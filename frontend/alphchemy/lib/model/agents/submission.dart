sealed class Submission {
  final String title;

  const Submission({required this.title});

  factory Submission.fromJson(Map<String, dynamic> json) {
    final type = json["type"] as String;
    final submission = json["submission"] as Map<String, dynamic>;
    final title = submission["title"] as String;

    if (type == "experiment") {
      return ExperimentSubmission(title: title, experimentJson: submission["experiment"] as Map<String, dynamic>);
    }

    return NotebookSubmission(title: title, notebookJson: submission);
  }

  String get type;

  Map<String, dynamic> toJson();
}

class ExperimentSubmission extends Submission {
  final Map<String, dynamic> experimentJson;
  
  const ExperimentSubmission({required super.title, required this.experimentJson});

  @override
  String get type => "experiment";

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "experiment",
      "submission": {"title": title, "experiment": experimentJson}
    };
  }
}

class NotebookSubmission extends Submission {
  final Map<String, dynamic> notebookJson;

  const NotebookSubmission({required super.title, required this.notebookJson});

  @override
  String get type => "notebook";

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "notebook",
      "submission": notebookJson
    };
  }
}
