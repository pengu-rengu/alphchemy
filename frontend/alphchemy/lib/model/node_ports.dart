import 'dart:ui';

import 'package:vyuh_node_flow/vyuh_node_flow.dart';

List<Port> portsForNodeType(String nodeType) {
  switch (nodeType) {
    case 'experiment_gen':
      return _outputPorts(['backtest_schema', 'strategy']);
    case 'experiment':
      return _outputPorts(['backtest_schema', 'strategy']);
    case 'strategy_gen':
      return [
        ..._inputPort(8),
        ..._outputPorts([
          'base_net',
          'feat_pool',
          'actions',
          'penalties',
          'stop_conds',
          'opt',
          'entry_pool',
          'exit_pool'
        ])
      ];
    case 'strategy':
      return [
        ..._inputPort(8),
        ..._outputPorts([
          'base_net',
          'feats',
          'actions',
          'penalties',
          'stop_conds',
          'opt',
          'entry_schemas',
          'exit_schemas'
        ])
      ];
    case 'network_gen':
      return [
        ..._inputPort(2),
        ..._outputPorts(['logic_net', 'decision_net'])
      ];
    case 'actions_gen':
      return [
        ..._inputPort(2),
        ..._outputPorts(['logic_actions', 'decision_actions'])
      ];
    case 'penalties_gen':
      return [
        ..._inputPort(2),
        ..._outputPorts(['logic_penalties', 'decision_penalties'])
      ];
    case 'logic_net':
      return [
        ..._inputPort(1),
        ..._outputPorts(['nodes'])
      ];
    case 'decision_net':
      return [
        ..._inputPort(1),
        ..._outputPorts(['nodes'])
      ];
    case 'logic_actions':
      return [
        ..._inputPort(2),
        ..._outputPorts(['meta_actions', 'thresholds'])
      ];
    case 'decision_actions':
      return [
        ..._inputPort(2),
        ..._outputPorts(['meta_actions', 'thresholds'])
      ];
    case 'entry_schema':
      return [
        ..._inputPort(1),
        ..._outputPorts(['node_ptr'])
      ];
    case 'exit_schema':
      return [
        ..._inputPort(1),
        ..._outputPorts(['node_ptr'])
      ];
    default:
      return _inputPort(0);
  }
}

double nodeHeight(int outputCount) {
  if (outputCount <= 0) return 100.0;
  final lastPort = 30.0 + (outputCount - 1) * 25.0;
  return lastPort + 30.0;
}

List<Port> _inputPort(int outputCount) {
  final height = nodeHeight(outputCount);
  return [
    Port(
      id: 'in',
      name: 'In',
      position: PortPosition.left,
      type: PortType.input,
      multiConnections: true,
      offset: Offset(0, height / 2)
    )
  ];
}

List<Port> _outputPorts(List<String> names) {
  final ports = <Port>[];
  for (var i = 0; i < names.length; i++) {
    final portName = names[i];
    final port = Port(
      id: 'out_$portName',
      name: portName,
      position: PortPosition.right,
      type: PortType.output,
      showLabel: true,
      multiConnections: true,
      offset: Offset(0, 30.0 + i * 25.0)
    );
    ports.add(port);
  }
  return ports;
}
