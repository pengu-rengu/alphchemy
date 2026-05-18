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

    return ReportSubmission(title: title, report: submission["report"] as String);
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

class ReportSubmission extends Submission {
  final String report;

  const ReportSubmission({required super.title, required this.report});

  @override
  String get type => "report";

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "report",
      "submission": {"title": title, "report": report}
    };
  }
}
