import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class ThresholdRange extends NodeObject {
  String thresholdId;
  String featId;
  double min;
  double max;

  @override
  String get nodeType => "threshold_range";

  ThresholdRange({
    this.thresholdId = "",
    this.featId = "",
    this.min = 0.0,
    this.max = 0.0
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "thresholdId": thresholdId = text;
      case "featId": featId = text;
      case "min": min = double.tryParse(text) ?? 0.0;
      case "max": max = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "thresholdId" => thresholdId,
      "featId" => featId,
      "min" => min.toString(),
      "max" => max.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final thresholdId = stringOrDefault(json, "id", "thresholdId", "", refs);
    final featId = stringOrDefault(json, "feat_id", "featId", "", refs);
    final min = doubleOrDefault(json, "min", "min", 0.0, refs);
    final max = doubleOrDefault(json, "max", "max", 0.0, refs);
    final data = ThresholdRange(
      thresholdId: thresholdId,
      featId: featId,
      min: min,
      max: max
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ThresholdRange;
    return {
      "id": assembleField(data.thresholdId, "thresholdId", data.paramRefs),
      "feat_id": assembleField(data.featId, "featId", data.paramRefs),
      "min": assembleField(data.min, "min", data.paramRefs),
      "max": assembleField(data.max, "max", data.paramRefs)
    };
  }
}

class MetaAction extends NodeObject {
  String metaActionId;
  String label;
  List<String> subActions;

  @override
  String get nodeType => "meta_action";

  MetaAction({
    this.metaActionId = "",
    this.label = "",
    this.subActions = const []
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "metaActionId": metaActionId = text;
      case "label": label = text;
      case "subActions": subActions = NodeObject.parseStringList(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "metaActionId" => metaActionId,
      "label" => label,
      "subActions" => NodeObject.formatList(subActions),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final metaActionId = stringOrDefault(json, "id", "metaActionId", "", refs);
    final label = stringOrDefault(json, "label", "label", "", refs);
    final subActions = stringListOrDefault(
      json,
      "sub_actions",
      "subActions",
      const [],
      refs
    );
    final data = MetaAction(
      metaActionId: metaActionId,
      label: label,
      subActions: subActions
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as MetaAction;
    return {
      "id": assembleField(data.metaActionId, "metaActionId", data.paramRefs),
      "label": assembleField(data.label, "label", data.paramRefs),
      "sub_actions": assembleField(data.subActions, "subActions", data.paramRefs)
    };
  }
}

class LogicActions extends NodeObject {
  List<String> metaActionSelection;
  List<String> thresholdSelection;
  List<String> featOrder;
  int nThresholds;
  bool allowRecurrence;
  List<Gate> allowedGates;

  @override
  String get nodeType => "logic_actions";

  LogicActions({
    this.metaActionSelection = const [],
    this.thresholdSelection = const [],
    this.featOrder = const [],
    this.nThresholds = 0,
    this.allowRecurrence = false,
    this.allowedGates = const []
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "metaActionSelection": metaActionSelection = NodeObject.parseStringList(text);
      case "thresholdSelection": thresholdSelection = NodeObject.parseStringList(text);
      case "featOrder": featOrder = NodeObject.parseStringList(text);
      case "nThresholds": nThresholds = int.tryParse(text) ?? 0;
      case "allowedGates": allowedGates = Gate.parseList(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "allowRecurrence": allowRecurrence = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "metaActionSelection" => NodeObject.formatList(metaActionSelection),
      "thresholdSelection" => NodeObject.formatList(thresholdSelection),
      "featOrder" => NodeObject.formatList(featOrder),
      "nThresholds" => nThresholds.toString(),
      "allowRecurrence" => allowRecurrence.toString(),
      "allowedGates" => allowedGates.map((gate) => gate.name).join(", "),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["meta_actions", "thresholds"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final metaActionIds = <String>[];
    final rawMetaActions = json["meta_action_pool"] as List<dynamic>?;
    if (rawMetaActions != null) {
      for (final raw in rawMetaActions) {
        final map = raw as Map<String, dynamic>;
        metaActionIds.add(MetaAction.flatten(ctx, map));
      }
    }
    final refs = <String, String>{};
    final metaActionSelection = stringListOrDefault(json, "meta_action_selection", "metaActionSelection", const [], refs);
    final thresholdIds = <String>[];
    final rawThresholds = json["threshold_pool"] as List<dynamic>?;
    if (rawThresholds != null) {
      for (final raw in rawThresholds) {
        final map = raw as Map<String, dynamic>;
        thresholdIds.add(ThresholdRange.flatten(ctx, map));
      }
    }
    final thresholdSelection = stringListOrDefault(json, "threshold_selection", "thresholdSelection", const [], refs);
    final featOrder = stringListOrDefault(json, "feat_order", "featOrder", const [], refs);
    final nThresholds = intOrDefault(json, "n_thresholds", "nThresholds", 0, refs);
    final allowRecurrence = boolOrDefault(json, "allow_recurrence", "allowRecurrence", false, refs);
    final allowedGates = listOrDefault<Gate>(
      json,
      "allowed_gates",
      "allowedGates",
      const [],
      refs,
      (value) => Gate.fromJson(value as String)
    );
    final data = LogicActions(
      metaActionSelection: metaActionSelection,
      thresholdSelection: thresholdSelection,
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRecurrence: allowRecurrence,
      allowedGates: allowedGates
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    for (final childId in metaActionIds) {
      ctx.connect(parentId, "out_meta_actions", childId);
    }
    for (final childId in thresholdIds) {
      ctx.connect(parentId, "out_thresholds", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as LogicActions;
    final metaIds = ctx.childIds(nodeId, "out_meta_actions");
    final threshIds = ctx.childIds(nodeId, "out_thresholds");
    final metaList = metaIds.map((id) => MetaAction.assemble(ctx, id)).toList();
    final threshList = threshIds.map((id) => ThresholdRange.assemble(ctx, id)).toList();
    final gatesList = data.allowedGates.map((gate) => gate.toJson()).toList();
    return {
      "meta_action_pool": metaList,
      "meta_action_selection": assembleField(data.metaActionSelection, "metaActionSelection", data.paramRefs),
      "threshold_pool": threshList,
      "threshold_selection": assembleField(data.thresholdSelection, "thresholdSelection", data.paramRefs),
      "feat_order": assembleField(data.featOrder, "featOrder", data.paramRefs),
      "n_thresholds": assembleField(data.nThresholds, "nThresholds", data.paramRefs),
      "allow_recurrence": assembleField(data.allowRecurrence, "allowRecurrence", data.paramRefs),
      "allowed_gates": assembleField(gatesList, "allowedGates", data.paramRefs)
    };
  }
}

class DecisionActions extends NodeObject {
  List<String> metaActionSelection;
  List<String> thresholdSelection;
  List<String> featOrder;
  int nThresholds;
  bool allowRefs;

  @override
  String get nodeType => "decision_actions";

  DecisionActions({
    this.metaActionSelection = const [],
    this.thresholdSelection = const [],
    this.featOrder = const [],
    this.nThresholds = 0,
    this.allowRefs = false
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "metaActionSelection": metaActionSelection = NodeObject.parseStringList(text);
      case "thresholdSelection": thresholdSelection = NodeObject.parseStringList(text);
      case "featOrder": featOrder = NodeObject.parseStringList(text);
      case "nThresholds": nThresholds = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "allowRefs": allowRefs = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "metaActionSelection" => NodeObject.formatList(metaActionSelection),
      "thresholdSelection" => NodeObject.formatList(thresholdSelection),
      "featOrder" => NodeObject.formatList(featOrder),
      "nThresholds" => nThresholds.toString(),
      "allowRefs" => allowRefs.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["meta_actions", "thresholds"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final metaActionIds = <String>[];
    final rawMetaActions = json["meta_action_pool"] as List<dynamic>?;
    if (rawMetaActions != null) {
      for (final raw in rawMetaActions) {
        final map = raw as Map<String, dynamic>;
        metaActionIds.add(MetaAction.flatten(ctx, map));
      }
    }
    final refs = <String, String>{};
    final metaActionSelection = stringListOrDefault(json, "meta_action_selection", "metaActionSelection", const [], refs);
    final thresholdIds = <String>[];
    final rawThresholds = json["threshold_pool"] as List<dynamic>?;
    if (rawThresholds != null) {
      for (final raw in rawThresholds) {
        final map = raw as Map<String, dynamic>;
        thresholdIds.add(ThresholdRange.flatten(ctx, map));
      }
    }
    final thresholdSelection = stringListOrDefault(json, "threshold_selection", "thresholdSelection", const [], refs);
    final featOrder = stringListOrDefault(json, "feat_order", "featOrder", const [], refs);
    final nThresholds = intOrDefault(json, "n_thresholds", "nThresholds", 0, refs);
    final allowRefs = boolOrDefault(json, "allow_refs", "allowRefs", false, refs);
    final data = DecisionActions(
      metaActionSelection: metaActionSelection,
      thresholdSelection: thresholdSelection,
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRefs: allowRefs
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    for (final childId in metaActionIds) {
      ctx.connect(parentId, "out_meta_actions", childId);
    }
    for (final childId in thresholdIds) {
      ctx.connect(parentId, "out_thresholds", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as DecisionActions;
    final metaIds = ctx.childIds(nodeId, "out_meta_actions");
    final threshIds = ctx.childIds(nodeId, "out_thresholds");
    final metaList = metaIds.map((id) => MetaAction.assemble(ctx, id)).toList();
    final threshList = threshIds.map((id) => ThresholdRange.assemble(ctx, id)).toList();
    return {
      "meta_action_pool": metaList,
      "meta_action_selection": assembleField(data.metaActionSelection, "metaActionSelection", data.paramRefs),
      "threshold_pool": threshList,
      "threshold_selection": assembleField(data.thresholdSelection, "thresholdSelection", data.paramRefs),
      "feat_order": assembleField(data.featOrder, "featOrder", data.paramRefs),
      "n_thresholds": assembleField(data.nThresholds, "nThresholds", data.paramRefs),
      "allow_refs": assembleField(data.allowRefs, "allowRefs", data.paramRefs)
    };
  }
}
