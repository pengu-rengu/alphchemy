import 'dart:ui';

import 'package:alphchemy/model/actions.dart';
import 'package:alphchemy/model/experiment.dart';
import 'package:alphchemy/model/features.dart';
import 'package:alphchemy/model/json_helpers.dart';
import 'package:alphchemy/model/network.dart';
import 'package:alphchemy/model/node_object.dart';
import 'package:alphchemy/model/node_ports.dart';
import 'package:alphchemy/model/optimizer.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

final _uuid = Uuid();

class GraphData {
  final List<Node<NodeObject>> nodes;
  final List<Connection> connections;

  GraphData({required this.nodes, required this.connections});
}

GraphData flattenExperimentGen(Map<String, dynamic> json) {
  final nodes = <Node<NodeObject>>[];
  final connections = <Connection>[];
  final yPerCol = <int, double>{};
  var col = 0;

  String addNode(NodeObject data, int column) {
    final yPos = yPerCol[column] ?? 0.0;
    final nodeId = _uuid.v4();
    final ports = portsForNodeType(data.nodeType);
    final outputCount = ports.where((port) {
      return port.type == PortType.output;
    }).length;
    final height = nodeHeight(outputCount);
    yPerCol[column] = yPos + height + 20.0;
    final position = Offset(column * 250.0, yPos);
    final node = Node<NodeObject>(
      id: nodeId,
      type: data.nodeType,
      position: position,
      data: data,
      ports: ports,
      size: Size(200, height)
    );
    nodes.add(node);
    return nodeId;
  }

  void connect(String sourceId, String sourcePort, String targetId) {
    final connId = _uuid.v4();
    final conn = Connection(
      id: connId,
      sourceNodeId: sourceId,
      sourcePortId: sourcePort,
      targetNodeId: targetId,
      targetPortId: 'in'
    );
    connections.add(conn);
  }

  String flattenNodePtr(Map<String, dynamic> json, int column) {
    final anchorStr = json['anchor'] as String;
    final anchor = Anchor.fromJson(anchorStr);
    final idx = json['idx'] as int;
    final data = NodePtr(anchor: anchor, idx: idx);
    return addNode(data, column);
  }

  String flattenLogicNode(Map<String, dynamic> json, int column) {
    final type = json['type'] as String;
    if (type == 'input') {
      final threshold = nullDoubleFromJson(json['threshold']);
      final featIdx = json['feat_idx'] as int?;
      final data = InputNode(threshold: threshold, featIdx: featIdx);
      return addNode(data, column);
    }
    final gateStr = json['gate'] as String?;
    final gate = gateStr != null ? Gate.fromJson(gateStr) : null;
    final in1Idx = json['in1_idx'] as int?;
    final in2Idx = json['in2_idx'] as int?;
    final data = GateNode(gate: gate, in1Idx: in1Idx, in2Idx: in2Idx);
    return addNode(data, column);
  }

  String flattenDecisionNode(Map<String, dynamic> json, int column) {
    final type = json['type'] as String;
    if (type == 'branch') {
      final threshold = nullDoubleFromJson(json['threshold']);
      final featIdx = json['feat_idx'] as int?;
      final trueIdx = json['true_idx'] as int?;
      final falseIdx = json['false_idx'] as int?;
      final data = BranchNode(
        threshold: threshold,
        featIdx: featIdx,
        trueIdx: trueIdx,
        falseIdx: falseIdx
      );
      return addNode(data, column);
    }
    final refIdx = json['ref_idx'] as int?;
    final trueIdx = json['true_idx'] as int?;
    final falseIdx = json['false_idx'] as int?;
    final data = RefNode(refIdx: refIdx, trueIdx: trueIdx, falseIdx: falseIdx);
    return addNode(data, column);
  }

  String flattenLogicNet(Map<String, dynamic> json, int column) {
    final rawNodes = json['nodes'] as List<dynamic>;
    final nodeIds = <String>[];
    for (final raw in rawNodes) {
      final map = raw as Map<String, dynamic>;
      final nodeId = flattenLogicNode(map, column + 1);
      nodeIds.add(nodeId);
    }
    final defaultValue = json['default_value'] as bool;
    final data = LogicNet(nodeIds: nodeIds, defaultValue: defaultValue);
    final parentId = addNode(data, column);
    for (final childId in nodeIds) {
      connect(parentId, 'out_nodes', childId);
    }
    return parentId;
  }

  String flattenDecisionNet(Map<String, dynamic> json, int column) {
    final rawNodes = json['nodes'] as List<dynamic>;
    final nodeIds = <String>[];
    for (final raw in rawNodes) {
      final map = raw as Map<String, dynamic>;
      final nodeId = flattenDecisionNode(map, column + 1);
      nodeIds.add(nodeId);
    }
    final maxTrailLen = json['max_trail_len'] as int;
    final defaultValue = json['default_value'] as bool;
    final data = DecisionNet(
      nodeIds: nodeIds,
      maxTrailLen: maxTrailLen,
      defaultValue: defaultValue
    );
    final parentId = addNode(data, column);
    for (final childId in nodeIds) {
      connect(parentId, 'out_nodes', childId);
    }
    return parentId;
  }

  String flattenLogicPenalties(Map<String, dynamic> json, int column) {
    final data = LogicPenalties(
      node: doubleFromJson(json['node']),
      input: doubleFromJson(json['input']),
      gate: doubleFromJson(json['gate']),
      recurrence: doubleFromJson(json['recurrence']),
      feedforward: doubleFromJson(json['feedforward']),
      usedFeat: doubleFromJson(json['used_feat']),
      unusedFeat: doubleFromJson(json['unused_feat'])
    );
    return addNode(data, column);
  }

  String flattenDecisionPenalties(Map<String, dynamic> json, int column) {
    final data = DecisionPenalties(
      node: doubleFromJson(json['node']),
      branch: doubleFromJson(json['branch']),
      ref: doubleFromJson(json['ref']),
      leaf: doubleFromJson(json['leaf']),
      nonLeaf: doubleFromJson(json['non_leaf']),
      usedFeat: doubleFromJson(json['used_feat']),
      unusedFeat: doubleFromJson(json['unused_feat'])
    );
    return addNode(data, column);
  }

  String flattenFeature(Map<String, dynamic> json, int column) {
    final feature = json['feature'] as String;
    if (feature == 'constant') {
      final featId = json['id'] as String;
      final constant = doubleFromJson(json['constant']);
      final data = ConstantFeature(featId: featId, constant: constant);
      return addNode(data, column);
    }
    final featId = json['id'] as String;
    final returnsTypeStr = json['returns_type'] as String;
    final returnsType = ReturnsType.fromJson(returnsTypeStr);
    final ohlcStr = json['ohlc'] as String;
    final ohlc = OHLC.fromJson(ohlcStr);
    final data = RawReturnsFeature(
      featId: featId,
      returnsType: returnsType,
      ohlc: ohlc
    );
    return addNode(data, column);
  }

  String flattenThresholdRange(Map<String, dynamic> json, int column) {
    final featId = json['feat_id'] as String;
    final min = doubleFromJson(json['min']);
    final max = doubleFromJson(json['max']);
    final data = ThresholdRange(featId: featId, min: min, max: max);
    return addNode(data, column);
  }

  String flattenMetaAction(Map<String, dynamic> json, int column) {
    final label = json['label'] as String;
    final rawSubActions = json['sub_actions'] as List<dynamic>;
    final subActions = List<String>.from(rawSubActions);
    final data = MetaAction(label: label, subActions: subActions);
    return addNode(data, column);
  }

  String flattenLogicActions(Map<String, dynamic> json, int column) {
    final rawMetaActions = json['meta_actions'] as List<dynamic>;
    final metaActionIds = <String>[];
    for (final raw in rawMetaActions) {
      final map = raw as Map<String, dynamic>;
      final id = flattenMetaAction(map, column + 1);
      metaActionIds.add(id);
    }
    final rawThresholds = json['thresholds'] as List<dynamic>;
    final thresholdIds = <String>[];
    for (final raw in rawThresholds) {
      final map = raw as Map<String, dynamic>;
      final id = flattenThresholdRange(map, column + 1);
      thresholdIds.add(id);
    }
    final nThresholds = json['n_thresholds'] as int;
    final allowRecurrence = json['allow_recurrence'] as bool;
    final rawGates = json['allowed_gates'] as List<dynamic>;
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
    final parentId = addNode(data, column);
    for (final childId in metaActionIds) {
      connect(parentId, 'out_meta_actions', childId);
    }
    for (final childId in thresholdIds) {
      connect(parentId, 'out_thresholds', childId);
    }
    return parentId;
  }

  String flattenDecisionActions(Map<String, dynamic> json, int column) {
    final rawMetaActions = json['meta_actions'] as List<dynamic>;
    final metaActionIds = <String>[];
    for (final raw in rawMetaActions) {
      final map = raw as Map<String, dynamic>;
      final id = flattenMetaAction(map, column + 1);
      metaActionIds.add(id);
    }
    final rawThresholds = json['thresholds'] as List<dynamic>;
    final thresholdIds = <String>[];
    for (final raw in rawThresholds) {
      final map = raw as Map<String, dynamic>;
      final id = flattenThresholdRange(map, column + 1);
      thresholdIds.add(id);
    }
    final nThresholds = json['n_thresholds'] as int;
    final allowRefs = json['allow_refs'] as bool;
    final data = DecisionActions(
      metaActionIds: metaActionIds,
      thresholdIds: thresholdIds,
      nThresholds: nThresholds,
      allowRefs: allowRefs
    );
    final parentId = addNode(data, column);
    for (final childId in metaActionIds) {
      connect(parentId, 'out_meta_actions', childId);
    }
    for (final childId in thresholdIds) {
      connect(parentId, 'out_thresholds', childId);
    }
    return parentId;
  }

  String flattenStopConds(Map<String, dynamic> json, int column) {
    final data = StopConds(
      maxIters: json['max_iters'] as int,
      trainPatience: json['train_patience'] as int,
      valPatience: json['val_patience'] as int
    );
    return addNode(data, column);
  }

  String flattenGeneticOpt(Map<String, dynamic> json, int column) {
    final data = GeneticOpt(
      popSize: json['pop_size'] as int,
      seqLen: json['seq_len'] as int,
      nElites: json['n_elites'] as int,
      mutRate: doubleFromJson(json['mut_rate']),
      crossRate: doubleFromJson(json['cross_rate']),
      tournSize: json['tournament_size'] as int
    );
    return addNode(data, column);
  }

  String flattenBacktestSchema(Map<String, dynamic> json, int column) {
    final data = BacktestSchema(
      startOffset: json['start_offset'] as int,
      startBalance: doubleFromJson(json['start_balance']),
      delay: json['delay'] as int
    );
    return addNode(data, column);
  }

  String flattenEntrySchema(Map<String, dynamic> json, int column) {
    final nodePtrJson = json['node_ptr'] as Map<String, dynamic>;
    final nodePtrId = flattenNodePtr(nodePtrJson, column + 1);
    final positionSize = doubleFromJson(json['position_size']);
    final maxPositions = json['max_positions'] as int;
    final data = EntrySchema(
      nodePtrId: nodePtrId,
      positionSize: positionSize,
      maxPositions: maxPositions
    );
    final parentId = addNode(data, column);
    connect(parentId, 'out_node_ptr', nodePtrId);
    return parentId;
  }

  String flattenExitSchema(Map<String, dynamic> json, int column) {
    final nodePtrJson = json['node_ptr'] as Map<String, dynamic>;
    final nodePtrId = flattenNodePtr(nodePtrJson, column + 1);
    final rawIndices = json['entry_indices'] as List<dynamic>;
    final entryIndices = List<int>.from(rawIndices);
    final stopLoss = doubleFromJson(json['stop_loss']);
    final takeProfit = doubleFromJson(json['take_profit']);
    final maxHoldTime = json['max_hold_time'] as int;
    final data = ExitSchema(
      nodePtrId: nodePtrId,
      entryIndices: entryIndices,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      maxHoldTime: maxHoldTime
    );
    final parentId = addNode(data, column);
    connect(parentId, 'out_node_ptr', nodePtrId);
    return parentId;
  }

  String flattenNetworkGen(Map<String, dynamic> json, int column) {
    final type = json['type'] as String;
    String? logicNetId;
    String? decisionNetId;
    final logicJson = json['logic_net'] as Map<String, dynamic>?;
    if (logicJson != null) {
      logicNetId = flattenLogicNet(logicJson, column + 1);
    }
    final decisionJson = json['decision_net'] as Map<String, dynamic>?;
    if (decisionJson != null) {
      decisionNetId = flattenDecisionNet(decisionJson, column + 1);
    }
    final data = NetworkGen(
      type: type,
      logicNetId: logicNetId,
      decisionNetId: decisionNetId
    );
    final parentId = addNode(data, column);
    if (logicNetId != null) {
      connect(parentId, 'out_logic_net', logicNetId);
    }
    if (decisionNetId != null) {
      connect(parentId, 'out_decision_net', decisionNetId);
    }
    return parentId;
  }

  String flattenActionsGen(Map<String, dynamic> json, int column) {
    final type = json['type'] as String;
    String? logicActionsId;
    String? decisionActionsId;
    final logicJson = json['logic_actions'] as Map<String, dynamic>?;
    if (logicJson != null) {
      logicActionsId = flattenLogicActions(logicJson, column + 1);
    }
    final decisionJson = json['decision_actions'] as Map<String, dynamic>?;
    if (decisionJson != null) {
      decisionActionsId = flattenDecisionActions(decisionJson, column + 1);
    }
    final data = ActionsGen(
      type: type,
      logicActionsId: logicActionsId,
      decisionActionsId: decisionActionsId
    );
    final parentId = addNode(data, column);
    if (logicActionsId != null) {
      connect(parentId, 'out_logic_actions', logicActionsId);
    }
    if (decisionActionsId != null) {
      connect(parentId, 'out_decision_actions', decisionActionsId);
    }
    return parentId;
  }

  String flattenPenaltiesGen(Map<String, dynamic> json, int column) {
    final type = json['type'] as String;
    String? logicPenaltiesId;
    String? decisionPenaltiesId;
    final logicJson = json['logic_penalties'] as Map<String, dynamic>?;
    if (logicJson != null) {
      logicPenaltiesId = flattenLogicPenalties(logicJson, column + 1);
    }
    final decisionJson = json['decision_penalties'] as Map<String, dynamic>?;
    if (decisionJson != null) {
      decisionPenaltiesId = flattenDecisionPenalties(decisionJson, column + 1);
    }
    final data = PenaltiesGen(
      type: type,
      logicPenaltiesId: logicPenaltiesId,
      decisionPenaltiesId: decisionPenaltiesId
    );
    final parentId = addNode(data, column);
    if (logicPenaltiesId != null) {
      connect(parentId, 'out_logic_penalties', logicPenaltiesId);
    }
    if (decisionPenaltiesId != null) {
      connect(parentId, 'out_decision_penalties', decisionPenaltiesId);
    }
    return parentId;
  }

  String flattenStrategyGen(Map<String, dynamic> json, int column) {
    final baseNetJson = json['base_net'] as Map<String, dynamic>;
    final baseNetId = flattenNetworkGen(baseNetJson, column + 1);

    final rawFeatPool = json['feat_pool'] as List<dynamic>;
    final featPoolIds = <String>[];
    for (final raw in rawFeatPool) {
      final map = raw as Map<String, dynamic>;
      final id = flattenFeature(map, column + 1);
      featPoolIds.add(id);
    }
    final rawFeatSelection = json['feat_selection'] as List<dynamic>;
    final featSelection = List<int>.from(rawFeatSelection);

    final actionsJson = json['actions'] as Map<String, dynamic>;
    final actionsId = flattenActionsGen(actionsJson, column + 1);

    final penaltiesJson = json['penalties'] as Map<String, dynamic>;
    final penaltiesId = flattenPenaltiesGen(penaltiesJson, column + 1);

    final stopCondsJson = json['stop_conds'] as Map<String, dynamic>;
    final stopCondsId = flattenStopConds(stopCondsJson, column + 1);

    final optJson = json['opt'] as Map<String, dynamic>;
    final optId = flattenGeneticOpt(optJson, column + 1);

    final rawEntryPool = json['entry_pool'] as List<dynamic>;
    final entryPoolIds = <String>[];
    for (final raw in rawEntryPool) {
      final map = raw as Map<String, dynamic>;
      final id = flattenEntrySchema(map, column + 1);
      entryPoolIds.add(id);
    }
    final rawEntrySelection = json['entry_selection'] as List<dynamic>;
    final entrySelection = List<int>.from(rawEntrySelection);

    final rawExitPool = json['exit_pool'] as List<dynamic>;
    final exitPoolIds = <String>[];
    for (final raw in rawExitPool) {
      final map = raw as Map<String, dynamic>;
      final id = flattenExitSchema(map, column + 1);
      exitPoolIds.add(id);
    }
    final rawExitSelection = json['exit_selection'] as List<dynamic>;
    final exitSelection = List<int>.from(rawExitSelection);

    final data = StrategyGen(
      baseNetId: baseNetId,
      featPoolIds: featPoolIds,
      featSelection: featSelection,
      actionsId: actionsId,
      penaltiesId: penaltiesId,
      stopCondsId: stopCondsId,
      optId: optId,
      entryPoolIds: entryPoolIds,
      entrySelection: entrySelection,
      exitPoolIds: exitPoolIds,
      exitSelection: exitSelection
    );
    final parentId = addNode(data, column);
    connect(parentId, 'out_base_net', baseNetId);
    for (final childId in featPoolIds) {
      connect(parentId, 'out_feat_pool', childId);
    }
    connect(parentId, 'out_actions', actionsId);
    connect(parentId, 'out_penalties', penaltiesId);
    connect(parentId, 'out_stop_conds', stopCondsId);
    connect(parentId, 'out_opt', optId);
    for (final childId in entryPoolIds) {
      connect(parentId, 'out_entry_pool', childId);
    }
    for (final childId in exitPoolIds) {
      connect(parentId, 'out_exit_pool', childId);
    }
    return parentId;
  }

  col = 0;
  final title = json['title'] as String;
  final valSize = doubleFromJson(json['val_size']);
  final testSize = doubleFromJson(json['test_size']);
  final cvFolds = json['cv_folds'] as int;
  final foldSize = doubleFromJson(json['fold_size']);

  final backtestJson = json['backtest_schema'] as Map<String, dynamic>;
  final backtestSchemaId = flattenBacktestSchema(backtestJson, col + 1);

  final strategyJson = json['strategy'] as Map<String, dynamic>;
  final strategyId = flattenStrategyGen(strategyJson, col + 1);

  final rootData = ExperimentGenerator(
    title: title,
    valSize: valSize,
    testSize: testSize,
    cvFolds: cvFolds,
    foldSize: foldSize,
    backtestSchemaId: backtestSchemaId,
    strategyId: strategyId
  );
  final rootId = addNode(rootData, col);
  connect(rootId, 'out_backtest_schema', backtestSchemaId);
  connect(rootId, 'out_strategy', strategyId);

  return GraphData(nodes: nodes, connections: connections);
}

Node<NodeObject>? _findNode(List<Node<NodeObject>> nodes, String id) {
  for (final node in nodes) {
    if (node.id == id) return node;
  }
  return null;
}

List<String> _childIds(
  List<Connection> connections,
  String parentId,
  String sourcePort
) {
  final ids = <String>[];
  for (final conn in connections) {
    final matchesParent = conn.sourceNodeId == parentId;
    final matchesPort = conn.sourcePortId == sourcePort;
    if (matchesParent && matchesPort) {
      ids.add(conn.targetNodeId);
    }
  }
  return ids;
}

String? _childId(
  List<Connection> connections,
  String parentId,
  String sourcePort
) {
  final ids = _childIds(connections, parentId, sourcePort);
  if (ids.isEmpty) return null;
  return ids.first;
}

Map<String, dynamic> assembleExperimentGen(
  List<Node<NodeObject>> nodes,
  List<Connection> connections
) {
  Map<String, dynamic> assembleNodePtr(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as NodePtr;
    return {
      'anchor': data.anchor.toJson(),
      'idx': data.idx
    };
  }

  Map<String, dynamic> assembleLogicNode(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data;
    if (data is InputNode) {
      return {
        'type': 'input',
        'threshold': data.threshold,
        'feat_idx': data.featIdx
      };
    }
    final gate = data as GateNode;
    return {
      'type': 'gate',
      'gate': gate.gate?.toJson(),
      'in1_idx': gate.in1Idx,
      'in2_idx': gate.in2Idx
    };
  }

  Map<String, dynamic> assembleDecisionNode(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data;
    if (data is BranchNode) {
      return {
        'type': 'branch',
        'threshold': data.threshold,
        'feat_idx': data.featIdx,
        'true_idx': data.trueIdx,
        'false_idx': data.falseIdx
      };
    }
    final ref = data as RefNode;
    return {
      'type': 'ref',
      'ref_idx': ref.refIdx,
      'true_idx': ref.trueIdx,
      'false_idx': ref.falseIdx
    };
  }

  Map<String, dynamic> assembleLogicNet(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as LogicNet;
    final childNodeIds = _childIds(connections, nodeId, 'out_nodes');
    final nodesList = childNodeIds.map(assembleLogicNode).toList();
    return {
      'nodes': nodesList,
      'default_value': data.defaultValue
    };
  }

  Map<String, dynamic> assembleDecisionNet(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as DecisionNet;
    final childNodeIds = _childIds(connections, nodeId, 'out_nodes');
    final nodesList = childNodeIds.map(assembleDecisionNode).toList();
    return {
      'nodes': nodesList,
      'max_trail_len': data.maxTrailLen,
      'default_value': data.defaultValue
    };
  }

  Map<String, dynamic> assembleLogicPenalties(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as LogicPenalties;
    return {
      'node': data.node,
      'input': data.input,
      'gate': data.gate,
      'recurrence': data.recurrence,
      'feedforward': data.feedforward,
      'used_feat': data.usedFeat,
      'unused_feat': data.unusedFeat
    };
  }

  Map<String, dynamic> assembleDecisionPenalties(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as DecisionPenalties;
    return {
      'node': data.node,
      'branch': data.branch,
      'ref': data.ref,
      'leaf': data.leaf,
      'non_leaf': data.nonLeaf,
      'used_feat': data.usedFeat,
      'unused_feat': data.unusedFeat
    };
  }

  Map<String, dynamic> assembleFeature(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data;
    if (data is ConstantFeature) {
      return {
        'feature': 'constant',
        'id': data.featId,
        'constant': data.constant
      };
    }
    final raw = data as RawReturnsFeature;
    return {
      'feature': 'raw_returns',
      'id': raw.featId,
      'returns_type': raw.returnsType.toJson(),
      'ohlc': raw.ohlc.toJson()
    };
  }

  Map<String, dynamic> assembleThresholdRange(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as ThresholdRange;
    return {
      'feat_id': data.featId,
      'min': data.min,
      'max': data.max
    };
  }

  Map<String, dynamic> assembleMetaAction(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as MetaAction;
    return {
      'label': data.label,
      'sub_actions': data.subActions
    };
  }

  Map<String, dynamic> assembleLogicActions(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as LogicActions;
    final metaIds = _childIds(connections, nodeId, 'out_meta_actions');
    final threshIds = _childIds(connections, nodeId, 'out_thresholds');
    final metaList = metaIds.map(assembleMetaAction).toList();
    final threshList = threshIds.map(assembleThresholdRange).toList();
    final gatesList = data.allowedGates.map((gate) => gate.toJson()).toList();
    return {
      'meta_actions': metaList,
      'thresholds': threshList,
      'n_thresholds': data.nThresholds,
      'allow_recurrence': data.allowRecurrence,
      'allowed_gates': gatesList
    };
  }

  Map<String, dynamic> assembleDecisionActions(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as DecisionActions;
    final metaIds = _childIds(connections, nodeId, 'out_meta_actions');
    final threshIds = _childIds(connections, nodeId, 'out_thresholds');
    final metaList = metaIds.map(assembleMetaAction).toList();
    final threshList = threshIds.map(assembleThresholdRange).toList();
    return {
      'meta_actions': metaList,
      'thresholds': threshList,
      'n_thresholds': data.nThresholds,
      'allow_refs': data.allowRefs
    };
  }

  Map<String, dynamic> assembleStopConds(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as StopConds;
    return {
      'max_iters': data.maxIters,
      'train_patience': data.trainPatience,
      'val_patience': data.valPatience
    };
  }

  Map<String, dynamic> assembleGeneticOpt(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as GeneticOpt;
    return {
      'pop_size': data.popSize,
      'seq_len': data.seqLen,
      'n_elites': data.nElites,
      'mut_rate': data.mutRate,
      'cross_rate': data.crossRate,
      'tournament_size': data.tournSize
    };
  }

  Map<String, dynamic> assembleBacktestSchema(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as BacktestSchema;
    return {
      'start_offset': data.startOffset,
      'start_balance': data.startBalance,
      'delay': data.delay
    };
  }

  Map<String, dynamic> assembleEntrySchema(String nodeId) {
    final nodePtrId = _childId(connections, nodeId, 'out_node_ptr')!;
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as EntrySchema;
    return {
      'node_ptr': assembleNodePtr(nodePtrId),
      'position_size': data.positionSize,
      'max_positions': data.maxPositions
    };
  }

  Map<String, dynamic> assembleExitSchema(String nodeId) {
    final nodePtrId = _childId(connections, nodeId, 'out_node_ptr')!;
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as ExitSchema;
    return {
      'node_ptr': assembleNodePtr(nodePtrId),
      'entry_indices': data.entryIndices,
      'stop_loss': data.stopLoss,
      'take_profit': data.takeProfit,
      'max_hold_time': data.maxHoldTime
    };
  }

  Map<String, dynamic> assembleNetworkGen(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as NetworkGen;
    final logicNetNodeId = _childId(connections, nodeId, 'out_logic_net');
    final decisionNetNodeId = _childId(
      connections,
      nodeId,
      'out_decision_net'
    );
    return {
      'type': data.type,
      'logic_net': logicNetNodeId != null
          ? assembleLogicNet(logicNetNodeId)
          : null,
      'decision_net': decisionNetNodeId != null
          ? assembleDecisionNet(decisionNetNodeId)
          : null
    };
  }

  Map<String, dynamic> assembleActionsGen(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as ActionsGen;
    final logicId = _childId(connections, nodeId, 'out_logic_actions');
    final decisionId = _childId(connections, nodeId, 'out_decision_actions');
    return {
      'type': data.type,
      'logic_actions': logicId != null
          ? assembleLogicActions(logicId)
          : null,
      'decision_actions': decisionId != null
          ? assembleDecisionActions(decisionId)
          : null
    };
  }

  Map<String, dynamic> assemblePenaltiesGen(String nodeId) {
    final node = _findNode(nodes, nodeId)!;
    final data = node.data as PenaltiesGen;
    final logicId = _childId(connections, nodeId, 'out_logic_penalties');
    final decisionId = _childId(
      connections,
      nodeId,
      'out_decision_penalties'
    );
    return {
      'type': data.type,
      'logic_penalties': logicId != null
          ? assembleLogicPenalties(logicId)
          : null,
      'decision_penalties': decisionId != null
          ? assembleDecisionPenalties(decisionId)
          : null
    };
  }

  Map<String, dynamic> assembleStrategyGenFromId(String nodeId) {
    final baseNetId = _childId(connections, nodeId, 'out_base_net')!;
    final featIds = _childIds(connections, nodeId, 'out_feat_pool');
    final actionsId = _childId(connections, nodeId, 'out_actions')!;
    final penaltiesId = _childId(connections, nodeId, 'out_penalties')!;
    final stopCondsId = _childId(connections, nodeId, 'out_stop_conds')!;
    final optId = _childId(connections, nodeId, 'out_opt')!;
    final entryIds = _childIds(connections, nodeId, 'out_entry_pool');
    final exitIds = _childIds(connections, nodeId, 'out_exit_pool');

    final node = _findNode(nodes, nodeId)!;
    final data = node.data as StrategyGen;

    final featPoolList = featIds.map(assembleFeature).toList();
    final entryPoolList = entryIds.map(assembleEntrySchema).toList();
    final exitPoolList = exitIds.map(assembleExitSchema).toList();

    return {
      'base_net': assembleNetworkGen(baseNetId),
      'feat_pool': featPoolList,
      'feat_selection': data.featSelection,
      'actions': assembleActionsGen(actionsId),
      'penalties': assemblePenaltiesGen(penaltiesId),
      'stop_conds': assembleStopConds(stopCondsId),
      'opt': assembleGeneticOpt(optId),
      'entry_pool': entryPoolList,
      'entry_selection': data.entrySelection,
      'exit_pool': exitPoolList,
      'exit_selection': data.exitSelection
    };
  }

  Node<NodeObject>? rootNode;
  for (final node in nodes) {
    if (node.data.nodeType == 'experiment_gen') {
      rootNode = node;
      break;
    }
  }

  final rootData = rootNode!.data as ExperimentGenerator;
  final strategyNodeId = _childId(connections, rootNode.id, 'out_strategy')!;
  final backtestNodeId = _childId(
    connections,
    rootNode.id,
    'out_backtest_schema'
  )!;

  return {
    'title': rootData.title,
    'val_size': rootData.valSize,
    'test_size': rootData.testSize,
    'cv_folds': rootData.cvFolds,
    'fold_size': rootData.foldSize,
    'backtest_schema': assembleBacktestSchema(backtestNodeId),
    'strategy': assembleStrategyGenFromId(strategyNodeId)
  };
}
