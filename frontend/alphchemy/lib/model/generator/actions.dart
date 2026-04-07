import "package:alphchemy/model/generator/graph_convert.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/node_ports.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class ThresholdRange extends NodeObject {
  String id;
  String featId;
  double min;
  double max;

  @override
  NodeType get nodeType => NodeType.thresholdRange;

  ThresholdRange({
    this.id = "",
    this.featId = "",
    this.min = 0.0,
    this.max = 0.0,
    super.paramRefs
  });

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id": id = text;
      case "feat_id": featId = text;
      case "min": min = double.tryParse(text) ?? 0.0;
      case "max": max = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {}

  @override
  String formatField(String field) {
    return switch (field) {
      "id" => id,
      "feat_id" => featId,
      "min" => min.toString(),
      "max" => max.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final thresholdId = getField<String>(json, "id", "", paramRefs);
    final featId = getField<String>(json, "feat_id", "", paramRefs);
    final min = getField<double>(json, "min", 0.0, paramRefs, doubleFromJson);
    final max = getField<double>(json, "max", 0.0, paramRefs, doubleFromJson);

    final data = ThresholdRange(
      id: thresholdId,
      featId: featId,
      min: min,
      max: max,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as ThresholdRange;

    final id = assembleField(data.id, "id", data);
    final featId = assembleField(data.featId, "feat_id", data);
    final min = assembleField(data.min, "min", data);
    final max = assembleField(data.max, "max", data);

    return {
      "id": id,
      "type": "threshold",
      "feat_id": featId,
      "min": min,
      "max": max
    };
  }
}

class MetaAction extends NodeObject {
  String id;
  String label;
  List<String> subActions;

  @override
  NodeType get nodeType => NodeType.metaAction;

  MetaAction({
    this.id = "",
    this.label = "",
    this.subActions = const [],
    super.paramRefs
  });

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id": id = text;
      case "label": label = text;
      case "sub_actions": subActions = parseList(text);
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {}

  @override
  String formatField(String field) {
    return switch (field) {
      "id" => id,
      "label" => label,
      "sub_actions" => subActions.join(", "),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final id = getField<String>(json, "id", "", paramRefs);
    final label = getField<String>(json, "label", "", paramRefs);
    final subActions = getField<List<String>>(json, "sub_actions", const [], paramRefs, listFromJson<String>);

    final data = MetaAction(
      id: id,
      label: label,
      subActions: subActions,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as MetaAction;

    final id = assembleField(data.id, "id", data);
    final label = assembleField(data.label, "label", data);
    final subActions = assembleField(data.subActions, "sub_actions", data);

    return {
      "id": id,
      "type": "meta_action",
      "label": label,
      "sub_actions": subActions
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
  NodeType get nodeType => NodeType.logicActions;

  LogicActions({this.metaActionSelection = const [], this.thresholdSelection = const [],this.featOrder = const [], this.nThresholds = 0, this.allowRecurrence = false, this.allowedGates = const [], super.paramRefs});

  List<Gate> parseGates(String text) {
    final gates = <Gate>[];

    for (final part in text.split(",")) {
      final trimmed = part.trim();

      if (trimmed.isNotEmpty) {
        final gate = Gate.fromJson(part);
        gates.add(gate);
      }
    }

    return gates;
  }
    

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "meta_action_selection": metaActionSelection = parseList(text);
      case "threshold_selection": thresholdSelection = parseList(text);
      case "feat_order": featOrder = parseList(text);
      case "n_thresholds": nThresholds = int.tryParse(text) ?? 0;
      case "allowed_gates": allowedGates = parseGates(text);
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "allow_recurrence": allowRecurrence = value as bool;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "meta_action_selection" => metaActionSelection.join(", "),
      "threshold_selection" => thresholdSelection.join(", "),
      "feat_order" => featOrder.join(", "),
      "n_thresholds" => nThresholds.toString(),
      "allow_recurrence" => allowRecurrence.toString(),
      "allowed_gates" => allowedGates.map((gate) => gate.name.toLowerCase()).join(", "),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["meta_actions", "thresholds"])
    ];
  }

  static List<Gate> gatesFromJson(dynamic value) {
    final gatesStr = listFromJson<String>(value);
    return gatesStr.map(Gate.fromJson).toList();
  } 

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    
    final metaActionSelection = getField<List<String>>(json, "meta_action_selection", const [], paramRefs, listFromJson<String>);
    final thresholdSelection = getField<List<String>>(json, "threshold_selection", const [], paramRefs, listFromJson<String>);
    final featOrder = getField<List<String>>(json, "feat_order", const [], paramRefs, listFromJson<String>);
    final nThresholds = getField<int>(json, "n_thresholds", 0, paramRefs);
    final allowRecurrence = getField<bool>(json, "allow_recurrence", false, paramRefs);
    final allowedGates = getField<List<Gate>>(json, "allowed_gates", const [], paramRefs, gatesFromJson);

    final data = LogicActions(
      metaActionSelection: metaActionSelection,
      thresholdSelection: thresholdSelection,
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRecurrence: allowRecurrence,
      allowedGates: allowedGates,
      paramRefs: paramRefs
    );
    final parentId = ctx.addNode(data);

    for (final metaActionJson in json["meta_action_pool"] as List<dynamic>? ?? []) {
      final childId = MetaAction.flatten(ctx, metaActionJson as Map<String, dynamic>);
      ctx.connect(parentId, "meta_actions", childId);
    }

    for (final thresholdRangeJson in json["threshold_pool"] as List<dynamic>? ?? []) {
      final childId = ThresholdRange.flatten(ctx, thresholdRangeJson as Map<String, dynamic>);
      ctx.connect(parentId, "thresholds", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as LogicActions;

    final metaActionIds = ctx.childIds(nodeId, "meta_actions");
    Map<String, dynamic> assembleMetaAction(id) => MetaAction.assemble(ctx, id);
    final metaActionPool = metaActionIds.map(assembleMetaAction).toList();

    final metaActionSelection = assembleField(data.metaActionSelection,"meta_action_selection", data);

    final thresholdIds = ctx.childIds(nodeId, "thresholds");
    Map<String, dynamic> assembleThreshold(id) => ThresholdRange.assemble(ctx, id);
    final thresholdPool = thresholdIds.map(assembleThreshold).toList();

    final thresholdSelection = assembleField(data.thresholdSelection, "threshold_selection", data);
    final featOrder = assembleField(data.featOrder, "feat_order", data);
    final nThresholds = assembleField(data.nThresholds, "n_thresholds", data);
    final allowRecurrence = assembleField(data.allowRecurrence, "allow_recurrence", data);

    final gatesStr = data.allowedGates.map((gate) => gate.toJson()).toList();
    final allowedGates = assembleField(gatesStr, "allowed_gates", data);

    return {
      "meta_action_pool": metaActionPool,
      "meta_action_selection": metaActionSelection,
      "threshold_pool": thresholdPool,
      "threshold_selection": thresholdSelection,
      "feat_order": featOrder,
      "n_thresholds": nThresholds,
      "allow_recurrence": allowRecurrence,
      "allowed_gates": allowedGates
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
  NodeType get nodeType => NodeType.decisionActions;

  DecisionActions({this.metaActionSelection = const [], this.thresholdSelection = const [], this.featOrder = const [], this.nThresholds = 0, this.allowRefs = false, super.paramRefs
  });

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "meta_action_selection": metaActionSelection = parseList(text);
      case "threshold_selection": thresholdSelection = parseList(text);
      case "feat_order": featOrder = parseList(text);
      case "n_thresholds": nThresholds = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "allow_refs": allowRefs = value as bool;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "meta_action_selection" => metaActionSelection.join(", "),
      "threshold_selection" => thresholdSelection.join(", "),
      "feat_order" => featOrder.join(", "),
      "n_thresholds" => nThresholds.toString(),
      "allow_refs" => allowRefs.toString(),
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
    final paramRefs = <String, String>{};

    final metaActionSelection = getField<List<String>>(json, "meta_action_selection", const [], paramRefs, listFromJson<String>);
    final thresholdSelection = getField<List<String>>(json, "threshold_selection", const [], paramRefs, listFromJson<String>);
    final featOrder = getField<List<String>>(json, "feat_order", const [], paramRefs, listFromJson<String>);
    final nThresholds = getField<int>(json, "n_thresholds", 0, paramRefs);
    final allowRefs = getField<bool>(json, "allow_refs", false, paramRefs);

    final data = DecisionActions(
      metaActionSelection: metaActionSelection,
      thresholdSelection: thresholdSelection,
      featOrder: featOrder,
      nThresholds: nThresholds,
      allowRefs: allowRefs,
      paramRefs: paramRefs
    );
    final parentId = ctx.addNode(data);

    for (final metaActionJson in json["meta_action_pool"] as List<dynamic>? ?? []) {
      final childId = MetaAction.flatten(ctx, metaActionJson as Map<String, dynamic>);
      ctx.connect(parentId, "meta_actions", childId);
    }

    for (final thresholdJson in json["threshold_pool"] as List<dynamic>? ?? []) {
      final childId = ThresholdRange.flatten(ctx, thresholdJson as Map<String, dynamic>);
      ctx.connect(parentId, "thresholds", childId);
    }

    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as DecisionActions;

    final metaActionIds = ctx.childIds(nodeId, "meta_actions");
    Map<String, dynamic> assembleMetaAction(id) => MetaAction.assemble(ctx, id);
    final metaActionPool = metaActionIds.map(assembleMetaAction).toList();

    final metaActionSelection = assembleField(data.metaActionSelection, "meta_action_selection", data);

    final thresholdIds = ctx.childIds(nodeId, "thresholds");
    Map<String, dynamic> assembleThreshold(id) => ThresholdRange.assemble(ctx, id);
    final thresholdPool = thresholdIds.map(assembleThreshold).toList();

    final thresholdSelection = assembleField(data.thresholdSelection, "threshold_selection", data);
    final featOrder = assembleField(data.featOrder, "feat_order", data);
    final nThresholds = assembleField(data.nThresholds, "n_thresholds", data);
    final allowRefs = assembleField(data.allowRefs, "allow_refs", data);

    return {
      "meta_action_pool": metaActionPool,
      "meta_action_selection": metaActionSelection,
      "threshold_pool": thresholdPool,
      "threshold_selection": thresholdSelection,
      "feat_order": featOrder,
      "n_thresholds": nThresholds,
      "allow_refs": allowRefs
    };
  }
}

class Actions extends NodeObject {
  String type;

  @override
  NodeType get nodeType => NodeType.actionsGen;

  Actions({this.type = "logic", super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {}

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "type": type = value as String;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "type" => type,
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["logic_actions", "decision_actions"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final type = getField<String>(json, "type", "logic", paramRefs);

    final data = Actions(type: type, paramRefs: paramRefs);
    final parentId = ctx.addNode(data);

    final logicActionsJson = json["logic_actions"] as Map<String, dynamic>?;
    if (logicActionsJson != null) {
      final logicActionsId = LogicActions.flatten(ctx, logicActionsJson);
      ctx.connect(parentId, "logic_actions", logicActionsId);
    }

    final decisionActionsJson = json["decision_actions"] as Map<String, dynamic>?;
    if (decisionActionsJson != null) {
      final decisionActionsId = DecisionActions.flatten(ctx, decisionActionsJson);
      ctx.connect(parentId, "decision_actions", decisionActionsId);
    }

    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as Actions;

    final type = assembleField(data.type, "type", data);

    final logicActionsId = ctx.childId(nodeId, "logic_actions");
    final logicActions = logicActionsId != null ? LogicActions.assemble(ctx, logicActionsId) : null;

    final decisionActionsId = ctx.childId(nodeId, "decision_actions");
    final decisionActions = decisionActionsId != null ? DecisionActions.assemble(ctx, decisionActionsId) : null;

    return {
      "type": type,
      "logic_actions": logicActions,
      "decision_actions": decisionActions
    };
  }
}
