module ParseJsonModule

using ..FeaturesModule

using ..NetworkModule
using ..LogicNetModule
using ..DecisionNetModule

using ..ActionsModule
using ..LogicActionsModule
using ..DecisionActionsModule

using ..OptimizerModule
using ..GeneticModule

using ..StrategyModule
using ..BacktestModule
using ..ExperimentModule

function parse_feature(json::AbstractDict)::AbstractFeature
    feature = json["feature"]
    id = json["id"]

    if haskey(json, "ohlc")
        ohlc = Symbol(json["ohlc"])
    end

    if haskey(json, "window")
        window = json["window"]
    end

    if haskey(json, "fast_window")
        fast_window = json["fast_window"]
    end

    if haskey(json, "slow_window")
        slow_window = json["slow_window"]
    end

    if haskey(json, "wilder")
        wilder = json["wilder"]
    end

    if haskey(json, "multiplier")
        multiplier = json["multiplier"]
    end

    if haskey(json, "out")
        out = Symbol(json["out"])
    end

    if feature == "constant"
        return Constant(
            id = id,
            constant = json["constant"]
        )
    elseif feature == "raw returns"
        returns_type = Symbol(json["returns_type"])

        return RawReturns(
            id = id,
            returns_type = returns_type,
            ohlc = ohlc
        )
    elseif feature == "rolling z score"
        return RollingZScore(
            id = id,
            window = window,
            ohlc = ohlc
        )
    elseif feature == "normalized sma"
        return NormalizedSMA(
            id = id,
            window = window,
            ohlc = ohlc
        )
    elseif feature == "normalized ema"
        return NormalizedEMA(
            id = id,
            window = window,
            wilder = wilder,
            ohlc = ohlc
        )
    elseif feature == "normalized kama"
        return NormalizedKAMA(
            id = id,
            window = window,
            fast_window = fast_window,
            slow_window = slow_window,
            ohlc = ohlc
        )
    elseif feature == "rsi"
        return RSI(
            id = id,
            window = window,
            wilder = wilder,
            ohlc = ohlc
        )
    elseif feature == "adx"
        return ADX(
            id = id,
            window = window,
            direction = out
        )
    elseif feature == "aroon"
        return Aroon(
            id = id,
            window = window,
            direction = out
        )
    elseif feature == "normalized ao"
        return NormalizedAO(id = id)
    elseif feature == "normalized dpo"
        return NormalizedDPO(
            id = id,
            window = window,
            ohlc = ohlc
        )
    elseif feature == "mass index"
        return MassIndex(
            id = id,
            window = window
        )
    elseif feature == "trix"
        return TRIX(
            id = id,
            window = window,
            ohlc = ohlc
        )
    elseif feature == "vortex"
        return Vortex(
            id = id,
            window = window,
            direction = out
        )
    elseif feature == "williams r"
        return WilliamsR(
            id = id,
            window = window
        )
    elseif feature == "stochastic"
        return Stochastic(
            id = id,
            window = window,
            fast_window = fast_window,
            slow_window = slow_window,
            output = out
        )
    elseif feature == "normalized macd"
        return NormalizedMACD(
            id = id,
            fast_window = fast_window,
            slow_window = slow_window,
            signal_window = json["signal_window"],
            ohlc = ohlc,
            output = out
        )
    elseif feature == "normalized atr"
        return NormalizedATR(
            id = id,
            window = window
        )
    elseif feature == "normalized bb"
        return NormalizedBB(
            id = id,
            window = window,
            std_multiplier = multiplier,
            ohlc = ohlc,
            band = out
        )
    elseif feature == "normalized dc"
        return NormalizedDC(
            id = id,
            window = window,
            channel = out
        )
    elseif feature == "normalized kc"
        return NormalizedKC(
            id = id,
            window = window,
            multiplier = multiplier,
            channel = out
        )
    end

    error("invalid feature $feature")
end
export parse_feature

function parse_node_ptr(json::AbstractDict)::NodePtr
    anchor = Symbol(json["anchor"])

    return NodePtr(
        anchor = anchor,
        idx = json["idx"]
    )
end
export parse_node_ptr

function parse_logic_node(json::AbstractDict)::Union{InputNode, LogicNode}
    type = json["type"]

    if type == "input"
        return InputNode(
            threshold = json["threshold"],
            feature_idx = json["feat_idx"]
        )
    elseif type == "logic"
        gate = Symbol(json["gate"])

        return LogicNode(
            gate = gate,
            in1_idx = json["in1_idx"],
            in2_idx = json["in2_idx"]
        )
    end

    error("invalid node type: $type")
end
export parse_logic_node

function parse_decision_node(json::AbstractDict)::Union{BranchNode, RefNode}
    type = json["type"]

    true_idx = json["true_idx"]
    false_idx = json["false_idx"]

    if type == "branch"
        return BranchNode(
            threshold = json["threshold"],
            feature_idx = json["feat_idx"],
            true_idx = true_idx,
            false_idx = false_idx
        )
    elseif type == "ref"
        return RefNode(
            ref_idx = json["ref_idx"],
            true_idx = true_idx,
            false_idx = false_idx
        )
    end

    error("invalid node type: $type")
end
export parse_decision_node

function parse_net(json::AbstractDict)::AbstractNetwork
    type = json["type"]

    nodes_json = json["nodes"]
    default_value = json["default_value"]

    if type == "logic"
        return LogicNet(
            nodes = [parse_logic_node(node_json) for node_json ∈ nodes_json],
            default_value = default_value
        )
    elseif type == "decision"
        return DecisionNet(
            nodes = [parse_decision_node(node_json) for node_json ∈ nodes_json],
            max_trail_len = json["max_trail_len"],
            default_value = default_value
        )
    end

    error("invalid network type: $type")
end
export parse_net

function parse_penalties(json::AbstractDict)::AbstractPenalties
    type = json["type"]
    node_penalty = json["node"]
    used_penalty = json["used_feat"]
    unused_penalty = json["unused_feat"]

    if type == "logic"
        return LogicPenalties(
            node = node_penalty,
            input = json["input"],
            logic = json["logic"],
            recurrence = json["recurrence"],
            feedforward = json["feedforward"],
            used_feature = used_penalty,
            unused_feature = unused_penalty
        )
    elseif type == "decision"
        return DecisionPenalties(
            node = node_penalty,
            branch = json["branch"],
            ref = json["ref"],
            leaf = json["leaf"],
            non_leaf = json["non_leaf"],
            used_feature = used_penalty,
            unused_feature = unused_penalty
        )
    end

    error("invalid penalties type: $type")
end

function parse_thresholds(json::AbstractVector, feats::Vector{<:AbstractFeature})::Tuple{Vector{Float64}, Vector{Float64}}

    n_features = length(feats)
    thresholds_len = length(json)

    @assert thresholds_len == n_features "length of thresholds must be == # of features"

    min_thresholds = Vector{Float64}(undef, thresholds_len)
    max_thresholds = Vector{Float64}(undef, thresholds_len)
    
    for threshold_json ∈ json
        idx = findfirst(feat -> feat.id == threshold_json["feat_id"], feats)
        min_thresholds[idx] = threshold_json["min"]
        max_thresholds[idx] = threshold_json["max"]
    end

    return min_thresholds, max_thresholds
end
export parse_thresholds

function parse_meta_actions(json::AbstractVector)::Dict{Symbol, Vector{Symbol}}
    meta_actions = Dict{Symbol, Vector{Symbol}}()

    for meta_json ∈ json
        label = Symbol(meta_json["label"])
        sub_actions = [Symbol(sub_action) for sub_action ∈ meta_json["sub_actions"]]

        meta_actions[label] = sub_actions
    end

    return meta_actions
end
export parse_meta_actions

function parse_actions(json::AbstractDict, features::Vector{<:AbstractFeature})::AbstractActions
    type = json["type"]

    meta_actions = parse_meta_actions(json["meta_actions"])
    min_thresholds, max_thresholds = parse_thresholds(json["thresholds"], features)
    n_thresholds = json["n_thresholds"]
    
    if type == "logic"
        return LogicActions(
            meta_actions = meta_actions,
            min_thresholds = min_thresholds,
            max_thresholds = max_thresholds,
            n_thresholds = n_thresholds,
            allow_recurrence = json["allow_recurrence"],
            allow_and = json["allow_and"],
            allow_or = json["allow_or"],
            allow_nand = json["allow_nand"],
            allow_nor = json["allow_nor"],
            allow_xor = json["allow_xor"],
            allow_xnor = json["allow_xnor"]
        )
    elseif type == "decision"
        return DecisionActions(
            meta_actions = meta_actions,
            min_thresholds = min_thresholds,
            max_thresholds = max_thresholds,
            n_thresholds = n_thresholds,
            allow_refs = json["allow_refs"],
            allow_cycles = json["allow_cycles"]
        )
    end

    error("invalid actions type: $type")
end
export parse_actions

function parse_stop_conditions(json::AbstractDict)::StopConds
    return StopConds(
        max_iters = json["max_iters"],
        train_patience = json["train_patience"],
        val_patience = json["val_patience"]
    )
end
export parse_stop_conditions

function parse_opt(json::AbstractDict)::AbstractOpt
    type = json["type"]

    if type == "genetic"
        return GeneticOpt(
            pop_size = json["pop_size"],
            seq_len = json["seq_len"],
            n_elites = json["n_elites"],
            mutation_rate = json["mut_rate"],
            crossover_rate = json["cross_rate"],
            tournament_size = json["tournament_size"]
        )
    end

    error("invalid optimizer type: $type")
end
export parse_opt

function parse_strategy(json::AbstractDict)::Strategy
    features = [parse_feature(feat_json) for feat_json ∈ json["feats"]]
    
    return Strategy(
        base_net = parse_net(json["base_net"]),
        features = features,
        actions = parse_actions(json["actions"], features),
        penalties = parse_penalties(json["penalties"]),
        stop_conds = parse_stop_conditions(json["stop_conds"]),
        optimizer = parse_opt(json["opt"]),
        entry_ptr = parse_node_ptr(json["entry_ptr"]),
        exit_ptr = parse_node_ptr(json["exit_ptr"]),
        stop_loss = json["stop_loss"],
        take_profit = json["take_profit"],
        max_hold_time = json["max_hold_time"]
    )
end
export parse_strategy

function parse_backtest_schema(json::AbstractDict)::BacktestSchema
    return BacktestSchema(
        start_offset = json["start_offset"],
        start_balance = json["start_balance"],
        alloc_size = json["alloc_size"],
        delay = json["delay"]
    )
end
export parse_backtest_schema

function parse_experiment(json::AbstractDict)::Experiment
    return Experiment(
        val_size = json["val_size"],
        test_size = json["test_size"],
        cv_folds = json["cv_folds"],
        fold_size = json["fold_size"],
        backtest_schema = parse_backtest_schema(json["backtest_schema"]),
        strategy = parse_strategy(json["strategy"])
    )
end
export parse_experiment

end