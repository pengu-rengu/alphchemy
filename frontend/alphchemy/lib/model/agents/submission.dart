sealed class Submission {
  final String title;

  const Submission({required this.title});

  factory Submission.fromJson(Map<String, dynamic> json) {
    final submission = json["submission"] as Map<String, dynamic>;
    final title = submission["title"] as String;

    if (json["type"] as String == "experiment") {
      return ExperimentSubmission(title: title, source: submission["source"] as String);
    }
    return NotebookSubmission(title: title, notebookJson: submission);
  }

  String get type;

  Map<String, dynamic> toJson();
}

class ExperimentSubmission extends Submission {
  final String source;

  const ExperimentSubmission({required super.title, required this.source});

  @override
  String get type => "experiment";

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "experiment",
      "submission": {"title": title, "source": source}
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
