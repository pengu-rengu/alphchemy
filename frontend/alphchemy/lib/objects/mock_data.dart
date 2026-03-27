final Map<String, dynamic> mockWrapperJson = {
  "generator": {
    "title": "Experiment",
    "val_size": 0.2,
    "test_size": 0.1,
    "cv_folds": 3,
    "fold_size": 0.3
  },
  "param_space": {
    "search_space": {
      "mut_rate": [0.02, 0.05, 0.1],
      "pop_size": [50, 150, 300],
      "default_value": [true, false]
    }
  }
};
