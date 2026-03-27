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

  ThresholdRange({this.featId = "", this.min = 0.0, this.max = 0.0});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final featId = json["feat_id"] as String;
    final min = doubleFromJson(json["min"]);
    final max = doubleFromJson(json["max"]);
    final data = ThresholdRange(featId: featId, min: min, max: max);
    return ctx.addNode(data);
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

  MetaAction({this.label = "", this.subActions = const []});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final label = json["label"] as String;
    final rawSubActions = json["sub_actions"] as List<dynamic>;
    final subActions = List<String>.from(rawSubActions);
    final data = MetaAction(label: label, subActions: subActions);
    return ctx.addNode(data);
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
    final rawMetaSel = json["meta_action_selection"] as List<dynamic>?;
    final metaActionSelection = rawMetaSel != null
        ? List<int>.from(rawMetaSel)
        : <int>[];
    final thresholdIds = <String>[];
    final rawThresholds = json["threshold_pool"] as List<dynamic>?;
    if (rawThresholds != null) {
      for (final raw in rawThresholds) {
        final map = raw as Map<String, dynamic>;
        thresholdIds.add(ThresholdRange.flatten(ctx, map));
      }
    }
    final rawThreshSel = json["threshold_selection"] as List<dynamic>?;
    final thresholdSelection = rawThreshSel != null
        ? List<int>.from(rawThreshSel)
        : <int>[];
    final nThresholds = json["n_thresholds"] as int? ?? 0;
    final allowRecurrence = json["allow_recurrence"] as bool? ?? false;
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
      "meta_action_selection": data.metaActionSelection,
      "threshold_pool": threshList,
      "threshold_selection": data.thresholdSelection,
      "n_thresholds": data.nThresholds,
      "allow_recurrence": data.allowRecurrence,
      "allowed_gates": gatesList
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
    final rawMetaSel = json["meta_action_selection"] as List<dynamic>?;
    final metaActionSelection = rawMetaSel != null
        ? List<int>.from(rawMetaSel)
        : <int>[];
    final thresholdIds = <String>[];
    final rawThresholds = json["threshold_pool"] as List<dynamic>?;
    if (rawThresholds != null) {
      for (final raw in rawThresholds) {
        final map = raw as Map<String, dynamic>;
        thresholdIds.add(ThresholdRange.flatten(ctx, map));
      }
    }
    final rawThreshSel = json["threshold_selection"] as List<dynamic>?;
    final thresholdSelection = rawThreshSel != null
        ? List<int>.from(rawThreshSel)
        : <int>[];
    final nThresholds = json["n_thresholds"] as int? ?? 0;
    final allowRefs = json["allow_refs"] as bool? ?? false;
    final data = DecisionActions(
      metaActionIds: metaActionIds,
      metaActionSelection: metaActionSelection,
      thresholdIds: thresholdIds,
      thresholdSelection: thresholdSelection,
      nThresholds: nThresholds,
      allowRefs: allowRefs
    );
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
      "meta_action_selection": data.metaActionSelection,
      "threshold_pool": threshList,
      "threshold_selection": data.thresholdSelection,
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
          label: "metaSel",
          value: data.metaActionSelection.join(","),
          onChanged: (val) {
            data.metaActionSelection = parseIntList(val);
          }
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "threshSel",
          value: data.thresholdSelection.join(","),
          onChanged: (val) {
            data.thresholdSelection = parseIntList(val);
          }
        ),
        SizedBox(height: 2),
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
          label: "metaSel",
          value: data.metaActionSelection.join(","),
          onChanged: (val) {
            data.metaActionSelection = parseIntList(val);
          }
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "threshSel",
          value: data.thresholdSelection.join(","),
          onChanged: (val) {
            data.thresholdSelection = parseIntList(val);
          }
        ),
        SizedBox(height: 2),
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
