import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("copy preserves node ids through json", () {
    final root = Experiment();
    final strategy = Strategy();
    final feat = Constant(id: "bias", constant: 1.0);

    root.addChild("strategy", strategy);
    strategy.addChild("feats", feat);

    final copied = root.copy() as Experiment;
    final copiedStrategy = copied.strategy!;
    final copiedFeat = copiedStrategy.feats.first;

    expect(copied.nodeId, root.nodeId);
    expect(copiedStrategy.nodeId, strategy.nodeId);
    expect(copiedFeat.nodeId, feat.nodeId);
  });

  test("fromJson generates node id when missing", () {
    final node = Constant.fromJson({
      "feature": "constant",
      "id": "bias",
      "constant": 1.0
    });

    expect(node.nodeId, isNotEmpty);
  });

  test("all node types preserve node id on copy", () {
    for (final nodeType in NodeType.values) {
      final node = nodeType.emptyNode();
      final copied = node.copy();

      expect(copied.nodeId, node.nodeId);
    }
  });

  test("field merge preserves current children", () {
    final current = Strategy();
    final currentFeat = Constant(id: "bias", constant: 2.0);
    current.addChild("feats", currentFeat);

    final source = Strategy();
    final staleFeat = Constant(id: "bias", constant: 1.0);
    source.nodeId = current.nodeId;
    source.addChild("feats", staleFeat);
    source.updateField("global_max_positions", "3");

    current.updateFieldsFrom(source);
    final mergedFeat = current.feats.first as Constant;

    expect(current.globalMaxPositions, 3);
    expect(mergedFeat.constant, 2.0);
  });
}
