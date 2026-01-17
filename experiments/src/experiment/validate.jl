module ValidateModule

# TODO: move validate module into parsejson module

using ..FeaturesModule
using ..NetworkModule
using ..LogicNetModule
using ..DecisionNetModule
using ..ActionsModule
using ..DecisionActionsModule
using ..OptimizerModule
using ..GeneticModule
using ..StrategyModule
using ..BacktestModule
using ..ExperimentModule

function validate_feature(feature::AbstractFeature)
    feat_type = typeof(feature)

    if hasfield(feat_type, :ohlc)
        ohlc = feature.ohlc
        @assert ohlc ∈ [:open, :high, :low, :close] "invalid ohlc: $ohlc"
    end

    if hasfield(feat_type, :window)
        @assert feature.window > 0 "window must be > 0"
    end
    
    if hasfield(feat_type, :fast_window) && hasfield(feat_type, :slow_window)
        @assert feature.fast_window > 0 "fast window must be > 0"
        @assert feature.slow_window > 0 "slow window must be > 0"
        @assert feature.fast_window ≤ feature.slow_window "fast window must be ≤ slow window"
    end

    if isa(feature, RawReturns)
        returns_type = feature.returns_type
        @assert returns_type ∈ [:simple, :log] "invalid returns_type: $returns_type"
    end

    if isa(feature, NormalizedMACD)
        @assert feature.signal_window > 0 "signal window must be > 0"
    end
end
export validate_feature

function validate_features(features::Vector{AbstractFeature})
    for feature ∈ features
        validate_feature(feature)
    end

    feature_ids = map(feat -> feat.id, features)
    ids_len = length(feature_ids)

    unique_ids = Set(feature_ids)
    unique_ids_len = length(unique_ids)

    @assert ids_len == unique_ids_len "feature ids must be unique"
end
export validate_features

function validate_node_ptr(ptr::NodePointer)
    anchor = ptr.anchor

    @assert anchor ∈ [:from_start, :from_end] "invalid anchor: $anchor"
    @assert ptr.idx > 0 "node pointer idx must be > 0"
end
export validate_node_ptr

function validate_net(net::LogicNet, n_features::Int)
    nodes_len = length(net.nodes)

    for node ∈ net.nodes
        if isa(node, InputNode)
            @assert 1 ≤ node.feature_idx ≤ n_features "feature_idx must be 1 - # of features"
        elseif isa(node, LogicNode)
            gate = node.gate
            @assert gate ∈ [:AND, :OR, :XOR, :NAND, :NOR, :XNOR] "invalid gate: $gate"
            
            in1_idx = node.in1_idx
            in2_idx = node.in2_idx

            @assert in1_idx != 0 "in1_idx cannot be 0"
            @assert in2_idx != 0 "in2_idx cannot be 0"

            if in1_idx > 0
                @assert 1 ≤ in1_idx ≤ nodes_len "in1_idx must be 1 - # of nodes"
            end

            if in2_idx > 0
                @assert 1 ≤ in2_idx ≤ nodes_len "in2_idx must be 1 - # of nodes"
            end
        end
    end
end
export validate_net

function validate_net(net::DecisionNet, n_features::Int)
    @assert net.max_trail_len > 0 "max_trail_len must be > 0"

    nodes_len = length(net.nodes)

    for node ∈ net.nodes
        if isa(node, BranchNode)
            @assert 1 ≤ node.feature_idx ≤ n_features "feature_idx must be 1 - # of features"
        elseif isa(node, RefNode)
            @assert 1 ≤ node.ref_idx ≤ nodes_len "ref_idx must be 1 - # of nodes"
        end

        true_idx = node.true_idx
        false_idx = node.false_idx

        @assert true_idx != 0 "true_idx cannot be 0"
        @assert false_idx != 0 "false_idx cannot be 0"

        if true_idx > 0
            @assert 1 ≤ node.true_idx ≤ nodes_len "true_idx must be 1 - # of nodes"
        end
        
        if false_idx > 0
            @assert 1 ≤ node.false_idx ≤ nodes_len "false_idx must be 1 - # of nodes"
        end
    end
end

function validate_penalties(penalties::AbstractPenalties)
    @assert penalties.node ≥ 0.0 "node penalty must be ≥ 0.0"
    @assert penalties.used_feature ≥ 0.0 "used_feature penalty must be ≥ 0.0"
    @assert penalties.unused_feature ≥ 0.0 "unused_feature penalty must be ≥ 0.0"

    if isa(penalties, LogicPenalties)

        @assert penalties.input ≥ 0.0 "input penalty must be ≥ 0.0"
        @assert penalties.logic ≥ 0.0 "logic penalty must be ≥ 0.0"
        @assert penalties.recurrence ≥ 0.0 "recurrence penalty must be ≥ 0.0"
        @assert penalties.feedforward ≥ 0.0 "feedforward penalty must be ≥ 0.0"

    elseif isa(penalties, DecisionPenalties)

        @assert penalties.branch ≥ 0.0 "branch penalty must be ≥ 0.0"
        @assert penalties.ref ≥ 0.0 "ref penalty must be ≥ 0.0"
        @assert penalties.leaf ≥ 0.0 "leaf penalty must be ≥ 0.0"
        @assert penalties.non_leaf ≥ 0.0 "non_leaf penalty must be ≥ 0.0"

    end
end
export validate_penalties

function validate_actions(actions::AbstractActions, n_features::Int)
    meta_actions = actions.meta_actions

    meta_labels = keys(meta_actions)
    sub_actions = values(meta_actions)
    sub_actions = reduce(vcat, sub_actions, init = Symbol[])

    @assert isdisjoint(meta_labels, sub_actions) "sub action cannot be a meta action"

    @assert actions.n_thresholds > 0 "n_thresholds must be > 0"
    
    min_len = length(actions.min_thresholds)
    max_len = length(actions.max_thresholds)

    @assert min_len == n_features "length of min_thresholds must be == # of features"
    @assert max_len == n_features "length of max_thresholds must be == # of features"
end
export validate_actions

function validate_opt(opt::GeneticOpt)
    @assert opt.pop_size > 0 "pop_size must be > 0"
    @assert opt.seq_len > 0 "seq_len must be > 0"
    @assert 0 <= opt.n_elites <= opt.pop_size "n_elites must be 0 -  population size"
    @assert 0.0 <= opt.mutation_rate <= 1.0 "mutation rate must be 0.0 - 1.0"
    @assert 0.0 <= opt.crossover_rate <= 1.0 "crossover rate must be 0.0 - 1.0"
    @assert 1 <= opt.tournament_size <= opt.pop_size "tournament size must be 1 - population_size"
end
export validate_opt

function validate_stop_conditions(stop_conditions::StopConditions)
    @assert stop_conditions.max_iters > 0 "max_iters must be > 0"
    @assert stop_conditions.train_patience > 0 "train_patience must be > 0"
    @assert stop_conditions.val_patience > 0 "val_patience must be > 0"
end
export validate_stop_conditions

function validate_strategy(strategy::Strategy)
    features = strategy.features
    n_features = length(features)

    validate_features(strategy.features)
    validate_net(strategy.base_network, n_features)
    validate_actions(strategy.actions, n_features)
    validate_penalties(strategy.penalties)
    validate_stop_conditions(strategy.stop_conditions)
    validate_opt(strategy.optimizer)
    validate_node_ptr(strategy.entry_ptr)
    validate_node_ptr(strategy.exit_ptr)

    @assert strategy.stop_loss > 0.0 "stop_loss must be > 0.0"
    @assert strategy.take_profit > 0.0 "take_profit must be > 0.0"
    @assert strategy.max_holding_time > 0 "max_holding_time must be > 0"
end
export validate_strategy

function validate_backtest_schema(backtest_schema::BacktestSchema)
    @assert backtest_schema.start_offset ≥ 0 "start_offset must be ≥ 0"
    @assert backtest_schema.start_balance > 0 "start_balance must be > 0"
    @assert 0.0 < backtest_schema.alloc_size ≤ 1.0 "alloc_size must be ≥ 0.0 and ≤ 1.0"
    @assert backtest_schema.delay ≥ 0 "delay must be ≥ 0"
end
export validate_backtest_schema

function validate_experiment(experiment::Experiment)
    validate_backtest_schema(experiment.backtest_schema)
    validate_strategy(experiment.strategy)

    test_size = experiment.test_size
    val_size = experiment.val_size

    @assert test_size > 0.0 "test_size must be > 0.0"
    @assert val_size > 0.0 "val_size must be > 0.0"
    @assert test_size + val_size < 1.0 "test_size + val_size must be < 1.0"
    @assert experiment.cv_folds > 0 "cv_folds must be > 0"
    @assert 0.0 < experiment.fold_size ≤ 1.0 "fold_size must be > 0.0 and ≤ 1.0"
end
export validate_experiment

end