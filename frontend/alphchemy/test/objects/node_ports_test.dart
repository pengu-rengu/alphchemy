import "package:alphchemy/model/generator/experiment.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/node_ports.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("output ports use bare ids for connections", () {
    final portIds = ExperimentGenerator.ports().map((port) => port.id).toList();

    expect(portIds, ["backtest_schema", "strategy"]);
    expect(
      canConnect(NodeType.experimentGen, "strategy", NodeType.strategyGen),
      isTrue,
    );
    expect(
      canConnect(NodeType.experimentGen, "out_strategy", NodeType.strategyGen),
      isFalse,
    );
  });
}
