module ParseJsonModule

using ..FeaturesModule
using ..NetworkModule
using ..PenaltiesModule
using ..ActionsModule

using ..OptimizerModule
using ..GeneticModule

using ..StrategyModule
using ..BacktestModule
using ..ExperimentModule

function parse_feat(json::AbstractDict)::AbstractFeature
    feature = json["feature"]
    id = json["id"]

    if haskey(json, "ohlc")
        ohlc = Symbol(json["ohlc"])
        @assert ohlc ∈ [:open, :high, :low, :close] "invalid ohlc: $ohlc"
    end

    if haskey(json, "window")
        window = json["window"]
        @assert window > 0 "window must be > 0"
    end

    has_fast = haskey(json, "fast_window")
    has_slow = haskey(json, "slow_window")
    
    if has_fast && has_slow
        fast_window = json["fast_window"]
        slow_window = json["slow_window"]

        @assert fast_window > 0 "fast window must be > 0"
        @assert slow_window > 0 "slow window must be > 0"
        @assert fast_window ≤ feature.slow_window "fast window must be ≤ slow window"
    end

    if haskey(json, "wilder")
        wilder = json["wilder"]
    end

    if haskey(json, "multiplier")
        multiplier = json["multiplier"]

        @assert multiplier > 0 "multiplier must be > 0"
    end

    if haskey(json, "out")
        out = Symbol(json["out"])

        if feature ∈ ["adx", "vortex"]
            @assert out ∈ [:pos, :neg] "invalid out for feature \"$feature\": $out"
        elseif feature ∈ ["normalized bb", "normalized dc", "normalized kc"]
            @assert out ∈ [:upper, :middle, :lower] "invalid out for feature \"$feature\": $out"
        end
    end

    if feature == "constant"
        return Constant(
            id = id,
            constant = json["constant"]
        )
    elseif feature == "raw returns"
        returns_type = Symbol(json["returns_type"])
        @assert returns_type ∈ [:simple, :log] "invalid returns_type: $returns_type"

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
        @assert out ∈ [:up, :down] "invalid out for feature \"aroon\": $out"

        return Aroon(
            id = id,
            window = window,
            out = out
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
            out = out
        )
    elseif feature == "williams r"
        return WilliamsR(
            id = id,
            window = window
        )
    elseif feature == "stochastic"
        @assert out ∈ [:fask_k, :fast_d, :slow_d] "invalid out for feature \"stochastic\": $out"

        return Stochastic(
            id = id,
            window = window,
            fast_window = fast_window,
            slow_window = slow_window,
            out = out
        )
    elseif feature == "normalized macd"
        signal_window = json["signal_window"]

        @assert signal_window > 0 "signal window must be > 0"
        @assert out ∈ [:macd, :diff, :signal] "invalid out for feature \"normalized macd\": $out"

        return NormalizedMACD(
            id = id,
            fast_window = fast_window,
            slow_window = slow_window,
            signal_window = signal_window,
            ohlc = ohlc,
            out = out
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
            multiplier = multiplier,
            ohlc = ohlc,
            out = out
        )
    elseif feature == "normalized dc"
        return NormalizedDC(
            id = id,
            window = window,
            out = out
        )
    elseif feature == "normalized kc"
        return NormalizedKC(
            id = id,
            window = window,
            multiplier = multiplier,
            out = out
        )
    end

    error("invalid feature $feature")
end
export parse_feat

function parse_node_ptr(json::AbstractDict)::NodePtr
    anchor = Symbol(json["anchor"])
    @assert anchor ∈ [:from_start, :from_end] "invalid anchor: $anchor"

    node_ptr = NodePtr(
        anchor = anchor,
        idx = json["idx"]
    )
    @assert node_ptr.idx > 0 "node pointer idx must be > 0"

    return node_ptr
end
export parse_node_ptr

function validate_feat_idx(node::Union{InputNode, BranchNode}, n_feats::Int)
    feat_idx = node.feat_idx
    @assert feat_idx != 0 "feat_idx cannot be 0"

    if feat_idx > 0
        @assert 1 ≤ node.feat_idx ≤ n_feats "feat_idx must be 1 - # of features"
    end
end
export validate_feat_idx

function parse_logic_node(json::AbstractDict, n_feats::Int, n_nodes::Int)::Union{InputNode, LogicNode}
    type = json["type"]

    if type == "input"
        node = InputNode(
            threshold = json["threshold"],
            feat_idx = json["feat_idx"]
        )
        validate_feat_idx(node, n_feats)

        return node
    elseif type == "logic"
        gate = Symbol(json["gate"])
        @assert gate ∈ [:AND, :OR, :XOR, :NAND, :NOR, :XNOR] "invalid gate: $gate"

        in1_idx = json["in1_idx"]
        in2_idx = json["in2_idx"]
        
        @assert in1_idx != 0 "in1_idx cannot be 0"
        @assert in2_idx != 0 "in2_idx cannot be 0"
        
        if in1_idx > 0
            @assert 1 ≤ in1_idx ≤ n_nodes "in1_idx must be 1 - # of nodes"
        end
        
        if in2_idx > 0
            @assert 1 ≤ node.in2_idx ≤ n_nodes "in2_idx must be 1 - # of nodes"
        end

        return LogicNode(
            gate = gate,
            in1_idx = in1_idx,
            in2_idx = in2_idx
        ) 
    end

    error("invalid logic node type: $type")
end
export parse_logic_node

function parse_decision_node(json::AbstractDict, n_feats::Int, n_nodes::Int)::Union{BranchNode, RefNode}
    type = json["type"]

    true_idx = json["true_idx"]
    false_idx = json["false_idx"]

    @assert true_idx != 0 "true_idx cannot be 0"
    @assert false_idx != 0 "false_idx cannot be 0"

    if true_idx > 0
        @assert 1 ≤ true_idx ≤ n_nodes "true_idx must be 1 - # of nodes"
    end

    if false_idx > 0
        @assert 1 ≤ false_idx ≤ n_nodes "false_idx must be 1 - # of nodes"
    end

    if type == "branch"
        node = BranchNode(
            threshold = json["threshold"],
            feature_idx = json["feat_idx"],
            true_idx = true_idx,
            false_idx = false_idx
        )

        validate_feat_idx(node, n_feats)

        return node
    elseif type == "ref"
        ref_idx = json["ref_idx"]

        @assert ref_idx != 0 "ref_idx cannot be 0"

        if ref_idx > 0
            @assert 1 ≤ ref_idx ≤ n_nodes "ref_idx must be 1 - # of nodes"
        end

        node = RefNode(
            ref_idx = ref_idx,
            true_idx = true_idx,
            false_idx = false_idx
        )

        return node
    end

    error("invalid decision node type: $type")
end
export parse_decision_node

function parse_net(json::AbstractDict, n_feats::int)::AbstractNetwork
    type = json["type"]

    nodes_json = json["nodes"]
    default_value = json["default_value"]

    n_nodes = length(nodes_json)

    if type == "logic"
        return LogicNet(
            nodes = [parse_logic_node(node_json, n_feats, n_nodes) for node_json ∈ nodes_json],
            default_value = default_value
        )
    elseif type == "decision"
        max_trail_len = json["max_trail_len"]
        @assert max_trail_len > 0 "max_trail_len must be > 0"

        return DecisionNet(
            nodes = [parse_decision_node(node_json, n_feats, n_nodes) for node_json ∈ nodes_json],
            max_trail_len = max_trail_len,
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

    @assert node_penalty ≥ 0.0 "node penalty must be ≥ 0.0"
    @assert used_penalty ≥ 0.0 "used_feat penalty must be ≥ 0.0"
    @assert unused_penalty ≥ 0.0 "unused_feat penalty must be ≥ 0.0"

    if type == "logic"
        penalties = LogicPenalties(
            node = node_penalty,
            input = json["input"],
            logic = json["logic"],
            recurrence = json["recurrence"],
            feedforward = json["feedforward"],
            used_feat = used_penalty,
            unused_feat = unused_penalty
        )

        @assert penalties.input ≥ 0.0 "input penalty must be ≥ 0.0"
        @assert penalties.logic ≥ 0.0 "logic penalty must be ≥ 0.0"
        @assert penalties.recurrence ≥ 0.0 "recurrence penalty must be ≥ 0.0"
        @assert penalties.feedforward ≥ 0.0 "feedforward penalty must be ≥ 0.0"
    elseif type == "decision"
        penalties = DecisionPenalties(
            node = node_penalty,
            branch = json["branch"],
            ref = json["ref"],
            leaf = json["leaf"],
            non_leaf = json["non_leaf"],
            used_feat = used_penalty,
            unused_feat = unused_penalty
        )

        @assert penalties.branch ≥ 0.0 "branch penalty must be ≥ 0.0"
        @assert penalties.ref ≥ 0.0 "ref penalty must be ≥ 0.0"
        @assert penalties.leaf ≥ 0.0 "leaf penalty must be ≥ 0.0"
        @assert penalties.non_leaf ≥ 0.0 "non_leaf penalty must be ≥ 0.0"
    else
        error("invalid penalties type: $type")
    end

    return penalties
end

function parse_thresholds(json::AbstractVector, feats::Vector{<:AbstractFeature})::Vector{ThresholdRange}
    n_features = length(feats)
    thresholds_len = length(json)

    @assert thresholds_len == n_features "length of thresholds must be == # of features"

    thresholds = Vector{ThresholdRange}(undef, thresholds_len)

    for threshold_json ∈ json
        feat_id = threshold_json["feat_id"]
        idx = findfirst(feat -> feat.id == feat_id, feats)

        if isnothing(idx)
            error("feature with id \"$feat_id\" not found")
        end

        thresholds[idx] = ThresholdRange(
            min = threshold_json["min"],
            max = threshold_json["max"]
        )
    end

    return thresholds
end
export parse_thresholds

function parse_meta_actions(json::AbstractVector)::Dict{Symbol, Vector{Symbol}}
    meta_actions = Dict{Symbol, Vector{Symbol}}()

    labels = Vector{Symbol}()
    all_sub_actions = Vector{Symbol}()

    for meta_json ∈ json
        label = Symbol(meta_json["label"])
        sub_actions = [Symbol(sub_action) for sub_action ∈ meta_json["sub_actions"]]
        
        meta_actions[label] = sub_actions

        push!(labels, label)
        append!(all_sub_actions, sub_actions)
    end

    @assert isdisjoint(labels, all_sub_actions) "sub action cannot be a meta action"

    return meta_actions
end
export parse_meta_actions

function parse_actions(json::AbstractDict, features::Vector{<:AbstractFeature})::AbstractActions
    type = json["type"]

    meta_actions = parse_meta_actions(json["meta_actions"])
    thresholds = parse_thresholds(json["thresholds"], features)

    n_thresholds = json["n_thresholds"]
    @assert n_thresholds > 0 "n_thresholds must be > 0"
    
    if type == "logic"
        return LogicActions(
            meta_actions = meta_actions,
            thresholds = thresholds,
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
            thresholds = thresholds,
            n_thresholds = n_thresholds,
            allow_refs = json["allow_refs"],
            allow_cycles = json["allow_cycles"]
        )
    end

    error("invalid actions type: $type")
end
export parse_actions

function parse_stop_conds(json::AbstractDict)::StopConds
    stop_conds = StopConds(
        max_iters = json["max_iters"],
        train_patience = json["train_patience"],
        val_patience = json["val_patience"]
    )
    
    @assert stop_conds.max_iters > 0 "max_iters must be > 0"
    @assert stop_conds.train_patience ≥ 0 "train patience must be ≥ 0"
    @assert stop_conds.val_patience ≥ 0 "val patience must be ≥ 0"

    return stop_conds
end
export parse_stop_conds

function parse_opt(json::AbstractDict)::AbstractOpt
    type = json["type"]

    if type == "genetic"
        opt = GeneticOpt(
            pop_size = json["pop_size"],
            seq_len = json["seq_len"],
            n_elites = json["n_elites"],
            mut_rate = json["mut_rate"],
            cross_rate = json["cross_rate"],
            tourn_size = json["tournament_size"]
        )

        @assert opt.pop_size > 0 "pop_size must be > 0"
        @assert opt.seq_len > 0 "seq_len must be > 0"
        @assert 0 <= opt.n_elites <= opt.pop_size "n_elites must be 0 -  population size"
        @assert 0.0 <= opt.mut_rate <= 1.0 "mut_rate must be 0.0 - 1.0"
        @assert 0.0 <= opt.cross_rate <= 1.0 "cross_rate must be 0.0 - 1.0"
        @assert 1 <= opt.tourn_size <= opt.pop_size "tourn_size must be 1 - pop_size"

        return opt
    end

    error("invalid optimizer type: $type")
end
export parse_opt

function validate_feat_ids(feats::Vector{<:AbstractFeature})
    feature_ids = map(feat -> feat.id, feats)
    ids_len = length(feature_ids)

    unique_ids = Set(feature_ids)
    unique_ids_len = length(unique_ids)

    @assert ids_len == unique_ids_len "feature ids must be unique"
end
export validate_feat_ids

function parse_strategy(json::AbstractDict)::Strategy
    feats = [parse_feat(feat_json) for feat_json ∈ json["feats"]]
    n_feats = len(feats)

    validate_feat_ids(feats)

    net = parse_net(json["base_net"], n_feats)
    actions = parse_actions(json["actions"], feats)
    penalties = parse_penalties(json["penalties"])
    stop_conds = parse_stop_conds(json["stop_conds"])
    opt = parse_opt(json["opt"])
    entry_ptr = parse_node_ptr(json["entry_ptr"])
    exit_ptr = parse_node_ptr(json["exit_ptr"])

    strategy = Strategy(
        base_net = net,
        feats = feats,
        actions = actions,
        penalties = penalties,
        stop_conds = stop_conds,
        opt = opt,
        entry_ptr = entry_ptr,
        exit_ptr = exit_ptr,
        stop_loss = json["stop_loss"],
        take_profit = json["take_profit"],
        max_hold_time = json["max_hold_time"]
    )

    @assert strategy.stop_loss > 0.0 "stop_loss must be > 0.0"
    @assert strategy.take_profit > 0.0 "take_profit must be > 0.0"
    @assert strategy.max_hold_time > 0 "max_hold_time must be > 0"

    return strategy
end
export parse_strategy

function parse_backtest_schema(json::AbstractDict)::BacktestSchema
    schema = BacktestSchema(
        start_offset = json["start_offset"],
        start_balance = json["start_balance"],
        alloc_size = json["alloc_size"],
        delay = json["delay"]
    )

    @assert schema.start_offset ≥ 0 "start_offset must be ≥ 0"
    @assert schema.start_balance > 0.0 "start_balance must be > 0.0"
    @assert 0.0 < schema.alloc_size ≤ 1.0 "alloc_size must be ≥ 0.0 and ≤ 1.0"
    @assert schema.delay ≥ 0 "delay must be ≥ 0"

    return schema
end
export parse_backtest_schema

function parse_experiment(json::AbstractDict)::Experiment
    test_size = json["val_size"]
    val_size = json["test_size"]
    cv_folds = json["cv_folds"]
    fold_size = json["fold_size"]

    @assert val_size > 0.0 "val_size must be > 0.0"
    @assert test_size > 0.0 "test_size must be > 0.0"
    @assert val_size + test_size < 1.0 "val_size + test_size must be < 1.0"
    @assert cv_folds > 0 "cv_folds must be > 0"
    @assert 0.0 < fold_size ≤ 1.0 "fold_size must be > 0.0 and ≤ 1.0"

    backtest_schema = parse_backtest_schema(json["backtest_schema"])
    strategy = parse_strategy(json["strategy"])

    return Experiment(
        val_size = val_size,
        test_size = test_size,
        cv_folds = cv_folds,
        fold_size = fold_size,
        backtest_schema = backtest_schema,
        strategy = strategy
    )
end
export parse_experiment

end