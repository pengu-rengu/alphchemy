import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class ThresholdRange extends NodeObject {
  String featId;
  double min;
  double max;

  @override
  String get nodeType => "threshold_range";

  ThresholdRange({this.featId = "", this.min = 0.0, this.max = 0.0});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final featId = stringOrDefault(json, "feat_id", "featId", "", refs);
    final min = doubleOrDefault(json, "min", "min", 0.0, refs);
    final max = doubleOrDefault(json, "max", "max", 0.0, refs);
    final data = ThresholdRange(featId: featId, min: min, max: max);
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ThresholdRange;
    return {
      "feat_id": assembleField(data.featId, "featId", data.paramRefs),
      "min": assembleField(data.min, "min", data.paramRefs),
      "max": assembleField(data.max, "max", data.paramRefs)
    };
  }
}

class MetaAction extends NodeObject {
  String label;
  List<String> subActions;

  @override
  String get nodeType => "meta_action";

  MetaAction({this.label = "", this.subActions = const []});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final label = stringOrDefault(json, "label", "label", "", refs);
    final rawSubActions = json["sub_actions"] as List<dynamic>;
    final subActions = List<String>.from(rawSubActions);
    final data = MetaAction(label: label, subActions: subActions);
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as MetaAction;
    return {
      "label": assembleField(data.label, "label", data.paramRefs),
      "sub_actions": assembleField(data.subActions, "subActions", data.paramRefs)
    };
  }
}

class LogicActions extends NodeObject {
  List<String> metaActionIds;
  List<int> metaActionSelection;
  List<String> thresholdIds;
  List<int> thresholdSelection;
  int nThresholds;
  bool allowRecurrence;
  List<Gate> allowedGates;

  @override
  String get nodeType => "logic_actions";

  LogicActions({
    this.metaActionIds = const [],
    this.metaActionSelection = const [],
    this.thresholdIds = const [],
    this.thresholdSelection = const [],
    this.nThresholds = 0,
    this.allowRecurrence = false,
    this.allowedGates = const []
  });

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
    final metaActionSelection = intListOrDefault(json, "meta_action_selection", "metaActionSelection", const [], refs);
    final thresholdIds = <String>[];
    final rawThresholds = json["threshold_pool"] as List<dynamic>?;
    if (rawThresholds != null) {
      for (final raw in rawThresholds) {
        final map = raw as Map<String, dynamic>;
        thresholdIds.add(ThresholdRange.flatten(ctx, map));
      }
    }
    final thresholdSelection = intListOrDefault(json, "threshold_selection", "thresholdSelection", const [], refs);
    final nThresholds = intOrDefault(json, "n_thresholds", "nThresholds", 0, refs);
    final allowRecurrence = boolOrDefault(json, "allow_recurrence", "allowRecurrence", false, refs);
    final rawGates = json["allowed_gates"] as List<dynamic>?;
    final allowedGates = rawGates != null
        ? listFromJson(rawGates, (val) => Gate.fromJson(val as String))
        : <Gate>[];
    final data = LogicActions(
      metaActionIds: metaActionIds,
      metaActionSelection: metaActionSelection,
      thresholdIds: thresholdIds,
      thresholdSelection: thresholdSelection,
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
      "n_thresholds": assembleField(data.nThresholds, "nThresholds", data.paramRefs),
      "allow_recurrence": assembleField(data.allowRecurrence, "allowRecurrence", data.paramRefs),
      "allowed_gates": assembleField(gatesList, "allowedGates", data.paramRefs)
    };
  }
}

class DecisionActions extends NodeObject {
  List<String> metaActionIds;
  List<int> metaActionSelection;
  List<String> thresholdIds;
  List<int> thresholdSelection;
  int nThresholds;
  bool allowRefs;

  @override
  String get nodeType => "decision_actions";

  DecisionActions({
    this.metaActionIds = const [],
    this.metaActionSelection = const [],
    this.thresholdIds = const [],
    this.thresholdSelection = const [],
    this.nThresholds = 0,
    this.allowRefs = false
  });

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
    final metaActionSelection = intListOrDefault(json, "meta_action_selection", "metaActionSelection", const [], refs);
    final thresholdIds = <String>[];
    final rawThresholds = json["threshold_pool"] as List<dynamic>?;
    if (rawThresholds != null) {
      for (final raw in rawThresholds) {
        final map = raw as Map<String, dynamic>;
        thresholdIds.add(ThresholdRange.flatten(ctx, map));
      }
    }
    final thresholdSelection = intListOrDefault(json, "threshold_selection", "thresholdSelection", const [], refs);
    final nThresholds = intOrDefault(json, "n_thresholds", "nThresholds", 0, refs);
    final allowRefs = boolOrDefault(json, "allow_refs", "allowRefs", false, refs);
    final data = DecisionActions(
      metaActionIds: metaActionIds,
      metaActionSelection: metaActionSelection,
      thresholdIds: thresholdIds,
      thresholdSelection: thresholdSelection,
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
      "n_thresholds": assembleField(data.nThresholds, "nThresholds", data.paramRefs),
      "allow_refs": assembleField(data.allowRefs, "allowRefs", data.paramRefs)
    };
  }
}

// Widget classes

class ThresholdRangeContent extends StatelessWidget {
  final ThresholdRange data;

  const ThresholdRangeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "featId", paramType: ParamType.stringType, nodeData: data, child: NodeTextField(
          label: "featId", value: data.featId, onChanged: (val) => data.featId = val
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "min", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "min", value: data.min.toString(), onChanged: (val) => data.min = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "max", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "max", value: data.max.toString(), onChanged: (val) => data.max = double.tryParse(val) ?? 0
        ))
      ]
    );
  }
}

class MetaActionContent extends StatelessWidget {
  final MetaAction data;

  const MetaActionContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "label", paramType: ParamType.stringType, nodeData: data, child: NodeTextField(
          label: "label", value: data.label, onChanged: (val) => data.label = val
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "subActions", paramType: ParamType.intListType, nodeData: data, child: NodeListField<String>(
          label: "subActs",
          items: data.subActions,
          display: (val) => val,
          parse: (str) => str,
          defaultItem: () => "",
          onChanged: (list) { data.subActions = list; }
        ))
      ]
    );
  }
}

class LogicActionsContent extends StatelessWidget {
  final LogicActions data;

  const LogicActionsContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "metaActionSelection", paramType: ParamType.intListType, nodeData: data, child: NodeListField<int>(
          label: "metaSel",
          items: data.metaActionSelection,
          display: (val) => val.toString(),
          parse: (str) => int.tryParse(str) ?? 0,
          defaultItem: () => 0,
          onChanged: (list) { data.metaActionSelection = list; }
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "thresholdSelection", paramType: ParamType.intListType, nodeData: data, child: NodeListField<int>(
          label: "threshSel",
          items: data.thresholdSelection,
          display: (val) => val.toString(),
          parse: (str) => int.tryParse(str) ?? 0,
          defaultItem: () => 0,
          onChanged: (list) { data.thresholdSelection = list; }
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "nThresholds", paramType: ParamType.intType, nodeData: data, child: NodeTextField(
          label: "nThresh",
          value: data.nThresholds.toString(),
          onChanged: (val) => data.nThresholds = int.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "allowRecurrence", paramType: ParamType.boolType, nodeData: data, child: NodeCheckbox(
          label: "recurrence",
          value: data.allowRecurrence,
          onChanged: (val) => data.allowRecurrence = val
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "allowedGates", paramType: ParamType.intListType, nodeData: data, child: NodeListField<Gate>(
          label: "gates",
          items: data.allowedGates,
          display: (gate) => gate.name,
          parse: (str) => Gate.fromJson(str),
          defaultItem: () => Gate.and,
          onChanged: (list) { data.allowedGates = list; }
        ))
      ]
    );
  }
}

class DecisionActionsContent extends StatelessWidget {
  final DecisionActions data;

  const DecisionActionsContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "metaActionSelection", paramType: ParamType.intListType, nodeData: data, child: NodeListField<int>(
          label: "metaSel",
          items: data.metaActionSelection,
          display: (val) => val.toString(),
          parse: (str) => int.tryParse(str) ?? 0,
          defaultItem: () => 0,
          onChanged: (list) { data.metaActionSelection = list; }
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "thresholdSelection", paramType: ParamType.intListType, nodeData: data, child: NodeListField<int>(
          label: "threshSel",
          items: data.thresholdSelection,
          display: (val) => val.toString(),
          parse: (str) => int.tryParse(str) ?? 0,
          defaultItem: () => 0,
          onChanged: (list) { data.thresholdSelection = list; }
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "nThresholds", paramType: ParamType.intType, nodeData: data, child: NodeTextField(
          label: "nThresh",
          value: data.nThresholds.toString(),
          onChanged: (val) => data.nThresholds = int.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "allowRefs", paramType: ParamType.boolType, nodeData: data, child: NodeCheckbox(
          label: "allowRefs",
          value: data.allowRefs,
          onChanged: (val) => data.allowRefs = val
        ))
      ]
    );
  }
}
