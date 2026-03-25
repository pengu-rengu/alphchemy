import 'package:alphchemy/model/node_object.dart';

class BacktestSchema extends NodeObject {
  int startOffset;
  double startBalance;
  int delay;

  @override
  String get nodeType => 'backtest_schema';

  BacktestSchema({
    required this.startOffset,
    required this.startBalance,
    required this.delay
  });
}

class EntrySchema extends NodeObject {
  String nodePtrId;
  double positionSize;
  int maxPositions;

  @override
  String get nodeType => 'entry_schema';

  EntrySchema({
    required this.nodePtrId,
    required this.positionSize,
    required this.maxPositions
  });
}

class ExitSchema extends NodeObject {
  String nodePtrId;
  List<int> entryIndices;
  double stopLoss;
  double takeProfit;
  int maxHoldTime;

  @override
  String get nodeType => 'exit_schema';

  ExitSchema({
    required this.nodePtrId,
    required this.entryIndices,
    required this.stopLoss,
    required this.takeProfit,
    required this.maxHoldTime
  });
}

class NetworkGen extends NodeObject {
  String type;
  String? logicNetId;
  String? decisionNetId;

  @override
  String get nodeType => 'network_gen';

  NetworkGen({
    required this.type,
    required this.logicNetId,
    required this.decisionNetId
  });
}

class PenaltiesGen extends NodeObject {
  String type;
  String? logicPenaltiesId;
  String? decisionPenaltiesId;

  @override
  String get nodeType => 'penalties_gen';

  PenaltiesGen({
    required this.type,
    required this.logicPenaltiesId,
    required this.decisionPenaltiesId
  });
}

class ActionsGen extends NodeObject {
  String type;
  String? logicActionsId;
  String? decisionActionsId;

  @override
  String get nodeType => 'actions_gen';

  ActionsGen({
    required this.type,
    required this.logicActionsId,
    required this.decisionActionsId
  });
}

class Strategy extends NodeObject {
  String baseNetId;
  List<String> featIds;
  String actionsId;
  String penaltiesId;
  String stopCondsId;
  String optId;
  List<String> entrySchemaIds;
  List<String> exitSchemaIds;

  @override
  String get nodeType => 'strategy';

  Strategy({
    required this.baseNetId,
    required this.featIds,
    required this.actionsId,
    required this.penaltiesId,
    required this.stopCondsId,
    required this.optId,
    required this.entrySchemaIds,
    required this.exitSchemaIds
  });
}

class StrategyGen extends NodeObject {
  String baseNetId;
  List<String> featPoolIds;
  List<int> featSelection;
  String actionsId;
  String penaltiesId;
  String stopCondsId;
  String optId;
  List<String> entryPoolIds;
  List<int> entrySelection;
  List<String> exitPoolIds;
  List<int> exitSelection;

  @override
  String get nodeType => 'strategy_gen';

  StrategyGen({
    required this.baseNetId,
    required this.featPoolIds,
    required this.featSelection,
    required this.actionsId,
    required this.penaltiesId,
    required this.stopCondsId,
    required this.optId,
    required this.entryPoolIds,
    required this.entrySelection,
    required this.exitPoolIds,
    required this.exitSelection
  });
}

class Experiment extends NodeObject {
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;
  String backtestSchemaId;
  String strategyId;

  @override
  String get nodeType => 'experiment';

  Experiment({
    required this.valSize,
    required this.testSize,
    required this.cvFolds,
    required this.foldSize,
    required this.backtestSchemaId,
    required this.strategyId
  });
}

class ExperimentGenerator extends NodeObject {
  String title;
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;
  String backtestSchemaId;
  String strategyId;

  @override
  String get nodeType => 'experiment_gen';

  ExperimentGenerator({
    required this.title,
    required this.valSize,
    required this.testSize,
    required this.cvFolds,
    required this.foldSize,
    required this.backtestSchemaId,
    required this.strategyId
  });
}
