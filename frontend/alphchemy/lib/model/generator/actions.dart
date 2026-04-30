import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/utils.dart";

class ThresholdRange extends NodeData {
  String id;
  String featId;
  double min;
  double max;

  @override
  NodeType get nodeType => NodeType.thresholdRange;

  @override
  int get fieldCount => 4;

  ThresholdRange({
    this.id = "",
    this.featId = "",
    this.min = 0.0,
    this.max = 0.0,
    super.paramRefs
  });

  factory ThresholdRange.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final featId = getField<String>(json, "feat_id", "", paramRefs);
    final min = getField<double>(json, "min", 0.0, paramRefs, doubleFromJson);
    final max = getField<double>(json, "max", 0.0, paramRefs, doubleFromJson);

    return ThresholdRange(
      id: id,
      featId: featId,
      min: min,
      max: max,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "feat_id":
        featId = text;
      case "min":
        min = double.tryParse(text) ?? 0.0;
      case "max":
        max = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "feat_id" => featId,
      "min" => min.toString(),
      "max" => max.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final featIdJson = assembleField("feat_id", featId);
    final minJson = assembleField("min", min);
    final maxJson = assembleField("max", max);

    return {
      "id": idJson,
      "type": "threshold",
      "feat_id": featIdJson,
      "min": minJson,
      "max": maxJson
    };
  }
}

class MetaAction extends NodeData {
  String id;
  String label;
  List<String> subActions;

  @override
  NodeType get nodeType => NodeType.metaAction;

  @override
  int get fieldCount => 3;

  MetaAction({
    this.id = "",
    this.label = "",
    this.subActions = const [],
    super.paramRefs
  });

  factory MetaAction.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final label = getField<String>(json, "label", "", paramRefs);
    final subActions = getField<List<String>>(json, "sub_actions", const [], paramRefs, listFromJson<String>);

    return MetaAction(
      id: id,
      label: label,
      subActions: subActions,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "label":
        label = text;
      case "sub_actions":
        subActions = parseList(text);
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "label" => label,
      "sub_actions" => subActions.join(", "),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final labelJson = assembleField("label", label);
    final subActionsJson = assembleField("sub_actions", subActions);

    return {
      "id": idJson,
      "type": "meta_action",
      "label": labelJson,
      "sub_actions": subActionsJson
    };
  }
}

class LogicActions extends NodeData {
  List<String> metaActionSelection;
  List<String> thresholdSelection;
  List<String> featOrder;
  int nThresholds;
  bool allowRecurrence;
  List<Gate> allowedGates;
  List<MetaAction> metaActions;
  List<ThresholdRange> thresholds;

  @override
  NodeType get nodeType => NodeType.logicActions;

  @override
  int get fieldCount => 6;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "meta_actions", label: "Meta Action", multi: true, allowedTypes: [NodeType.metaAction]),
      ChildSlot(key: "thresholds", label: "Threshold", multi: true, allowedTypes: [NodeType.thresholdRange])
    ];
  }

  LogicActions({
    this.metaActionSelection = const [],
    this.thresholdSelection = const [],
    this.featOrder = const [],
    this.nThresholds = 0,
    this.allowRecurrence = false,
    this.allowedGates = const [],
    List<MetaAction>? metaActions,
    List<ThresholdRange>? thresholds,
    super.paramRefs
  }) : metaActions = metaActions ?? <MetaAction>[],
       thresholds = thresholds ?? <ThresholdRange>[];

  factory LogicActions.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final metaActionSelection = getField<List<String>>(json, "meta_action_selection", const [], paramRefs, listFromJson<String>);
    final thresholdSelection = getField<List<String>>(json, "threshold_selection", const [], paramRefs, listFromJson<String>);
    final featOrder = getField<List<String>>(json, "feat_order", const [], paramRefs, listFromJson<String>);
    final nThresholds = getField<int>(json, "n_thresholds", 0, paramRefs);
    final allowRecurrence = getField<bool>(json, "allow_recurrence", false, paramRefs);
    final allowedGates = getField<List<Gate>>(json, "allowed_gates", const [], paramRefs, Gate.listFromJson);
    final metaActions = <MetaAction>[];
    final thresholds = <ThresholdRange>[];
    final metaActionsJson = json["meta_action_pool"] as List<dynamic>? ?? [];
    final thresholdsJson = json["threshold_pool"] as List<dynamic>? ?? [];

    for (final metaActionJson in metaActionsJson) {
      final metaAction = MetaAction.fromJson(metaActionJson as Map<String, dynamic>);
      metaActions.add(metaAction);
    }

    for (final thresholdJson in thresholdsJson) {
      final threshold = ThresholdRange.fromJson(thresholdJson as Map<String, dynamic>);
      thresholds.add(threshold);
    }

    return LogicActions(
      metaActionSelection: metaActionSelection,
      thresholdSelection: thresholdSelection,
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRecurrence: allowRecurrence,
      allowedGates: allowedGates,
      metaActions: metaActions,
      thresholds: thresholds,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "meta_actions":
        return metaActions;
      case "thresholds":
        return thresholds;
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    switch (slotKey) {
      case "meta_actions":
        metaActions.add(child as MetaAction);
        return true;
      case "thresholds":
        thresholds.add(child as ThresholdRange);
        return true;
      default:
        return false;
    }
  }

  @override
  bool removeDirectChild(String targetId) {
    if (removeChildFromList(metaActions, targetId)) return true;
    return removeChildFromList(thresholds, targetId);
  }

  List<Gate> parseGates(String text) {
    final gates = <Gate>[];

    for (final part in parseList(text)) {
      final gate = Gate.fromJson(part);
      gates.add(gate);
    }

    return gates;
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "meta_action_selection":
        metaActionSelection = parseList(text);
      case "threshold_selection":
        thresholdSelection = parseList(text);
      case "feat_order":
        featOrder = parseList(text);
      case "n_thresholds":
        nThresholds = int.tryParse(text) ?? 0;
      case "allowed_gates":
        allowedGates = parseGates(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "allow_recurrence":
        allowRecurrence = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "meta_action_selection" => metaActionSelection.join(", "),
      "threshold_selection" => thresholdSelection.join(", "),
      "feat_order" => featOrder.join(", "),
      "n_thresholds" => nThresholds.toString(),
      "allow_recurrence" => allowRecurrence.toString(),
      "allowed_gates" => allowedGates.map((gate) => gate.name).join(", "),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final metaActionPool = metaActions.map((action) => action.toJson()).toList();
    final thresholdPool = thresholds.map((threshold) => threshold.toJson()).toList();
    final gatesJson = allowedGates.map((gate) => gate.toJson()).toList();
    final metaActionSelectionJson = assembleField("meta_action_selection", metaActionSelection);
    final thresholdSelectionJson = assembleField("threshold_selection", thresholdSelection);
    final featOrderJson = assembleField("feat_order", featOrder);
    final nThresholdsJson = assembleField("n_thresholds", nThresholds);
    final allowRecurrenceJson = assembleField("allow_recurrence", allowRecurrence);
    final allowedGatesJson = assembleField("allowed_gates", gatesJson);

    return {
      "meta_action_pool": metaActionPool,
      "meta_action_selection": metaActionSelectionJson,
      "threshold_pool": thresholdPool,
      "threshold_selection": thresholdSelectionJson,
      "feat_order": featOrderJson,
      "n_thresholds": nThresholdsJson,
      "allow_recurrence": allowRecurrenceJson,
      "allowed_gates": allowedGatesJson
    };
  }
}

class DecisionActions extends NodeData {
  List<String> metaActionSelection;
  List<String> thresholdSelection;
  List<String> featOrder;
  int nThresholds;
  bool allowRefs;
  List<MetaAction> metaActions;
  List<ThresholdRange> thresholds;

  @override
  NodeType get nodeType => NodeType.decisionActions;

  @override
  int get fieldCount => 5;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "meta_actions", label: "Meta Action", multi: true, allowedTypes: [NodeType.metaAction]),
      ChildSlot(key: "thresholds", label: "Threshold", multi: true, allowedTypes: [NodeType.thresholdRange])
    ];
  }

  DecisionActions({
    this.metaActionSelection = const [],
    this.thresholdSelection = const [],
    this.featOrder = const [],
    this.nThresholds = 0,
    this.allowRefs = false,
    List<MetaAction>? metaActions,
    List<ThresholdRange>? thresholds,
    super.paramRefs
  }) : metaActions = metaActions ?? <MetaAction>[],
       thresholds = thresholds ?? <ThresholdRange>[];

  factory DecisionActions.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final metaActionSelection = getField<List<String>>(json, "meta_action_selection", const [], paramRefs, listFromJson<String>);
    final thresholdSelection = getField<List<String>>(json, "threshold_selection", const [], paramRefs, listFromJson<String>);
    final featOrder = getField<List<String>>(json, "feat_order", const [], paramRefs, listFromJson<String>);
    final nThresholds = getField<int>(json, "n_thresholds", 0, paramRefs);
    final allowRefs = getField<bool>(json, "allow_refs", false, paramRefs);
    final metaActions = <MetaAction>[];
    final thresholds = <ThresholdRange>[];
    final metaActionsJson = json["meta_action_pool"] as List<dynamic>? ?? [];
    final thresholdsJson = json["threshold_pool"] as List<dynamic>? ?? [];

    for (final metaActionJson in metaActionsJson) {
      final metaAction = MetaAction.fromJson(metaActionJson as Map<String, dynamic>);
      metaActions.add(metaAction);
    }

    for (final thresholdJson in thresholdsJson) {
      final threshold = ThresholdRange.fromJson(thresholdJson as Map<String, dynamic>);
      thresholds.add(threshold);
    }

    return DecisionActions(
      metaActionSelection: metaActionSelection,
      thresholdSelection: thresholdSelection,
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRefs: allowRefs,
      metaActions: metaActions,
      thresholds: thresholds,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "meta_actions":
        return metaActions;
      case "thresholds":
        return thresholds;
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    switch (slotKey) {
      case "meta_actions":
        metaActions.add(child as MetaAction);
        return true;
      case "thresholds":
        thresholds.add(child as ThresholdRange);
        return true;
      default:
        return false;
    }
  }

  @override
  bool removeDirectChild(String targetId) {
    if (removeChildFromList(metaActions, targetId)) return true;
    return removeChildFromList(thresholds, targetId);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "meta_action_selection":
        metaActionSelection = parseList(text);
      case "threshold_selection":
        thresholdSelection = parseList(text);
      case "feat_order":
        featOrder = parseList(text);
      case "n_thresholds":
        nThresholds = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "allow_refs":
        allowRefs = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "meta_action_selection" => metaActionSelection.join(", "),
      "threshold_selection" => thresholdSelection.join(", "),
      "feat_order" => featOrder.join(", "),
      "n_thresholds" => nThresholds.toString(),
      "allow_refs" => allowRefs.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final metaActionPool = metaActions.map((action) => action.toJson()).toList();
    final thresholdPool = thresholds.map((threshold) => threshold.toJson()).toList();
    final metaActionSelectionJson = assembleField("meta_action_selection", metaActionSelection);
    final thresholdSelectionJson = assembleField("threshold_selection", thresholdSelection);
    final featOrderJson = assembleField("feat_order", featOrder);
    final nThresholdsJson = assembleField("n_thresholds", nThresholds);
    final allowRefsJson = assembleField("allow_refs", allowRefs);

    return {
      "meta_action_pool": metaActionPool,
      "meta_action_selection": metaActionSelectionJson,
      "threshold_pool": thresholdPool,
      "threshold_selection": thresholdSelectionJson,
      "feat_order": featOrderJson,
      "n_thresholds": nThresholdsJson,
      "allow_refs": allowRefsJson
    };
  }
}

class Actions extends NodeData {
  String type;
  LogicActions? logicActions;
  DecisionActions? decisionActions;

  @override
  NodeType get nodeType => NodeType.actionsGen;

  @override
  int get fieldCount => 1;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "logic_actions", label: "Logic Actions", multi: false, allowedTypes: [NodeType.logicActions]),
      ChildSlot(key: "decision_actions", label: "Decision Actions", multi: false, allowedTypes: [NodeType.decisionActions])
    ];
  }

  Actions({this.type = "logic", this.logicActions, this.decisionActions, super.paramRefs});

  factory Actions.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final type = getField<String>(json, "type", "logic", paramRefs);
    final logicActionsJson = json["logic_actions"] as Map<String, dynamic>?;
    final decisionActionsJson = json["decision_actions"] as Map<String, dynamic>?;
    final logicActions = logicActionsJson == null ? null : LogicActions.fromJson(logicActionsJson);
    final decisionActions = decisionActionsJson == null ? null : DecisionActions.fromJson(decisionActionsJson);

    return Actions(
      type: type,
      logicActions: logicActions,
      decisionActions: decisionActions,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "logic_actions":
        return logicActions == null ? const [] : [logicActions!];
      case "decision_actions":
        return decisionActions == null ? const [] : [decisionActions!];
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    switch (slotKey) {
      case "logic_actions":
        logicActions = child as LogicActions;
        return true;
      case "decision_actions":
        decisionActions = child as DecisionActions;
        return true;
      default:
        return false;
    }
  }

  @override
  bool removeDirectChild(String targetId) {
    if (logicActions?.nodeId == targetId) {
      logicActions = null;
      return true;
    }

    if (decisionActions?.nodeId == targetId) {
      decisionActions = null;
      return true;
    }

    return false;
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "type":
        type = value as String;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "type" => type,
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final typeJson = assembleField("type", type);

    return {
      "type": typeJson,
      "logic_actions": logicActions?.toJson(),
      "decision_actions": decisionActions?.toJson()
    };
  }
}
