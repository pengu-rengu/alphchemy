module BacktestModule

using ..FeaturesModule
using ..StrategyModule
using TimeSeries
using Statistics

@kwdef mutable struct BacktestState
    net_signals::Vector{NetworkSignal}
    close_prices::Vector{Float64}
    balance::Float64
    equity::Vector{Float64}

    enter_price::Float64 = -1.0
    enter_idx::Int = -1
    enter_size::Float64 = -1.0
    entries::Int = 0

    total_exits::Int = 0
    signal_exits::Int = 0
    take_profit_exits::Int = 0
    stop_loss_exits::Int = 0
    max_holding_time_exits::Int = 0

    holding_times::Vector{Int} = []
end
export BacktestState

@kwdef struct BacktestResults
    excess_sharpe::Float64
    mean_holding_time::Float64
    std_holding_time::Float64
    is_invalid::Bool
    final_state::BacktestState
end
export BacktestResults

@kwdef struct BacktestSchema
    start_offset::Int
    start_balance::Float64
    alloc_size::Float64
    delay::Int
end
export BacktestSchema

@kwdef struct ExitConditions
    exit_signal::Bool
    take_profit::Bool
    stop_loss::Bool
    max_holding_time::Bool
end
export ExitConditions

function sharpe(values::Vector{Float64})::Float64
    returns = log_returns(values)

    μ = mean(returns)
    σ = std(returns)

    if σ == 0.0
        return 0.0
    end
    
    return μ / σ
end
export sharpe

function entry_update!(schema::BacktestSchema, state::BacktestState, idx::Int)
    if !state.net_signals[idx].entry
        return
    end

    current_close = state.close_prices[idx]
    
    state.enter_price = current_close

    alloc_amount = state.balance * schema.alloc_size
    state.enter_size = alloc_amount / current_close

    state.entries += 1
    state.enter_idx = idx
end
export entry_update!

function exit_conditions(strategy::Strategy, state::BacktestState, idx::Int)::ExitConditions
    current_close = state.close_prices[idx]
    
    enter_price = state.enter_price

    take_profit_ratio = 1 + strategy.take_profit
    take_profit_price = enter_price * take_profit_ratio
    take_profit_signal = current_close > take_profit_price
    
    stop_loss_ratio = 1 - strategy.stop_loss
    stop_loss_price = enter_price * stop_loss_ratio
    stop_loss_signal = current_close < stop_loss_price

    indices_since_enter = idx - state.enter_idx
    holding_time_signal = indices_since_enter ≥ strategy.max_holding_time

    return ExitConditions(
        exit_signal = state.net_signals[idx].exit,
        take_profit = take_profit_signal,
        stop_loss = stop_loss_signal,
        max_holding_time = holding_time_signal
    )
end
export exit_conditions

function should_exit(exit_conditions::ExitConditions)::Bool
    return exit_conditions.exit_signal || exit_conditions.stop_loss || exit_conditions.take_profit || exit_conditions.max_holding_time
end
export should_exit

function inc_exit_counts!(state::BacktestState, exit_conditions::ExitConditions)
    state.total_exits += 1

    if exit_conditions.exit_signal
        state.signal_exits += 1
    end

    if exit_conditions.take_profit
        state.take_profit_exits += 1
    end

    if exit_conditions.stop_loss
        state.stop_loss_exits += 1
    end

    if exit_conditions.max_holding_time
        state.max_holding_time_exits += 1
    end
end
export inc_exit_counts!

function exit_update!(strategy::Strategy, state::BacktestState, idx::Int)
    conditions = exit_conditions(strategy, state, idx)

    if !should_exit(conditions)
        return
    end
    
    diff = state.close_prices[idx] - state.enter_price
    state.balance += diff * state.enter_size
    state.enter_price = -1.0

    holding_time = idx - state.enter_idx
    push!(state.holding_times, holding_time)

    inc_exit_counts!(state, conditions)
end
export exit_update!

function initial_backtest_state(net_signals::Vector{NetworkSignal}, schema::BacktestSchema, data::TimeArray)::BacktestState
    close_values = values(data[:close])

    data_len = length(data)
    equity_len = data_len - schema.start_offset
    
    initial_equity = Vector{Float64}(undef, equity_len)

    return BacktestState(
        net_signals = net_signals,
        close_prices = close_values,
        balance = schema.start_balance,
        equity = initial_equity,
    )
end
export initial_backtest_state

function update_equity!(schema::BacktestSchema, state::BacktestState, idx::Int)
    enter_price = state.enter_price
    balance = state.balance

    equity_idx = idx - schema.start_offset
    equity_value = balance

    if enter_price > 0.0
        diff = state.close_prices[idx] - enter_price
        unrealized = state.enter_size * diff

        equity_value += unrealized
    end

    state.equity[equity_idx] = equity_value
end
export update_equity!

function backtest_iter!(strategy::Strategy, schema::BacktestSchema, state::BacktestState, idx::Int)
    if state.enter_price < 0
        entry_update!(schema, state, idx)
    else
        exit_update!(strategy, state, idx)
    end
    
    update_equity!(schema, state, idx)
end
export backtest_iter!

function backtest_results(state::BacktestState, schema::BacktestSchema)::BacktestResults
    is_neg = state.equity .< 0.0
    neg_equity = any(is_neg)
    no_exits = state.total_exits == 0

    if neg_equity || no_exits
        return BacktestResults(
            excess_sharpe = 0.0,
            mean_holding_time = 0.0,
            std_holding_time = 0.0,
            is_invalid = true,
            final_state = state
        )
    end
    
    adjusted_offset = schema.start_offset + 1
    close_sharpe = sharpe(state.close_prices[adjusted_offset:end])
    equity_sharpe = sharpe(state.equity)
    excess_sharpe = equity_sharpe - close_sharpe

    hold_time_μ = mean(state.holding_times)
    hold_time_σ = std(state.holding_times)
    if isnan(hold_time_σ)
        hold_time_σ = 0.0
    end

    return BacktestResults(
        excess_sharpe = excess_sharpe,
        mean_holding_time = hold_time_μ,
        std_holding_time = hold_time_σ,
        is_invalid = false,
        final_state = state
    )
end
export backtest_results

function backtest(net_signals::Vector{NetworkSignal}, strategy::Strategy, schema::BacktestSchema, data::TimeArray)::BacktestResults
    state = initial_backtest_state(net_signals, schema, data)

    adjusted_offset = schema.start_offset + 1
    close_len = length(state.close_prices)

    for i ∈ adjusted_offset:close_len
        backtest_iter!(strategy, schema, state, i)
    end

    return backtest_results(state, schema)
end
export backtest

end