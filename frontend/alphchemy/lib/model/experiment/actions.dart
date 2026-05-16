import "package:alphchemy/model/experiment/network.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

class ThresholdRange extends NodeData {
  String featId;
  double min;
  double max;

  @override
  NodeType get nodeType => NodeType.thresholdRange;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "feat_id"),
    NodeTextField(label: "Min", field: "min"),
    NodeTextField(label: "Max", field: "max")
  ];

  ThresholdRange({this.featId = "", this.min = 0.0, this.max = 0.0});

  factory ThresholdRange.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final featId = getField<String>(json, "feat_id", "");
    final min = getField<double>(json, "min", 0.0, doubleFromJson);
    final max = getField<double>(json, "max", 0.0, doubleFromJson);

    final node = ThresholdRange(featId: featId, min: min, max: max);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "feat_id":
        featId = text;
      case "min":
        min = double.tryParse(text) ?? 0.0;
      case "max":
        max = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "feat_id" => featId,
      "min" => min.toString(),
      "max" => max.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "node_id": nodeId,
      "feat_id": featId,
      "min": min,
      "max": max
    };
  }

  @override
  NodeData copy() => ThresholdRange.fromJson(toJson());
}

class MetaAction extends NodeData {
  String label;
  List<String> subActions;

  @override
  NodeType get nodeType => NodeType.metaAction;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Label", field: "label"),
    NodeTextField(label: "Sub Actions", field: "sub_actions")
  ];

  MetaAction({this.label = "", this.subActions = const []});

  factory MetaAction.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final label = getField<String>(json, "label", "");
    final subActions = getField<List<String>>(json, "sub_actions", const [], listFromJson<String>);

    final node = MetaAction(label: label, subActions: subActions);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "label":
        label = text;
      case "sub_actions":
        subActions = parseList(text);
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "label" => label,
      "sub_actions" => subActions.join(", "),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "node_id": nodeId,
      "label": label,
      "sub_actions": subActions
    };
  }

  @override
  NodeData copy() => MetaAction.fromJson(toJson());
}

sealed class Actions extends NodeData {
  Actions();

  factory Actions.fromJson(Map<String, dynamic> json) {
    final type = json["type"];

    return switch (type) {
      "logic" => LogicActions.fromJson(json),
      "decision" => DecisionActions.fromJson(json),
      _ => throw Exception("Unknown actions type: $type")
    };
  }
}


class LogicActions extends Actions {
  List<String> featOrder;
  int nThresholds;
  bool allowRecurrence;
  List<Gate> allowedGates;
  List<MetaAction> metaActions;
  List<ThresholdRange> thresholds;

  @override
  NodeType get nodeType => NodeType.logicActions;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature Order", field: "feat_order"),
    NodeTextField(label: "# Of Threshold Choices", field: "n_thresholds"),
    NodeBoolDropdown(label: "Allow Recurrence", field: "allow_recurrence"),
    NodeTextField(label: "Allowed Gates", field: "allowed_gates")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "meta_actions", label: "Meta Actions", isMulti: true, allowedTypes: [NodeType.metaAction]),
      ChildSlot(field: "thresholds", label: "Thresholds", isMulti: true, allowedTypes: [NodeType.thresholdRange])
    ];
  }

  LogicActions({this.featOrder = const [], this.nThresholds = 0, this.allowRecurrence = false, this.allowedGates = const [], List<MetaAction>? metaActions,List<ThresholdRange>? thresholds}) :
    metaActions = metaActions ?? <MetaAction>[],
    thresholds = thresholds ?? <ThresholdRange>[];

  factory LogicActions.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final featOrder = getField<List<String>>(json, "feat_order", const [], listFromJson<String>);
    final nThresholds = getField<int>(json, "n_thresholds", 0);
    final allowRecurrence = getField<bool>(json, "allow_recurrence", false);
    final allowedGates = getField<List<Gate>>(json, "allowed_gates", const [], Gate.listFromJson);
    final metaActions = <MetaAction>[];
    final thresholds = <ThresholdRange>[];
    final metaActionsJson = json["meta_actions"] as List<dynamic>? ?? [];
    final thresholdsJson = json["thresholds"] as List<dynamic>? ?? [];

    for (final metaActionJson in metaActionsJson) {
      final metaAction = MetaAction.fromJson(metaActionJson as Map<String, dynamic>);
      metaActions.add(metaAction);
    }

    for (final thresholdJson in thresholdsJson) {
      final threshold = ThresholdRange.fromJson(thresholdJson as Map<String, dynamic>);
      thresholds.add(threshold);
    }

    final node = LogicActions(
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRecurrence: allowRecurrence,
      allowedGates: allowedGates,
      metaActions: metaActions,
      thresholds: thresholds
    );
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    switch (field) {
      case "meta_actions":
        return metaActions;
      case "thresholds":
        return thresholds;
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String field, NodeData child) {
    switch (field) {
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
  void updateField(String field, String text) {
    switch (field) {
      case "feat_order":
        featOrder = parseList(text);
      case "n_thresholds":
        nThresholds = int.tryParse(text) ?? 0;
      case "allowed_gates":
        allowedGates = parseList(text).map(Gate.fromJson).toList();
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "allow_recurrence":
        allowRecurrence = value as bool;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "feat_order" => featOrder.join(", "),
      "n_thresholds" => nThresholds.toString(),
      "allow_recurrence" => allowRecurrence.toString(),
      "allowed_gates" => allowedGates.map((gate) => gate.name).join(", "),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final metaActionsJson = metaActions.map((action) => action.toJson()).toList();
    final thresholdsJson = thresholds.map((threshold) => threshold.toJson()).toList();
    final gatesJson = allowedGates.map((gate) => gate.toJson()).toList();

    return {
      "node_id": nodeId,
      "type": "logic",
      "meta_actions": metaActionsJson,
      "thresholds": thresholdsJson,
      "feat_order": featOrder,
      "n_thresholds": nThresholds,
      "allow_recurrence": allowRecurrence,
      "allowed_gates": gatesJson
    };
  }

  @override
  NodeData copy() => LogicActions.fromJson(toJson());
}

class DecisionActions extends Actions {
  List<String> featOrder;
  int nThresholds;
  bool allowRefs;
  List<MetaAction> metaActions;
  List<ThresholdRange> thresholds;

  @override
  NodeType get nodeType => NodeType.decisionActions;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature Order", field: "feat_order"),
    NodeTextField(label: "N Thresholds", field: "n_thresholds"),
    NodeBoolDropdown(label: "Allow References", field: "allow_refs")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "meta_actions", label: "Meta Actions", isMulti: true, allowedTypes: [NodeType.metaAction]),
      ChildSlot(field: "thresholds", label: "Thresholds", isMulti: true, allowedTypes: [NodeType.thresholdRange])
    ];
  }

  DecisionActions({this.featOrder = const [], this.nThresholds = 0, this.allowRefs = false, List<MetaAction>? metaActions, List<ThresholdRange>? thresholds}) :
    metaActions = metaActions ?? <MetaAction>[],
    thresholds = thresholds ?? <ThresholdRange>[];

  factory DecisionActions.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final featOrder = getField<List<String>>(json, "feat_order", const [], listFromJson<String>);
    final nThresholds = getField<int>(json, "n_thresholds", 0);
    final allowRefs = getField<bool>(json, "allow_refs", false);
    final metaActions = <MetaAction>[];
    final thresholds = <ThresholdRange>[];
    final metaActionsJson = json["meta_actions"] as List<dynamic>? ?? [];
    final thresholdsJson = json["thresholds"] as List<dynamic>? ?? [];

    for (final metaActionJson in metaActionsJson) {
      final metaAction = MetaAction.fromJson(metaActionJson as Map<String, dynamic>);
      metaActions.add(metaAction);
    }

    for (final thresholdJson in thresholdsJson) {
      final threshold = ThresholdRange.fromJson(thresholdJson as Map<String, dynamic>);
      thresholds.add(threshold);
    }

    final node = DecisionActions(
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRefs: allowRefs,
      metaActions: metaActions,
      thresholds: thresholds
    );
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    switch (field) {
      case "meta_actions":
        return metaActions;
      case "thresholds":
        return thresholds;
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String field, NodeData child) {
    switch (field) {
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
  void updateField(String field, String text) {
    switch (field) {
      case "feat_order":
        featOrder = parseList(text);
      case "n_thresholds":
        nThresholds = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "allow_refs":
        allowRefs = value as bool;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "feat_order" => featOrder.join(", "),
      "n_thresholds" => nThresholds.toString(),
      "allow_refs" => allowRefs.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final metaActionsJson = metaActions.map((action) => action.toJson()).toList();
    final thresholdsJson = thresholds.map((threshold) => threshold.toJson()).toList();

    return {
      "node_id": nodeId,
      "type": "decision",
      "meta_actions": metaActionsJson,
      "thresholds": thresholdsJson,
      "feat_order": featOrder,
      "n_thresholds": nThresholds,
      "allow_refs": allowRefs
    };
  }

  @override
  NodeData copy() => DecisionActions.fromJson(toJson());
}
