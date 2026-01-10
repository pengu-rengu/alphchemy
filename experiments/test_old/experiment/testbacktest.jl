module TestBacktestModule

include("../testutilities.jl")
include("../../src/utils.jl")
include("../../src/network/network.jl")
include("../../src/network/logicnetwork.jl")
include("../../src/features/features.jl")
include("../../src/features/indicators.jl")
include("../../src/features/mlfeatures.jl")
include("../../src/features/featurevalues.jl")
include("../../src/features/mltraining.jl")
include("../../src/optimizer/optimizer.jl")
include("../../src/actions/logicactions.jl")
include("../../src/experiment/strategy.jl")
include("../../src/experiment/backtest.jl")

using .TestUtilitiesModule
using .UtilsModule
using .NetworkModule
using .LogicNetworkModule
using .FeaturesModule
using .StrategyModule
using .BacktestModule
using Statistics
using TimeSeries
using Test

mock_values = [100.0, 110.0, 120.0, 100.0]

function mock_features()::Vector{AbstractFeature}
    return [
        ComparisonFeature(
            id = "1",
            sub_feature1=ConstantFeature(
                id = "2",
                constant=1.0
            ),
            sub_feature2=RawPrices(
                id = "3",
                ohlc=:low
            )
        )
    ]
end

function mock_backtest_state()::BacktestState
    return BacktestState(
        network_signals = fill(NetworkSignals(
            entry_signal = true,
            exit_signal = true
        ), 10),
        close_prices = 10 |> ones,
        balance = 100.0,
        equity = 10 |> zeros,
    )
end

function mock_backtest_schema()::BacktestSchema
    return BacktestSchema(
        starting_offset = 3,
        starting_balance = 100.0
    )
end

function mock_strategy()::Strategy
    strategy = Strategy(
        base_network = LogicNetwork(
            nodes = [],
            default_value = false
        ),
        features = mock_features(),
        network_optimizer = nothing,
        entry_pointer = NodePointer(
            index = -1,
            anchor = :from_start
        ),
        exit_pointer = NodePointer(
            index = -1,
            anchor = :from_start
        ),
        stop_loss = nothing,
        take_profit = nothing,
        min_holding_time = nothing,
        max_holding_time = nothing
    )

    return strategy
end

function mock_exit_conditions(;
    network_exit_signal = false,
    take_profit = false,
    stop_loss = false,
    max_holding_time = false
)::ExitConditions
    return ExitConditions(
        min_holding_time = true,
        network_exit_signal = network_exit_signal,
        take_profit = take_profit,
        stop_loss = stop_loss,
        max_holding_time = max_holding_time
    )
end


@testset "test log returns" begin
    log_returns = mock_values |> get_log_returns

    @test log_returns |> length == 3
    @test isapprox(log_returns, [110.0 / 100.0 |> log, 120.0 / 110.0 |> log, 100.0 / 120.0 |> log])
end

@testset "test sharpe ratio" begin
    log_returns = [110.0 / 100.0 |> log, 120.0 / 110.0 |> log, 100.0 / 120.0 |> log]

    @test isapprox(mock_values |> get_sharpe_ratio, (log_returns |> mean) / (log_returns |> std))
end

@testset "test entry update" begin
    state = mock_backtest_state()
    state.close_prices[3] = 2.0
    state.entries = 2

    entry_update!(state, 3)

    @test state.enter_price == 2.0
    @test state.entries == 3
    @test state.enter_index == 3

    state.network_signals[5] = NetworkSignals(
        entry_signal = false,
        exit_signal = true
    )

    entry_update!(state, 5)

    @test state.enter_price == 2.0
    @test state.entries == 3
    @test state.enter_index == 3
end

@testset "test network signal exit condition" begin
    strategy = mock_strategy()
    state = mock_backtest_state()

    @test get_exit_conditions(strategy, state, 1).network_exit_signal == true

    state.network_signals = [NetworkSignals(
        entry_signal = true,
        exit_signal = false
    )]

    @test get_exit_conditions(strategy, state, 1).network_exit_signal == false
end

@testset "test take profit exit condition" begin
    state = mock_backtest_state()
    state.enter_price = 1.0
    state.close_prices = [2.0]

    strategy = mock_strategy()
    strategy.take_profit = 0.5

    @test get_exit_conditions(strategy, state, 1).take_profit == true

    state.close_prices = [1.1]
    
    @test get_exit_conditions(strategy, state, 1).take_profit == false
end

@testset "test stop loss exit condition" begin
    state = mock_backtest_state()
    state.enter_price = 3.0
    state.close_prices = [1.0]

    strategy = mock_strategy()
    strategy.stop_loss = 0.5

    @test get_exit_conditions(strategy, state, 1).stop_loss == true

    state.close_prices = [2.0]

    @test get_exit_conditions(strategy, state, 1).stop_loss == false
end

@testset "test min holding time exit condition" begin
    state = mock_backtest_state() 
    state.enter_index = 1

    strategy = mock_strategy()
    strategy.min_holding_time = 5

    @test get_exit_conditions(strategy, state, 10).min_holding_time == true
    @test get_exit_conditions(strategy, state, 4).min_holding_time == false
end

@testset "test max holding time exit condition" begin
    state = mock_backtest_state()
    state.enter_index = 1

    strategy = mock_strategy()
    strategy.max_holding_time = 5

    @test get_exit_conditions(strategy, state, 10).max_holding_time == true
    @test get_exit_conditions(strategy, state, 4).max_holding_time == false
end

@testset "test get exit signal" begin
    @test mock_exit_conditions(network_exit_signal = true) |> get_exit_signal == true
    @test mock_exit_conditions(take_profit = true) |> get_exit_signal == true
    @test mock_exit_conditions(stop_loss = true) |> get_exit_signal == true
    @test mock_exit_conditions(max_holding_time = true) |> get_exit_signal == true

    @test ExitConditions(
        min_holding_time = false,
        network_exit_signal = true,
        take_profit = true,
        stop_loss = true,
        max_holding_time = true
    ) |> get_exit_signal == false
end

@testset "test increment exit counts" begin
    state = mock_backtest_state()

    increment_exit_counts!(state, mock_exit_conditions(network_exit_signal = true))
    @test state.signal_exits == 1

    increment_exit_counts!(state, mock_exit_conditions(take_profit = true))
    @test state.take_profit_exits == 1

    increment_exit_counts!(state, mock_exit_conditions(stop_loss = true))
    @test state.stop_loss_exits == 1

    increment_exit_counts!(state, mock_exit_conditions(max_holding_time = true))
    @test state.max_holding_time_exits == 1

    increment_exit_counts!(state, ExitConditions(
        min_holding_time = false,
        network_exit_signal = true,
        take_profit = true,
        stop_loss = true,
        max_holding_time = true
    ))

    @test state.signal_exits == 2
    @test state.take_profit_exits == 2
    @test state.stop_loss_exits == 2
    @test state.max_holding_time_exits == 2
end

@testset "test exit update" begin
    state = mock_backtest_state()
    state.close_prices[3] = 20.0
    state.enter_price = 10.0
    state.total_exits = 3

    strategy = mock_strategy()

    increment_exits = false

    exit_update!(strategy, state, 3, 
        get_exit_conditions = (_, _, _) -> mock_exit_conditions(),
        get_exit_signal = (_) -> true,
        (increment_exit_counts!) = (_, _) -> begin
            increment_exits = true
        end
    )

    @test state.balance == 110.0
    @test state.enter_price == -1.0
    @test state.total_exits == 4
    @test increment_exits == true
    
    increment_exits = false

    exit_update!(strategy, state, 5, 
        get_exit_conditions = (_, _, _) -> mock_exit_conditions(),
        get_exit_signal = (_) -> false,
        (increment_exit_counts!) = (_, _) -> begin
            increment_exits = true
        end
    )

    @test state.balance == 110.0
    @test state.enter_price == -1.0
    @test state.total_exits == 4
    @test increment_exits == false
end

@testset "test initial backtest state" begin
    prices = 10 |> mock_prices

    strategy = mock_strategy()
    strategy.network_signals = [NetworkSignals(
        entry_signal = false,
        exit_signal = true
    )]

    state = initial_backtest_state(strategy, mock_backtest_schema(), prices)

    network_signals = state.network_signals
    signal = network_signals[1]

    @test network_signals |> length == 1
    @test signal.entry_signal == false
    @test signal.exit_signal == true
    
    @test state.close_prices == prices[:close] |> values
    @test state.equity |> length == 7
end

@testset "test update equity" begin
    state = mock_backtest_state()
    schema = mock_backtest_schema()
    
    update_equity!(schema, state, 4)

    @test state.equity[1] == 100.0
    
    state.close_prices[5]  = 20.0
    state.enter_price = 10.0

    update_equity!(schema, state, 5)

    @test state.equity[2] == 110.0
end

@testset "test backtest iteration" begin
    strategy = mock_strategy()
    schema = mock_backtest_schema()
    state = mock_backtest_state()

    enter_index = -1
    exit_index = -1
    update_index = -1

    backtest_iteration!(strategy, schema, state, 10;
        (entry_update!) = (_, index) -> begin
            enter_index = index
        end,
        (update_equity!) = (_, _, index) -> begin
            update_index = index
        end
    )

    @test enter_index == 10
    @test update_index == 10

    state.enter_price = 1.0

    backtest_iteration!(strategy, schema, state, 20;
        (exit_update!) = (_, _, index) -> begin
            exit_index = index
        end,
        (update_equity!) = (_, _, index) -> begin
            update_index = index
        end
    )

    @test exit_index == 20
    @test update_index == 20
end

end