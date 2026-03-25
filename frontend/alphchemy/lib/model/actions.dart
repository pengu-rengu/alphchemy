import 'package:alphchemy/model/network.dart';
import 'package:alphchemy/model/node_object.dart';

class ThresholdRange extends NodeObject {
  String featId;
  double min;
  double max;

  @override
  String get nodeType => 'threshold_range';

  ThresholdRange({required this.featId, required this.min, required this.max});
}

class MetaAction extends NodeObject {
  String label;
  List<String> subActions;

  @override
  String get nodeType => 'meta_action';

  MetaAction({required this.label, required this.subActions});
}

class LogicActions extends NodeObject {
  List<String> metaActionIds;
  List<String> thresholdIds;
  int nThresholds;
  bool allowRecurrence;
  List<Gate> allowedGates;

  @override
  String get nodeType => 'logic_actions';

  LogicActions({
    required this.metaActionIds,
    required this.thresholdIds,
    required this.nThresholds,
    required this.allowRecurrence,
    required this.allowedGates
  });
}

class DecisionActions extends NodeObject {
  List<String> metaActionIds;
  List<String> thresholdIds;
  int nThresholds;
  bool allowRefs;

  @override
  String get nodeType => 'decision_actions';

  DecisionActions({
    required this.metaActionIds,
    required this.thresholdIds,
    required this.nThresholds,
    required this.allowRefs
  });
}
