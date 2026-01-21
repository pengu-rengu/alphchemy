module ToJsonModule

using ..OptimizerModule
using ..BacktestModule
using ..ExperimentModule

function improvements_json(improvements::Vector{Improvement})::Vector{Dict}
    return [Dict(
        "iter" => improvement.iter,
        "score" => improvement.score
    ) for improvement ∈ improvements]
end
export improvements_json

function opt_results_json(results::ItersState)::Dict{String, Any}
    train_json = improvements_json(results.train_improvements)
    val_json = improvements_json(results.val_improvements)

    return Dict(
        "iters" => results.iters,
        "best_seq" => results.best_sequence,
        "train_improvements" => train_json,
        "val_improvements" => val_json
    )
end
export opt_results

function backtest_results_json(results::BacktestResults)::Dict{String, Any}
    state = results.final_state

    return Dict(
        "is_invalid" => results.is_invalid,
        "excess_sharpe" => results.excess_sharpe,
        "mean_hold_time" => results.mean_hold_time,
        "std_hold_time" => results.std_hold_time,
        "total_exits" => state.total_exits,
        "signal_exits" => state.signal_exits,
        "stop_loss_exits" => state.stop_loss_exits,
        "take_profit_exits" => state.take_profit_exits,
        "max_hold_time_exits" => state.max_hold_time_exits
    )
end
export backtest_results_json

function fold_results_json(results::FoldResults)::Dict{String, Any}

    start_date = string(results.start_date)
    end_date = string(results.end_date)

    opt_json = opt_results_json(results.opt_results)

    train_json = backtest_results_json(results.train_results)
    val_json = backtest_results_json(results.val_results)
    test_json = backtest_results_json(results.test_results)

    return Dict(
        "start_date" => start_date,
        "end_date" => end_date,
        "opt_results" => opt_json,
        "train_results" => train_json,
        "val_results" => val_json,
        "test_results" => test_json
    )
end
export fold_results_json

function experiment_results_json(results::ExperimentResults)::Dict{String, Any}
    folds_json = [fold_results_json(fold_results) for fold_results ∈ results.fold_results]

    return Dict(
        "overall_excess_sharpe" => results.overall_excess_sharpe,
        "invalid_frac" => results.invalid_frac,
        "fold_results" => folds_json
    )
end
export experiment_results_json

end