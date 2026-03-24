import 'package:alphchemy/model/json_helpers.dart';
import 'package:alphchemy/model/network.dart';
import 'package:alphchemy/model/features.dart';
import 'package:alphchemy/model/actions.dart';
import 'package:alphchemy/model/optimizer.dart';

class BacktestSchema {
  final int startOffset;
  final double startBalance;
  final int delay;

  BacktestSchema({required this.startOffset, required this.startBalance, required this.delay});

  factory BacktestSchema.fromJson(Map<String, dynamic> json) {
    final startOffset = json['start_offset'] as int;
    final startBalance = doubleFromJson(json['start_balance']);
    final delay = json['delay'] as int;

    return BacktestSchema(
      startOffset: startOffset,
      startBalance: startBalance,
      delay: delay
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_offset': startOffset,
      'start_balance': startBalance,
      'delay': delay
    };
  }
}

class EntrySchema {
  final NodePtr nodePtr;
  final double positionSize;
  final int maxPositions;

  EntrySchema({required this.nodePtr, required this.positionSize, required this.maxPositions});

  factory EntrySchema.fromJson(Map<String, dynamic> json) {
    final nodePtrJson = json['node_ptr'] as Map<String, dynamic>;
    final nodePtr = NodePtr.fromJson(nodePtrJson);
    final positionSize = doubleFromJson(json['position_size']);
    final maxPositions = json['max_positions'] as int;

    return EntrySchema(
      nodePtr: nodePtr,
      positionSize: positionSize,
      maxPositions: maxPositions
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_ptr': nodePtr.toJson(),
      'position_size': positionSize,
      'max_positions': maxPositions
    };
  }
}

EntrySchema entrySchemaFromDynamic(dynamic val) {
  final map = val as Map<String, dynamic>;
  return EntrySchema.fromJson(map);
}

class ExitSchema {
  final NodePtr nodePtr;
  final List<int> entryIndices;
  final double stopLoss;
  final double takeProfit;
  final int maxHoldTime;

  ExitSchema({required this.nodePtr, required this.entryIndices, required this.stopLoss, required this.takeProfit, required this.maxHoldTime});

  factory ExitSchema.fromJson(Map<String, dynamic> json) {
    final nodePtrJson = json['node_ptr'] as Map<String, dynamic>;
    final nodePtr = NodePtr.fromJson(nodePtrJson);
    final rawIndices = json['entry_indices'] as List<dynamic>;
    final entryIndices = List<int>.from(rawIndices);
    final stopLoss = doubleFromJson(json['stop_loss']);
    final takeProfit = doubleFromJson(json['take_profit']);
    final maxHoldTime = json['max_hold_time'] as int;

    return ExitSchema(
      nodePtr: nodePtr,
      entryIndices: entryIndices,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      maxHoldTime: maxHoldTime
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_ptr': nodePtr.toJson(),
      'entry_indices': entryIndices,
      'stop_loss': stopLoss,
      'take_profit': takeProfit,
      'max_hold_time': maxHoldTime
    };
  }
}

ExitSchema exitSchemaFromDynamic(dynamic val) {
  final map = val as Map<String, dynamic>;
  return ExitSchema.fromJson(map);
}

class NetworkGen {
  final String type;
  final LogicNet? logicNet;
  final DecisionNet? decisionNet;

  NetworkGen({required this.type, required this.logicNet, required this.decisionNet});

  factory NetworkGen.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final logicJson = json['logic_net'] as Map<String, dynamic>?;
    final logicNet = logicJson != null ? LogicNet.fromJson(logicJson) : null;
    final decisionJson = json['decision_net'] as Map<String, dynamic>?;
    final decisionNet = decisionJson != null ? DecisionNet.fromJson(decisionJson) : null;

    return NetworkGen(
      type: type,
      logicNet: logicNet,
      decisionNet: decisionNet
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'logic_net': logicNet?.toJson(),
      'decision_net': decisionNet?.toJson()
    };
  }
}

class PenaltiesGen {
  final String type;
  final LogicPenalties? logicPenalties;
  final DecisionPenalties? decisionPenalties;

  PenaltiesGen({required this.type, required this.logicPenalties, required this.decisionPenalties});

  factory PenaltiesGen.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final logicJson = json['logic_penalties'] as Map<String, dynamic>?;
    final logicPenalties = logicJson != null ? LogicPenalties.fromJson(logicJson) : null;
    final decisionJson = json['decision_penalties'] as Map<String, dynamic>?;
    final decisionPenalties = decisionJson != null ? DecisionPenalties.fromJson(decisionJson) : null;

    return PenaltiesGen(
      type: type,
      logicPenalties: logicPenalties,
      decisionPenalties: decisionPenalties
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'logic_penalties': logicPenalties?.toJson(),
      'decision_penalties': decisionPenalties?.toJson()
    };
  }
}

class ActionsGen {
  final String type;
  final LogicActions? logicActions;
  final DecisionActions? decisionActions;

  ActionsGen({required this.type, required this.logicActions, required this.decisionActions});

  factory ActionsGen.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final logicJson = json['logic_actions'] as Map<String, dynamic>?;
    final logicActions = logicJson != null ? LogicActions.fromJson(logicJson) : null;
    final decisionJson = json['decision_actions'] as Map<String, dynamic>?;
    final decisionActions = decisionJson != null ? DecisionActions.fromJson(decisionJson) : null;

    return ActionsGen(
      type: type,
      logicActions: logicActions,
      decisionActions: decisionActions
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'logic_actions': logicActions?.toJson(),
      'decision_actions': decisionActions?.toJson()
    };
  }
}

class Strategy {
  final dynamic baseNet;
  final List<Feature> feats;
  final dynamic actions;
  final dynamic penalties;
  final StopConds stopConds;
  final GeneticOpt opt;
  final List<EntrySchema> entrySchemas;
  final List<ExitSchema> exitSchemas;

  Strategy({
    required this.baseNet,
    required this.feats,
    required this.actions,
    required this.penalties,
    required this.stopConds,
    required this.opt,
    required this.entrySchemas,
    required this.exitSchemas
  });

  factory Strategy.fromJson(Map<String, dynamic> json) {
    final netJson = json['base_net'] as Map<String, dynamic>;
    final netType = netJson['type'] as String;
    final dynamic baseNet;

    if (netType == 'logic_net') {
      baseNet = LogicNet.fromJson(netJson['logic_net']);
    } else {
      baseNet = DecisionNet.fromJson(netJson['decision_net']);
    }

    final rawFeats = json['feats'] as List<dynamic>;
    final feats = listFromJson(rawFeats, featureFromDynamic);
    final actionsJson = json['actions'] as Map<String, dynamic>;
    final actionsType = actionsJson['type'] as String;
    final dynamic actions;

    if (actionsType == 'logic_actions') {
      actions = LogicActions.fromJson(actionsJson['logic_actions']);
    } else {
      actions = DecisionActions.fromJson(actionsJson['decision_actions']);
    }

    final penaltiesJson = json['penalties'] as Map<String, dynamic>;
    final penaltiesType = penaltiesJson['type'] as String;
    final dynamic penalties;
    if (penaltiesType == 'logic_penalties') {
      penalties = LogicPenalties.fromJson(penaltiesJson['logic_penalties']);
    } else {
      penalties = DecisionPenalties.fromJson(penaltiesJson['decision_penalties']);
    }
    final stopCondsJson = json['stop_conds'] as Map<String, dynamic>;
    final stopConds = StopConds.fromJson(stopCondsJson);
    final optJson = json['opt'] as Map<String, dynamic>;
    final opt = GeneticOpt.fromJson(optJson);
    final rawEntries = json['entry_schemas'] as List<dynamic>;
    final entrySchemas = listFromJson(rawEntries, entrySchemaFromDynamic);
    final rawExits = json['exit_schemas'] as List<dynamic>;
    final exitSchemas = listFromJson(rawExits, exitSchemaFromDynamic);

    return Strategy(
      baseNet: baseNet,
      feats: feats,
      actions: actions,
      penalties: penalties,
      stopConds: stopConds,
      opt: opt,
      entrySchemas: entrySchemas,
      exitSchemas: exitSchemas
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> netJson;
    if (baseNet is LogicNet) {
      netJson = {'type': 'logic_net', 'logic_net': baseNet.toJson(), 'decision_net': null};
    } else {
      netJson = {'type': 'decision_net', 'logic_net': null, 'decision_net': baseNet.toJson()};
    }
    final featsList = listFromJson(feats, (feat) => feat.toJson());
    
    final Map<String, dynamic> actionsJson;
    if (actions is LogicActions) {
      actionsJson = {'type': 'logic_actions', 'logic_actions': actions.toJson(), 'decision_actions': null};
    } else {
      actionsJson = {'type': 'decision_actions', 'logic_actions': null, 'decision_actions': actions.toJson()};
    }

    final Map<String, dynamic> penaltiesJson;
    if (penalties is LogicPenalties) {
      penaltiesJson = {'type': 'logic_penalties', 'logic_penalties': penalties.toJson(), 'decision_penalties': null};
    } else {
      penaltiesJson = {'type': 'decision_penalties', 'logic_penalties': null, 'decision_penalties': penalties.toJson()};
    }

    final entriesList = listFromJson(entrySchemas, (entry) => entry.toJson());
    final exitsList = listFromJson(exitSchemas, (exit) => exit.toJson());

    return {
      'base_net': netJson,
      'feats': featsList,
      'actions': actionsJson,
      'penalties': penaltiesJson,
      'stop_conds': stopConds.toJson(),
      'opt': opt.toJson(),
      'entry_schemas': entriesList,
      'exit_schemas': exitsList
    };
  }
}

class StrategyGen {
  final NetworkGen baseNet;
  final List<Feature> featPool;
  final List<int> featSelection;
  final ActionsGen actions;
  final PenaltiesGen penalties;
  final StopConds stopConds;
  final GeneticOpt opt;
  final List<EntrySchema> entryPool;
  final List<int> entrySelection;
  final List<ExitSchema> exitPool;
  final List<int> exitSelection;

  StrategyGen({
    required this.baseNet,
    required this.featPool,
    required this.featSelection,
    required this.actions,
    required this.penalties,
    required this.stopConds,
    required this.opt,
    required this.entryPool,
    required this.entrySelection,
    required this.exitPool,
    required this.exitSelection
  });

  factory StrategyGen.fromJson(Map<String, dynamic> json) {
    final baseNetJson = json['base_net'] as Map<String, dynamic>;
    final baseNet = NetworkGen.fromJson(baseNetJson);
    final rawFeatPool = json['feat_pool'] as List<dynamic>;
    final featPool = listFromJson(rawFeatPool, featureFromDynamic);
    final rawFeatSelection = json['feat_selection'] as List<dynamic>;
    final featSelection = List<int>.from(rawFeatSelection);
    final actionsJson = json['actions'] as Map<String, dynamic>;
    final actions = ActionsGen.fromJson(actionsJson);
    final penaltiesJson = json['penalties'] as Map<String, dynamic>;
    final penalties = PenaltiesGen.fromJson(penaltiesJson);
    final stopCondsJson = json['stop_conds'] as Map<String, dynamic>;
    final stopConds = StopConds.fromJson(stopCondsJson);
    final optJson = json['opt'] as Map<String, dynamic>;
    final opt = GeneticOpt.fromJson(optJson);
    final rawEntryPool = json['entry_pool'] as List<dynamic>;
    final entryPool = listFromJson(rawEntryPool, entrySchemaFromDynamic);
    final rawEntrySelection = json['entry_selection'] as List<dynamic>;
    final entrySelection = List<int>.from(rawEntrySelection);
    final rawExitPool = json['exit_pool'] as List<dynamic>;
    final exitPool = listFromJson(rawExitPool, exitSchemaFromDynamic);
    final rawExitSelection = json['exit_selection'] as List<dynamic>;
    final exitSelection = List<int>.from(rawExitSelection);
    return StrategyGen(
      baseNet: baseNet,
      featPool: featPool,
      featSelection: featSelection,
      actions: actions,
      penalties: penalties,
      stopConds: stopConds,
      opt: opt,
      entryPool: entryPool,
      entrySelection: entrySelection,
      exitPool: exitPool,
      exitSelection: exitSelection
    );
  }

  Map<String, dynamic> toJson() {
    final featPoolList = listFromJson(featPool, (feat) => feat.toJson());
    final entryPoolList = listFromJson(entryPool, (entry) => entry.toJson());
    final exitPoolList = listFromJson(exitPool, (exit) => exit.toJson());
    return {
      'base_net': baseNet.toJson(),
      'feat_pool': featPoolList,
      'feat_selection': featSelection,
      'actions': actions.toJson(),
      'penalties': penalties.toJson(),
      'stop_conds': stopConds.toJson(),
      'opt': opt.toJson(),
      'entry_pool': entryPoolList,
      'entry_selection': entrySelection,
      'exit_pool': exitPoolList,
      'exit_selection': exitSelection
    };
  }
}

class Experiment {
  final double valSize;
  final double testSize;
  final int cvFolds;
  final double foldSize;
  final BacktestSchema backtestSchema;
  final Strategy strategy;

  Experiment({
    required this.valSize,
    required this.testSize,
    required this.cvFolds,
    required this.foldSize,
    required this.backtestSchema,
    required this.strategy
  });

  factory Experiment.fromJson(Map<String, dynamic> json) {
    final valSize = doubleFromJson(json['val_size']);
    final testSize = doubleFromJson(json['test_size']);
    final cvFolds = json['cv_folds'] as int;
    final foldSize = doubleFromJson(json['fold_size']);
    final backtestJson = json['backtest_schema'] as Map<String, dynamic>;
    final backtestSchema = BacktestSchema.fromJson(backtestJson);
    final strategyJson = json['strategy'] as Map<String, dynamic>;
    final strategy = Strategy.fromJson(strategyJson);
    return Experiment(
      valSize: valSize,
      testSize: testSize,
      cvFolds: cvFolds,
      foldSize: foldSize,
      backtestSchema: backtestSchema,
      strategy: strategy
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'val_size': valSize,
      'test_size': testSize,
      'cv_folds': cvFolds,
      'fold_size': foldSize,
      'backtest_schema': backtestSchema.toJson(),
      'strategy': strategy.toJson()
    };
  }
}

class ExperimentGenerator {
  final String title;
  final double valSize;
  final double testSize;
  final int cvFolds;
  final double foldSize;
  final BacktestSchema backtestSchema;
  final StrategyGen strategy;

  ExperimentGenerator({
    required this.title,
    required this.valSize,
    required this.testSize,
    required this.cvFolds,
    required this.foldSize,
    required this.backtestSchema,
    required this.strategy
  });

  factory ExperimentGenerator.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String;
    final valSize = doubleFromJson(json['val_size']);
    final testSize = doubleFromJson(json['test_size']);
    final cvFolds = json['cv_folds'] as int;
    final foldSize = doubleFromJson(json['fold_size']);
    final backtestJson = json['backtest_schema'] as Map<String, dynamic>;
    final backtestSchema = BacktestSchema.fromJson(backtestJson);
    final strategyJson = json['strategy'] as Map<String, dynamic>;
    final strategy = StrategyGen.fromJson(strategyJson);
    return ExperimentGenerator(
      title: title,
      valSize: valSize,
      testSize: testSize,
      cvFolds: cvFolds,
      foldSize: foldSize,
      backtestSchema: backtestSchema,
      strategy: strategy
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'val_size': valSize,
      'test_size': testSize,
      'cv_folds': cvFolds,
      'fold_size': foldSize,
      'backtest_schema': backtestSchema.toJson(),
      'strategy': strategy.toJson()
    };
  }
}
