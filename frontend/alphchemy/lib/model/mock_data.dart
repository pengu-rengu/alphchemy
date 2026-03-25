final Map<String, dynamic> mockExperimentGenJson = {
  'title': 'Mock Experiment',
  'val_size': 0.2,
  'test_size': 0.1,
  'cv_folds': 3,
  'fold_size': 0.3,
  'backtest_schema': {
    'start_offset': 100,
    'start_balance': 10000.0,
    'delay': 1
  },
  'strategy': {
    'base_net': {
      'type': 'logic_net',
      'logic_net': {
        'nodes': [
          {'type': 'input', 'threshold': 0.5, 'feat_idx': 0},
          {'type': 'input', 'threshold': 0.3, 'feat_idx': 1},
          {'type': 'gate', 'gate': 'and', 'in1_idx': 0, 'in2_idx': 1}
        ],
        'default_value': false
      },
      'decision_net': null
    },
    'feat_pool': [
      {
        'feature': 'raw_returns',
        'id': 'feat_0',
        'returns_type': 'log',
        'ohlc': 'close'
      },
      {
        'feature': 'raw_returns',
        'id': 'feat_1',
        'returns_type': 'simple',
        'ohlc': 'open'
      },
      {
        'feature': 'constant',
        'id': 'feat_2',
        'constant': 1.0
      }
    ],
    'feat_selection': [0, 1],
    'actions': {
      'type': 'logic_actions',
      'logic_actions': {
        'meta_actions': [
          {'label': 'buy', 'sub_actions': ['market_buy']},
          {'label': 'sell', 'sub_actions': ['market_sell']}
        ],
        'thresholds': [
          {'feat_id': 'feat_0', 'min': -1.0, 'max': 1.0}
        ],
        'n_thresholds': 5,
        'allow_recurrence': true,
        'allowed_gates': ['and', 'or']
      },
      'decision_actions': null
    },
    'penalties': {
      'type': 'logic_penalties',
      'logic_penalties': {
        'node': 0.1,
        'input': 0.2,
        'gate': 0.1,
        'recurrence': 0.5,
        'feedforward': 0.3,
        'used_feat': 0.0,
        'unused_feat': 0.4
      },
      'decision_penalties': null
    },
    'stop_conds': {
      'max_iters': 100,
      'train_patience': 10,
      'val_patience': 5
    },
    'opt': {
      'pop_size': 50,
      'seq_len': 10,
      'n_elites': 5,
      'mut_rate': 0.1,
      'cross_rate': 0.7,
      'tournament_size': 3
    },
    'entry_pool': [
      {
        'node_ptr': {'anchor': 'from_end', 'idx': 0},
        'position_size': 0.1,
        'max_positions': 3
      }
    ],
    'entry_selection': [0],
    'exit_pool': [
      {
        'node_ptr': {'anchor': 'from_end', 'idx': 0},
        'entry_indices': [0],
        'stop_loss': 0.05,
        'take_profit': 0.1,
        'max_hold_time': 100
      }
    ],
    'exit_selection': [0]
  }
};
