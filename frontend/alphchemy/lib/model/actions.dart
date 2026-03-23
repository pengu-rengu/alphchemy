import 'package:alphchemy/model/json_helpers.dart';
import 'package:alphchemy/model/network.dart';

class ThresholdRange {
  final String featId;
  final double min;
  final double max;

  ThresholdRange({
    required this.featId,
    required this.min,
    required this.max
  });

  factory ThresholdRange.fromJson(Map<String, dynamic> json) {
    final featId = json['feat_id'] as String;
    final min = doubleFromJson(json['min']);
    final max = doubleFromJson(json['max']);
    return ThresholdRange(featId: featId, min: min, max: max);
  }

  Map<String, dynamic> toJson() {
    return {
      'feat_id': featId,
      'min': min,
      'max': max
    };
  }
}

ThresholdRange thresholdRangeFromDynamic(dynamic val) {
  final map = val as Map<String, dynamic>;
  return ThresholdRange.fromJson(map);
}

class MetaAction {
  final String label;
  final List<String> subActions;

  MetaAction({
    required this.label,
    required this.subActions
  });

  factory MetaAction.fromJson(Map<String, dynamic> json) {
    final label = json['label'] as String;
    final rawSubActions = json['sub_actions'] as List<dynamic>;
    final subActions = List<String>.from(rawSubActions);
    return MetaAction(label: label, subActions: subActions);
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'sub_actions': subActions
    };
  }
}

MetaAction metaActionFromDynamic(dynamic val) {
  final map = val as Map<String, dynamic>;
  return MetaAction.fromJson(map);
}

class LogicActions {
  final List<MetaAction> metaActions;
  final List<ThresholdRange> thresholds;
  final int nThresholds;
  final bool allowRecurrence;
  final List<Gate> allowedGates;

  LogicActions({
    required this.metaActions,
    required this.thresholds,
    required this.nThresholds,
    required this.allowRecurrence,
    required this.allowedGates
  });

  factory LogicActions.fromJson(Map<String, dynamic> json) {
    final rawMetaActions = json['meta_actions'] as List<dynamic>;
    final metaActions = listFromJson(rawMetaActions, metaActionFromDynamic);
    final rawThresholds = json['thresholds'] as List<dynamic>;
    final thresholds = listFromJson(rawThresholds, thresholdRangeFromDynamic);
    final nThresholds = json['n_thresholds'] as int;
    final allowRecurrence = json['allow_recurrence'] as bool;
    final rawGates = json['allowed_gates'] as List<dynamic>;
    final allowedGates = listFromJson(rawGates, gateFromDynamic);
    return LogicActions(
      metaActions: metaActions,
      thresholds: thresholds,
      nThresholds: nThresholds,
      allowRecurrence: allowRecurrence,
      allowedGates: allowedGates
    );
  }

  Map<String, dynamic> toJson() {
    final metaActionsList = listFromJson(metaActions, (ma) => ma.toJson());
    final thresholdsList = listFromJson(thresholds, (tr) => tr.toJson());
    final gatesList = listFromJson(allowedGates, (gate) => gate.toJson());
    return {
      'meta_actions': metaActionsList,
      'thresholds': thresholdsList,
      'n_thresholds': nThresholds,
      'allow_recurrence': allowRecurrence,
      'allowed_gates': gatesList
    };
  }
}

class DecisionActions {
  final List<MetaAction> metaActions;
  final List<ThresholdRange> thresholds;
  final int nThresholds;
  final bool allowRefs;

  DecisionActions({
    required this.metaActions,
    required this.thresholds,
    required this.nThresholds,
    required this.allowRefs
  });

  factory DecisionActions.fromJson(Map<String, dynamic> json) {
    final rawMetaActions = json['meta_actions'] as List<dynamic>;
    final metaActions = listFromJson(rawMetaActions, metaActionFromDynamic);
    final rawThresholds = json['thresholds'] as List<dynamic>;
    final thresholds = listFromJson(rawThresholds, thresholdRangeFromDynamic);
    final nThresholds = json['n_thresholds'] as int;
    final allowRefs = json['allow_refs'] as bool;
    return DecisionActions(
      metaActions: metaActions,
      thresholds: thresholds,
      nThresholds: nThresholds,
      allowRefs: allowRefs
    );
  }

  Map<String, dynamic> toJson() {
    final metaActionsList = listFromJson(metaActions, (ma) => ma.toJson());
    final thresholdsList = listFromJson(thresholds, (tr) => tr.toJson());
    return {
      'meta_actions': metaActionsList,
      'thresholds': thresholdsList,
      'n_thresholds': nThresholds,
      'allow_refs': allowRefs
    };
  }
}
