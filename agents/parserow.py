import numpy as np

def parse_dist(row: dict, name: str, data: list):
    if len(data) == 0:
        default = dict.fromkeys([f"{name}_{stat}" for stat in ["count", "mean", "median", "std", "min", "max"]], 0.0)
        row.update(default)
        return
    
    row[f"{name}_count"] = len(data)
    row[f"{name}_mean"] = np.mean(data)
    row[f"{name}_median"] = np.median(data)
    row[f"{name}_std"] = np.std(data)
    row[f"{name}_min"] = min(data)
    row[f"{name}_max"] = max(data)

def parse_feats(row: dict, feats: list):

    feat_counts = dict.fromkeys(["constant_count", "raw_returns_count", "rolling_z_score_count", "normalized_sma_count", "normalized_ema_count", "normalized_kama_count", "rsi_count", "adx_count", "aroon_count", "normalized_ao_count", "normalized_dpo_count", "mass_index_count", "trix_count", "vortex_count", "williams_r_count", "stochastic_count", "normalized_macd_count", "normalized_atr_count", "normalized_bb_count", "normalized_dc_count", "normalized_kc_count"], 0)

    ohlc_counts = dict.fromkeys(["open_count", "high_count", "low_count", "close_count"], 0)
    out_counts = dict.fromkeys(["upper_count", "middle_count", "lower_count", "positive_count", "negative_count", "up_count", "down_count", "fast_k_count", "fast_d_count", "slow_d_count", "macd_count", "diff_count", "signal_count"], 0)

    row["wilder_true_count"] = 0
    row["wilder_false_count"] = 0
    
    row["simple_returns_count"] = 0
    row["log_returns_count"] = 0
    
    windows = []
    fast_windows = []
    slow_windows = []
    multipliers = []

    for feat in feats:
        feat_name = feat["feature"].replace(" ", "_")
        feat_counts[f"{feat_name}_count"] += 1

        if "wilder" in feat:
            wilder = feat["wilder"]

            row["wilder_true_count"] += wilder
            row["wilder_false_count"] += not wilder
        
        if "returns_type" in feat:
            row[f"{feat['returns_type']}_returns_count"] += 1
        
        if "ohlc" in feat:
            ohlc_counts[f"{feat['ohlc']}_count"] += 1

        if "out" in feat:
            out_counts[f"{feat['out']}_count"] += 1

        if "window" in feat:
            windows.append(feat["window"])

        if "signal_window" in feat:
            windows.append(feat["signal_window"])

        if "fast_window" in feat:
            fast_windows.append(feat["fast_window"])

        if "slow_window" in feat:
            slow_windows.append(feat["slow_window"])
        
        if "multiplier" in feat:
            multipliers.append(feat["multiplier"])

    row.update(feat_counts)
    row.update(ohlc_counts)
    row.update(out_counts)
    parse_dist(row, "window", windows)
    parse_dist(row, "fast_window", fast_windows)
    parse_dist(row, "slow_window", slow_windows)
    parse_dist(row, "multiplier", multipliers)

def parse_net(row: dict, net: dict):
    row["default_value"] = net["default_value"]

    net_type = net["type"]

    if net_type == "decision":
        row["max_trail_len"] = net["max_trail_len"]
    else:
        row["max_trail_len"] = 0

    net_type_dict = dict.fromkeys(["logic_net", "decision_net"], False)
    net_type_key = f"{net_type}_net"
    if net_type_key in net_type_dict:
        net_type_dict[net_type_key] = True
    row.update(net_type_dict)

    counts = dict.fromkeys(["set_feat_indices", "set_node_indices", "unset_feat_indices", "unset_node_indices", "recurrent_connections", "feedforward_connections", "type1_nodes", "type2_nodes", "AND_nodes", "OR_nodes", "XOR_nodes", "NAND_nodes", "NOR_nodes", "XNOR_nodes"], 0)

    for i, node in enumerate(net["nodes"]):
        node_type = node["type"]

        if node_type in ["input", "branch"]:
            counts["type1_nodes"] += 1

            feat_idx = node["feat_idx"]

            counts["set_feat_indices"] += feat_idx > 0
            counts["unset_feat_indices"] += feat_idx < 0

        elif node_type in ["logic", "ref"]:
            counts["type2_nodes"] += 1
        
        if node_type == "logic":

            counts[f"{node['gate']}_nodes"] += 1

            in1_idx = node["in1_idx"]
            in2_idx = node["in2_idx"]

            in1_set = in1_idx > 0
            in2_set = in2_idx > 0

            counts["set_node_indices"] += in1_set
            counts["set_node_indices"] += in2_set
            
            counts["unset_node_indices"] += not in1_set
            counts["unset_node_indices"] += not in2_set
            
            counts["recurrent_connections"] += in1_idx >= i + 1
            counts["recurrent_connections"] += in2_idx >= i + 1

            in1_feedforward = in1_idx < i + 1
            in2_feedforward = in2_idx < i + 1

            counts["feedforward_connections"] += in1_set and in1_feedforward
            counts["feedforward_connections"] += in2_set and in2_feedforward
        
        elif node_type in ["branch", "ref"]:
            
            true_idx = node["true_idx"]
            false_idx = node["false_idx"]

            counts["set_node_indices"] += true_idx > 0
            counts["set_node_indices"] += false_idx > 0

            counts["unset_node_indices"] += true_idx < 0
            counts["unset_node_indices"] += false_idx < 0

            if node_type == "ref":
                ref_idx = node["ref_idx"]

                counts["set_node_indices"] += ref_idx > 0
                counts["unset_node_indices"] += ref_idx < 0

    row.update(counts)

def parse_penalties(row: dict, penalties: dict):
    penalties_dict = dict.fromkeys(["logic_penalties", "decision_penalties", "node", "used_feat", "unused_feat", "input", "logic", "recurrence", "feedforward", "branch", "ref", "leaf", "non_leaf"], 0.0)

    penalties_type_key = f"{penalties['type']}_penalties"
    if penalties_type_key in penalties_dict:
        penalties_dict[penalties_type_key] = True

    for key, value in penalties.items():
        if key in penalties_dict:
            penalties_dict[key] = value

    row.update(penalties_dict)

def parse_meta_actions(row: dict, meta_actions: list):
    row["n_meta_actions"] = len(meta_actions)

    action_counts = dict.fromkeys(["NEXT_FEATURE_count", "NEXT_THRESHOLD_count", "NEXT_NODE_count", "SELECT_NODE_count", "SET_IN1_IDX_count", "SET_IN2_IDX_count", "SET_TRUE_IDX_count", "SET_FALSE_IDX_count", "SET_REF_IDX_count", "NEW_INPUT_NODE_count", "NEW_AND_NODE_count", "NEW_OR_NODE_count", "NEW_XOR_NODE_count", "NEW_NAND_NODE_count", "NEW_NOR_NODE_count", "NEW_XNOR_NODE_count", "NEW_BRANCH_NODE_count", "NEW_REF_NODE_count"], 0)

    lengths = []

    for meta_action in meta_actions:
        sub_actions = meta_action["sub_actions"]

        sub_actions_len = len(sub_actions)
        lengths.append(sub_actions_len)

        for sub_action in sub_actions:
            action_counts[f"{sub_action}_count"] += 1

    parse_dist(row, "meta_action_length", lengths)
    row.update(action_counts)

def parse_actions(row: dict, actions: dict):
    actions_dict = dict.fromkeys(["logic_actions", "decision_actions", "allow_recurrence", "allow_and", "allow_or", "allow_xor", "allow_nand", "allow_nor", "allow_xnor", "allow_refs", "allow_cycles"], False)

    actions_type_key = f"{actions['type']}_actions"
    if actions_type_key in actions_dict:
        actions_dict[actions_type_key] = True

    for key, value in actions.items():
        if key in actions_dict:
            actions_dict[key] = value

    row.update(actions_dict)

    row["n_thresholds"] = actions["n_thresholds"]
    parse_meta_actions(row, actions["meta_actions"])

def parse_stop_conds(row: dict, stop_conds: dict):
    row["max_iters"] = stop_conds["max_iters"]
    row["train_patience"] = stop_conds["train_patience"]
    row["val_patience"] = stop_conds["val_patience"]

def parse_opt(row: dict, opt: dict):
    opt_dict = dict.fromkeys(["genetic_opt", "pop_size", "seq_len", "n_elites", "mut_rate", "cross_rate", "tournament_size"], 0.0)
    
    opt_type_key = f"{opt['type']}_opt"
    if opt_type_key in opt_dict:
        opt_dict[opt_type_key] = True
    
    for key, value in opt.items():
        if key in opt_dict:
            opt_dict[key] = value
    
    row.update(opt_dict)

def parse_node_ptr(row: dict, name: str, node_ptr: dict):
    row[f"{name}_from_start"] = node_ptr["anchor"] == "from_start"
    row[f"{name}_idx"] = node_ptr["idx"]

def parse_strategy(row: dict, strategy: dict):
    parse_net(row, strategy["base_net"])
    parse_feats(row, strategy["feats"])
    parse_actions(row, strategy["actions"])
    parse_penalties(row, strategy["penalties"])
    parse_stop_conds(row, strategy["stop_conds"])
    parse_opt(row, strategy["opt"])

    parse_node_ptr(row, "entry", strategy["entry_ptr"])
    parse_node_ptr(row, "exit", strategy["exit_ptr"])

    row["stop_loss"] = strategy["stop_loss"]
    row["take_profit"] = strategy["take_profit"]
    row["max_hold_time"] = strategy["max_hold_time"]

def parse_backtest_schema(row: dict, schema: dict):
    row["start_offset"] = schema["start_offset"]
    row["start_balance"] = schema["start_balance"]
    row["alloc_size"] = schema["alloc_size"]
    row["delay"] = schema["delay"]

def parse_experiment(row: dict, experiment: dict):
    row["val_size"] = experiment["val_size"]
    row["test_size"] = experiment["test_size"]
    row["cv_folds"] = experiment["cv_folds"]
    row["fold_size"] = experiment["fold_size"]

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

        counts.append(imps_len)
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
    iters_list = [fold["opt_results"]["iters"] for fold in folds]
    train_imps = [fold["opt_results"]["train_improvements"] for fold in folds]
    val_imps = [fold["opt_results"]["val_improvements"] for fold in folds]

    parse_dist(row, "opt_iters", iters_list)
    parse_imps(row, "opt_train", train_imps, iters_list)
    parse_imps(row, "opt_val", val_imps, iters_list)

def parse_backtest_results(row: dict, folds: list):
    metrics = ["excess_sharpe", "mean_holding_time", "std_holding_time", "total_exits", "signal_exits", "stop_loss_exits", "take_profit_exits", "max_holding_time_exits"]
    metric_lists = {f"{split}_{metric}": [] for split in ["train", "val", "test"] for metric in metrics}

    train_invalid = 0
    val_invalid = 0
    test_invalid = 0

    for fold in folds:
        train_results = fold["train_results"]
        val_results = fold["val_results"]
        test_results = fold["test_results"]
        
        train_invalid += train_results["is_invalid"]
        val_invalid += val_results["is_invalid"]
        test_invalid += test_results["is_invalid"]

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
    
