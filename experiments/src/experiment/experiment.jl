module ExperimentModule

using ..FeatureValuesModule
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
using Statistics
using StatsBase
using TimeSeries

@kwdef struct FoldResults
    start_date::DateTime
    end_date::DateTime
    train_results::BacktestResults
    val_results::BacktestResults
    test_results::BacktestResults
    opt_results::ItersState
end
export FoldResults

@kwdef struct ExperimentResults
    fold_results::Vector{FoldResults}
    overall_excess_sharpe::Float64
    invalid_frac::Float64
end
export ExperimentResults

@kwdef struct Experiment
    val_size::Float64
    test_size::Float64
    
    cv_folds::Int
    fold_size::Float64

    backtest_schema::BacktestSchema
    strategy::Strategy
end
export Experiment

@kwdef struct FoldData
    train_data::TimeArray
    val_data::TimeArray
    test_data::TimeArray
    
    train_feat_matrix::Matrix{Float64}
    val_feat_matrix::Matrix{Float64}
    test_feat_matrix::Matrix{Float64}
end
export FoldData
function construct_net(base_net::AbstractNetwork, seq::Vector{Symbol}, actions::AbstractActions)::AbstractNetwork
    net = deepcopy(base_net)
    state = ActionsState()

    if isa(actions, LogicActions)
        for action ∈ seq
            logic_action!(net, action, state, actions)
        end
    elseif isa(actions, DecisionActions)
        for action ∈ seq
            decision_action!(net, action, state, actions)
        end
    end

    return net
end
export construct_net

function penalty(net::AbstractNetwork, strategy::Strategy)::Float64
    penalties = strategy.penalties
    n_features = length(strategy.features)

    if isa(net, LogicNet)
        return logic_penalty(net, penalties, n_features)
    elseif isa(net, DecisionNet)
        return decision_penalty(net, penalties, n_features)
    end
end

function criterion(strategy::Strategy, schema::BacktestSchema, feat_matrix::Matrix{Float64}, data::TimeArray)::Function
    
    return function(seq::Vector{Symbol})
        net = construct_net(strategy.base_network, seq, strategy.actions)
        net_signals = network_signals!(strategy, net, feat_matrix, schema.delay)
        
        excess_sharpe = backtest(net_signals, strategy, schema, data).excess_sharpe
        penalty_score = penalty(net, strategy)

        return excess_sharpe - penalty_score
    end
end
export criterion

function actions_list(actions::AbstractActions)::Vector{Symbol}
    if isa(actions, LogicActions)
        return logic_actions_list(actions)
    elseif isa(actions, DecisionActions)
        return decision_actions_list(actions)
    end
end

function run_opt(strategy::Strategy, schema::BacktestSchema, fold::FoldData)::ItersState
    actions = actions_list(strategy.actions)

    train_criterion = criterion(strategy, schema, fold.train_feat_matrix, fold.train_data)
    val_criterion = criterion(strategy, schema, fold.val_feat_matrix, fold.val_data)

    criteria = Criteria(
        train = train_criterion,
        val = val_criterion
    )

    return optimize(strategy.optimizer, strategy.stop_conditions, actions, criteria)
end
export run_opt

function run_fold(experiment::Experiment, fold::FoldData)::FoldResults
    strategy = experiment.strategy
    schema = experiment.backtest_schema
    
    opt_results = run_opt(strategy, schema, fold)
    net = construct_net(strategy.base_network, opt_results.best_sequence, strategy.actions)

    delay = schema.delay

    train_signals = network_signals!(strategy, net, fold.train_feat_matrix, delay)
    train_results = backtest(train_signals, strategy, schema, fold.train_data)

    val_signals = network_signals!(strategy, net, fold.val_feat_matrix, delay)
    val_results = backtest(val_signals, strategy, schema, fold.val_data)

    test_signals = network_signals!(strategy, net, fold.test_feat_matrix, delay)
    test_results = backtest(test_signals, strategy, schema, fold.test_data)

    start_date = timestamp(fold.train_data)[1]
    end_date = timestamp(fold.test_data)[end]

    return FoldResults(
        start_date = start_date,
        end_date = end_date,
        train_results = train_results,
        val_results = val_results,
        test_results = test_results,
        opt_results = opt_results
    )
end
export run_fold

function fold_from_indices(data::TimeArray, strategy::Strategy, start_idx::Int, val_split::Int, test_split::Int, end_idx::Int)::FoldData
    
    train_data = data[start_idx:val_split]
    val_data = data[val_split + 1:test_split]
    test_data = data[test_split + 1:end_idx]

    features = strategy.features
    train_matrix = features_matrix(features, train_data)
    val_matrix = features_matrix(features, val_data)
    test_matrix = features_matrix(features, test_data)
    

    return FoldData(
        train_data = train_data,
        val_data = val_data,
        test_data = test_data,
        train_feat_matrix = train_matrix,
        val_feat_matrix = val_matrix,
        test_feat_matrix = test_matrix
    )
end
export fold_from_indices

function get_folds(experiment::Experiment, data::TimeArray)::Vector{FoldData}
    strategy = experiment.strategy
    cv_folds = experiment.cv_folds

    data_len = length(data)
    
    folds = Vector{FoldData}(undef, cv_folds)

    fold_len = data_len * experiment.fold_size
    fold_len = floor(Int, fold_len)

    range = data_len - fold_len
    divisor = max(1, cv_folds - 1)
    stride = range / divisor
    stride = floor(Int, stride)

    test_frac = 1 - experiment.test_size
    test_offset = test_frac * fold_len
    test_offset = floor(Int, test_offset)

    val_frac = test_frac - experiment.val_size
    val_offset = val_frac * fold_len
    val_offset = floor(Int, val_offset)

    for i ∈ 1:cv_folds

        start_idx = (i - 1) * stride + 1

        val_split = start_idx + val_offset
        test_split = start_idx + test_offset
        
        end_idx = start_idx + fold_len - 1
        
        folds[i] = fold_from_indices(data, strategy, start_idx, val_split, test_split, end_idx)
    end

    return folds
end
export get_folds

function experiment_results(fold_results::Vector{FoldResults})::ExperimentResults
    excess_sharpes = Float64[]
    n_invalid = 0

    for fr ∈ fold_results
        test_results = fr.test_results

        if test_results.is_invalid
            n_invalid += 1
        else
            push!(excess_sharpes, test_results.excess_sharpe)
        end
    end

    if isempty(excess_sharpes)
        overall_excess_sharpe = 0.0
    else
        overall_excess_sharpe = mean(excess_sharpes)
    end
    
    n_folds = length(fold_results)
    invalid_frac = n_invalid / n_folds

    return ExperimentResults(
        fold_results = fold_results,
        overall_excess_sharpe = overall_excess_sharpe,
        invalid_frac = invalid_frac
    )
end
export experiment_results

function run_experiment(experiment::Experiment, data::TimeArray)::ExperimentResults

    folds = get_folds(experiment, data)
    fold_results = [run_fold(experiment, fold) for fold ∈ folds]

    return experiment_results(fold_results)
end
export run_experiment

end