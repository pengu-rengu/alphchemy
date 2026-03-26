import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class ThresholdRange extends NodeObject {
  String featId;
  double min;
  double max;

  @override
  String get nodeType => "threshold_range";

  ThresholdRange({required this.featId, required this.min, required this.max});

  static int get fieldCount => 3;

  static List<Port> ports() {
    return inputPort(0, fieldCount);
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int column) {
    final featId = json["feat_id"] as String;
    final min = doubleFromJson(json["min"]);
    final max = doubleFromJson(json["max"]);
    final data = ThresholdRange(featId: featId, min: min, max: max);
    return ctx.addNode(data, column);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ThresholdRange;
    return {
      "feat_id": data.featId,
      "min": data.min,
      "max": data.max
    };
  }
}

class MetaAction extends NodeObject {
  String label;
  List<String> subActions;

  @override
  String get nodeType => "meta_action";

  MetaAction({required this.label, required this.subActions});

  static int get fieldCount => 2;

  static List<Port> ports() {
    return inputPort(0, fieldCount);
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int column) {
    final label = json["label"] as String;
    final rawSubActions = json["sub_actions"] as List<dynamic>;
    final subActions = List<String>.from(rawSubActions);
    final data = MetaAction(label: label, subActions: subActions);
    return ctx.addNode(data, column);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as MetaAction;
    return {
      "label": data.label,
      "sub_actions": data.subActions
    };
  }
}

class LogicActions extends NodeObject {
  List<String> metaActionIds;
  List<String> thresholdIds;
  int nThresholds;
  bool allowRecurrence;
  List<Gate> allowedGates;

  @override
  String get nodeType => "logic_actions";

  LogicActions({
    required this.metaActionIds,
    required this.thresholdIds,
    required this.nThresholds,
    required this.allowRecurrence,
    required this.allowedGates
  });

  static int get fieldCount => 3;

  static List<Port> ports() {
    final topOffset = portTopOffset(fieldCount);
    return [
      ...inputPort(2, fieldCount),
      ...outputPorts(["meta_actions", "thresholds"], topOffset)
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int column) {
    final rawMetaActions = json["meta_actions"] as List<dynamic>;
    final metaActionIds = <String>[];
    for (final raw in rawMetaActions) {
      final map = raw as Map<String, dynamic>;
      final id = MetaAction.flatten(ctx, map, column + 1);
      metaActionIds.add(id);
    }
    final rawThresholds = json["thresholds"] as List<dynamic>;
    final thresholdIds = <String>[];
    for (final raw in rawThresholds) {
      final map = raw as Map<String, dynamic>;
      final id = ThresholdRange.flatten(ctx, map, column + 1);
      thresholdIds.add(id);
    }
    final nThresholds = json["n_thresholds"] as int;
    final allowRecurrence = json["allow_recurrence"] as bool;
    final rawGates = json["allowed_gates"] as List<dynamic>;
    final allowedGates = listFromJson(rawGates, (val) {
      final str = val as String;
      return Gate.fromJson(str);
    });
    final data = LogicActions(
      metaActionIds: metaActionIds,
      thresholdIds: thresholdIds,
      nThresholds: nThresholds,
      allowRecurrence: allowRecurrence,
      allowedGates: allowedGates
    );
    final parentId = ctx.addNode(data, column);
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
      "meta_actions": metaList,
      "thresholds": threshList,
      "n_thresholds": data.nThresholds,
      "allow_recurrence": data.allowRecurrence,
      "allowed_gates": gatesList
    };
  }
}

class DecisionActions extends NodeObject {
  List<String> metaActionIds;
  List<String> thresholdIds;
  int nThresholds;
  bool allowRefs;

  @override
  String get nodeType => "decision_actions";

  DecisionActions({
    required this.metaActionIds,
    required this.thresholdIds,
    required this.nThresholds,
    required this.allowRefs
  });

  static int get fieldCount => 2;

  static List<Port> ports() {
    final topOffset = portTopOffset(fieldCount);
    return [
      ...inputPort(2, fieldCount),
      ...outputPorts(["meta_actions", "thresholds"], topOffset)
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int column) {
    final rawMetaActions = json["meta_actions"] as List<dynamic>;
    final metaActionIds = <String>[];
    for (final raw in rawMetaActions) {
      final map = raw as Map<String, dynamic>;
      final id = MetaAction.flatten(ctx, map, column + 1);
      metaActionIds.add(id);
    }
    final rawThresholds = json["thresholds"] as List<dynamic>;
    final thresholdIds = <String>[];
    for (final raw in rawThresholds) {
      final map = raw as Map<String, dynamic>;
      final id = ThresholdRange.flatten(ctx, map, column + 1);
      thresholdIds.add(id);
    }
    final nThresholds = json["n_thresholds"] as int;
    final allowRefs = json["allow_refs"] as bool;
    final data = DecisionActions(
      metaActionIds: metaActionIds,
      thresholdIds: thresholdIds,
      nThresholds: nThresholds,
      allowRefs: allowRefs
    );
    final parentId = ctx.addNode(data, column);
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
      "meta_actions": metaList,
      "thresholds": threshList,
      "n_thresholds": data.nThresholds,
      "allow_refs": data.allowRefs
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
        NodeTextField(
          label: "featId",
          value: data.featId,
          onChanged: (val) => data.featId = val
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "min",
          value: data.min.toString(),
          onChanged: (val) => data.min = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "max",
          value: data.max.toString(),
          onChanged: (val) => data.max = double.tryParse(val) ?? 0
        )
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
        NodeTextField(
          label: "label",
          value: data.label,
          onChanged: (val) => data.label = val
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "subActs",
          value: data.subActions.join(","),
          onChanged: (val) {
            data.subActions = val.split(",")
                .map((str) => str.trim())
                .where((str) => str.isNotEmpty)
                .toList();
          }
        )
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
        NodeTextField(
          label: "nThresh",
          value: data.nThresholds.toString(),
          onChanged: (val) => data.nThresholds = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeCheckbox(
          label: "recurrence",
          value: data.allowRecurrence,
          onChanged: (val) => data.allowRecurrence = val
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "gates",
          value: data.allowedGates.map((gate) => gate.name).join(","),
          onChanged: (val) {
            data.allowedGates = val.split(",")
                .map((str) => str.trim())
                .where((str) => str.isNotEmpty)
                .map(Gate.fromJson)
                .toList();
          }
        )
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
        NodeTextField(
          label: "nThresh",
          value: data.nThresholds.toString(),
          onChanged: (val) => data.nThresholds = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeCheckbox(
          label: "allowRefs",
          value: data.allowRefs,
          onChanged: (val) => data.allowRefs = val
        )
      ]
    );
  }
}
