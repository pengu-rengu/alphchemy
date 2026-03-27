import numpy as np

def parse_dist(row: dict, name: str, data: list):
    if len(data) == 0:
        default = dict.fromkeys([f"{name}_{stat}" for stat in ["count", "mean", "median", "std", "min", "max"]], 0.0)
        row.update(default)
        return
    
    row[f"{name}_count"] = float(len(data))
    row[f"{name}_mean"] = float(np.mean(data))
    row[f"{name}_median"] = float(np.median(data))
    row[f"{name}_std"] = float(np.std(data))
    row[f"{name}_min"] = float(min(data))
    row[f"{name}_max"] = float(max(data))

def parse_feats(row: dict, feats: list):

    feat_counts = dict.fromkeys(["constant_count", "raw_returns_count"], 0.0)

    ohlc_counts = dict.fromkeys(["open_count", "high_count", "low_count", "close_count"], 0.0)

    row["simple_returns_count"] = 0.0
    row["log_returns_count"] = 0.0

    for feat in feats:
        feat_name = feat["feature"]
        feat_counts[f"{feat_name}_count"] += 1.0

        if "returns_type" in feat:
            row[f"{feat['returns_type']}_returns_count"] += 1.0

        if "ohlc" in feat:
            ohlc_counts[f"{feat['ohlc']}_count"] += 1.0

    row.update(feat_counts)
    row.update(ohlc_counts)

def parse_net(row: dict, net: dict):
    row["default_value"] = 1.0 if net["default_value"] else 0.0

    net_type = net["type"]

    if net_type == "decision":
        row["max_trail_len"] = float(net["max_trail_len"])
    else:
        row["max_trail_len"] = 0.0

    net_type_dict = dict.fromkeys(["logic_net", "decision_net"], 0.0)
    net_type_key = f"{net_type}_net"
    if net_type_key in net_type_dict:
        net_type_dict[net_type_key] = 1.0
    row.update(net_type_dict)

    counts = dict.fromkeys(["set_feat_indices", "set_node_indices", "unset_feat_indices", "unset_node_indices", "recurrent_connections", "feedforward_connections", "type1_nodes", "type2_nodes", "and_nodes", "or_nodes", "xor_nodes", "nand_nodes", "nor_nodes", "xnor_nodes"], 0.0)

    for i, node in enumerate(net["nodes"]):
        node_type = node["type"]

        if node_type in ["input", "branch"]:
            counts["type1_nodes"] += 1.0

            feat_idx = node["feat_idx"]

            counts["set_feat_indices"] += 1.0 if feat_idx is not None else 0.0
            counts["unset_feat_indices"] += 1.0 if feat_idx is None else 0.0

        elif node_type in ["gate", "ref"]:
            counts["type2_nodes"] += 1.0

        if node_type == "gate":
            gate_type = node["gate"]

            if gate_type is not None:
                counts[f"{gate_type}_nodes"] += 1.0

                in1_idx = node["in1_idx"]
                in2_idx = node["in2_idx"]

                in1_set = in1_idx is not None
                in2_set = in2_idx is not None

                counts["set_node_indices"] += 1.0 if in1_set else 0.0
                counts["set_node_indices"] += 1.0 if in2_set else 0.0

                counts["unset_node_indices"] += 1.0 if not in1_set else 0.0
                counts["unset_node_indices"] += 1.0 if not in2_set else 0.0

                counts["recurrent_connections"] += 1.0 if in1_set and in1_idx >= i else 0.0
                counts["recurrent_connections"] += 1.0 if in2_set and in2_idx >= i else 0.0

                counts["feedforward_connections"] += 1.0 if in1_set and in1_idx < i else 0.0
                counts["feedforward_connections"] += 1.0 if in2_set and in2_idx < i else 0.0
        
        elif node_type in ["branch", "ref"]:
            
            true_idx = node["true_idx"]
            false_idx = node["false_idx"]

            counts["set_node_indices"] += 1.0 if true_idx is not None else 0.0
            counts["set_node_indices"] += 1.0 if false_idx is not None else 0.0

            counts["unset_node_indices"] += 1.0 if true_idx is None else 0.0
            counts["unset_node_indices"] += 1.0 if false_idx is None else 0.0

            if node_type == "ref":
                ref_idx = node["ref_idx"]

                counts["set_node_indices"] += 1.0 if ref_idx is not None else 0.0
                counts["unset_node_indices"] += 1.0 if ref_idx is None else 0.0

    row.update(counts)

def parse_penalties(row: dict, penalties: dict):
    penalties_dict = dict.fromkeys(["logic_penalties", "decision_penalties", "node", "used_feat", "unused_feat", "input", "gate", "recurrence", "feedforward", "branch", "ref", "leaf", "non_leaf"], 0.0)

    penalties_type_key = f"{penalties['type']}_penalties"
    if penalties_type_key in penalties_dict:
        penalties_dict[penalties_type_key] = 1.0

    for key, value in penalties.items():
        if key in penalties_dict:
            penalties_dict[key] = float(value)

    row.update(penalties_dict)

def parse_meta_actions(row: dict, meta_actions: list):
    row["n_meta_actions"] = float(len(meta_actions))

    action_counts = dict.fromkeys(["next_feat_count", "next_threshold_count", "next_node_count", "select_node_count", "next_gate_count", "set_feat_idx_count", "set_threshold_count", "set_gate_count", "set_in1_idx_count", "set_in2_idx_count", "set_true_idx_count", "set_false_idx_count", "set_ref_idx_count", "new_input_count", "new_gate_count", "new_branch_count", "new_ref_count"], 0.0)

    lengths = []

    for meta_action in meta_actions:
        sub_actions = meta_action["sub_actions"]

        sub_actions_len = len(sub_actions)
        lengths.append(sub_actions_len)

        for sub_action in sub_actions:
            action_counts[f"{sub_action}_count"] += 1.0

    parse_dist(row, "meta_action_length", lengths)
    row.update(action_counts)

def parse_actions(row: dict, actions: dict):
    actions_dict = dict.fromkeys(["logic_actions", "decision_actions", "allow_recurrence", "allow_and", "allow_or", "allow_xor", "allow_nand", "allow_nor", "allow_xnor", "allow_refs"], 0.0)

    actions_type_key = f"{actions['type']}_actions"
    if actions_type_key in actions_dict:
        actions_dict[actions_type_key] = 1.0

    if "allow_recurrence" in actions:
        actions_dict["allow_recurrence"] = 1.0 if actions["allow_recurrence"] else 0.0

    if "allow_refs" in actions:
        actions_dict["allow_refs"] = 1.0 if actions["allow_refs"] else 0.0

    if "allowed_gates" in actions:
        for gate in actions["allowed_gates"]:
            actions_dict[f"allow_{gate}"] = 1.0

    row.update(actions_dict)

    row["n_thresholds"] = float(actions["n_thresholds"])
    parse_meta_actions(row, actions["meta_actions"])

def parse_stop_conds(row: dict, stop_conds: dict):
    row["max_iters"] = float(stop_conds["max_iters"])
    row["train_patience"] = float(stop_conds["train_patience"])
    row["val_patience"] = float(stop_conds["val_patience"])

def parse_opt(row: dict, opt: dict):
    opt_dict = dict.fromkeys(["genetic_opt", "pop_size", "seq_len", "n_elites", "mut_rate", "cross_rate", "tournament_size"], 0.0)
    
    opt_type_key = f"{opt['type']}_opt"
    if opt_type_key in opt_dict:
        opt_dict[opt_type_key] = 1.0
    
    for key, value in opt.items():
        if key in opt_dict:
            opt_dict[key] = float(value)
    
    row.update(opt_dict)

def parse_node_ptr(row: dict, name: str, node_ptr: dict):
    row[f"{name}_from_start"] = 1.0 if node_ptr["anchor"] == "from_start" else 0.0
    row[f"{name}_idx"] = float(node_ptr["idx"])

def parse_strategy(row: dict, strategy: dict):
    parse_net(row, strategy["base_net"])
    parse_feats(row, strategy["feats"])
    parse_actions(row, strategy["actions"])
    parse_penalties(row, strategy["penalties"])
    parse_stop_conds(row, strategy["stop_conds"])
    parse_opt(row, strategy["opt"])

    entry_schemas = strategy["entry_schemas"]
    exit_schemas = strategy["exit_schemas"]

    row["n_entry_schemas"] = float(len(entry_schemas))
    row["n_exit_schemas"] = float(len(exit_schemas))

    position_sizes = []
    max_positions_list = []
    for schema in entry_schemas:
        parse_node_ptr(row, f"entry_{len(position_sizes)}", schema["node_ptr"])
        position_sizes.append(schema["position_size"])
        max_positions_list.append(schema["max_positions"])

    parse_dist(row, "position_size", position_sizes)
    parse_dist(row, "max_positions", max_positions_list)

    stop_losses = []
    take_profits = []
    max_hold_times = []
    entry_indices_counts = []
    for i, schema in enumerate(exit_schemas):
        parse_node_ptr(row, f"exit_{i}", schema["node_ptr"])
        stop_losses.append(schema["stop_loss"])
        take_profits.append(schema["take_profit"])
        max_hold_times.append(schema["max_hold_time"])
        entry_indices_counts.append(float(len(schema["entry_indices"])))

    parse_dist(row, "stop_loss", stop_losses)
    parse_dist(row, "take_profit", take_profits)
    parse_dist(row, "max_hold_time", max_hold_times)
    parse_dist(row, "entry_indices_count", entry_indices_counts)

def parse_backtest_schema(row: dict, schema: dict):
    row["start_offset"] = float(schema["start_offset"])
    row["start_balance"] = float(schema["start_balance"])
    row["delay"] = float(schema["delay"])

def parse_experiment(row: dict, experiment: dict):
    row["val_size"] = float(experiment["val_size"])
    row["test_size"] = float(experiment["test_size"])
    row["cv_folds"] = float(experiment["cv_folds"])
    row["fold_size"] = float(experiment["fold_size"])

    parse_backtest_schema(row, experiment["backtest_schema"])
    parse_strategy(row, experiment["strategy"])

def calculate_gain(imps: list, iters: int, fraction: float) -> float:
    if len(imps) < 2:
        return 0.0
    
    start_score = imps[0]["score"]
    
    cutoff = iters * fraction
    early_score = start_score
    
    for imp in imps:
        if imp["iter"] > cutoff:
            break

        early_score = imp["score"]
            
    return early_score - start_score

def parse_imps(row: dict, prefix: str, folds_imps: list, folds_iters: list):
    counts = []
    gains_total = []
    gains_25 = []
    gains_50 = []
    gains_75 = []

    for imps, iters in zip(folds_imps, folds_iters):
        imps_len = len(imps)
        total_gain = imps[-1]["score"] - imps[0]["score"]
        gain_25 = calculate_gain(imps, iters, 0.25)
        gain_50 = calculate_gain(imps, iters, 0.50)
        gain_75 = calculate_gain(imps, iters, 0.75)

        counts.append(float(imps_len))
        gains_total.append(total_gain)
        gains_25.append(gain_25)
        gains_50.append(gain_50)
        gains_75.append(gain_75)

    parse_dist(row, f"{prefix}_imp_count", counts)
    parse_dist(row, f"{prefix}_gain_total", gains_total)
    parse_dist(row, f"{prefix}_gain_25", gains_25)
    parse_dist(row, f"{prefix}_gain_50", gains_50)
    parse_dist(row, f"{prefix}_gain_75", gains_75)

def parse_opt_results(row: dict, folds: list):
    iters_list = [float(fold["opt_results"]["iters"]) for fold in folds]
    train_imps = [fold["opt_results"]["train_improvements"] for fold in folds]
    val_imps = [fold["opt_results"]["val_improvements"] for fold in folds]

    parse_dist(row, "opt_iters", iters_list)
    parse_imps(row, "opt_train", train_imps, iters_list)
    parse_imps(row, "opt_val", val_imps, iters_list)

def parse_backtest_results(row: dict, folds: list):
    metrics = ["excess_sharpe", "mean_hold_time", "std_hold_time", "entries", "total_exits", "signal_exits", "stop_loss_exits", "take_profit_exits", "max_hold_exits"]
    metric_lists = {f"{split}_{metric}": [] for split in ["train", "val", "test"] for metric in metrics}

    train_invalid = 0.0
    val_invalid = 0.0
    test_invalid = 0.0

    for fold in folds:
        train_results = fold["train_results"]
        val_results = fold["val_results"]
        test_results = fold["test_results"]
        
        train_invalid += 1.0 if train_results["is_invalid"] else 0.0
        val_invalid += 1.0 if val_results["is_invalid"] else 0.0
        test_invalid += 1.0 if test_results["is_invalid"] else 0.0

        for metric in metrics:
            metric_lists[f"train_{metric}"].append(train_results[metric])
            metric_lists[f"val_{metric}"].append(val_results[metric])
            metric_lists[f"test_{metric}"].append(test_results[metric])

    n_folds = len(folds)
    row["train_invalid_frac"] = train_invalid / n_folds
    row["val_invalid_frac"] = val_invalid / n_folds
    row["test_invalid_frac"] = test_invalid / n_folds

    for key, data in metric_lists.items():
        parse_dist(row, key, data)

def parse_results(row: dict, results: dict):
    
    parse_opt_results(row, results["fold_results"])
    parse_backtest_results(row, results["fold_results"])
    
