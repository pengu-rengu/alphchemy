#=
module TestExperimentModule

include("utils.jl")
include("../src/network.jl")
include("../src/features/features.jl")
include("../src/features/indicators.jl")
include("../src/features/mlfeatures.jl")
include("../src/features/featurevalues.jl")
include("../src/features/featuredescriptions.jl")
include("../src/features/mltraining.jl")
include("../src/actions.jl")
include("../src/optimizer.jl")
include("../src/strategy.jl")
include("../src/experiment.jl")

using .UtilsModule
using .NetworkModule
using .FeaturesModule
using .FeatureValuesModule
using .StrategyModule
using .ExperimentModule
using Statistics
using Test

mock_values = [100.0, 110.0, 120.0, 100.0]

function mock_features()::Vector{AbstractFeature}
    return [
        ComparisonFeature(
            comparison=:less_than,
            sub_feature1=ConstantFeature(
                constant=1.0
            ),
            sub_feature2=RawPrices(
                ohlc=:low
            )
        )
    ]
end

function mock_backtest_state()::BacktestState
    return BacktestState(
        network_signals=fill((true, true), 10),
        close_prices=ones(10),
        balance=0.0,
        equity=[],
        features_table=initial_features_table(mock_features())
    )
end

function mock_strategy()::Strategy
    strategy = Strategy(
        base_network=LogicNetwork(nodes=[]),
        features=mock_features(),
        network_opt=nothing,
        entry_node=NodeIndex(
            node_index=-1,
            index_type=:from_start
        ),
        exit_node=NodeIndex(
            node_index=-1,
            index_type=:from_start
        ),
        stop_loss=nothing,
        take_profit=nothing,
        min_holding_time=nothing,
        max_holding_time=nothing
    )
    get_values!(strategy.features, mock_prices(10))
    return strategy
end

function mock_experiment()::Experiment
    return Experiment(
        validation_size=0.2,
        cv_folds=3,
        starting_offset=0,
        starting_balance=10.0,
        strategy=mock_strategy()
    )
end

function mock_exit_conditions(;network_exit_signal=false, take_profit=false, stop_loss=false, max_holding_time=false)::NamedTuple
    return (
        min_holding_time = true,
        network_exit_signal = network_exit_signal,
        take_profit = take_profit,
        stop_loss = stop_loss,
        max_holding_time = max_holding_time
    )
end

@testset "test log returns" begin
    log_returns = get_log_returns(mock_values)

    @test length(log_returns) == 3
    @test isapprox(log_returns[1], log(110.0/100.0))
    @test isapprox(log_returns[2], log(120.0/110.0))
    @test isapprox(log_returns[3], log(100.0/120.0))
end

@testset "test sharpe ratio" begin
    log_returns = [log(110.0/100.0), log(120.0/110.0), log(100.0/120.0)]

    @test isapprox(get_sharpe_ratio(mock_values), mean(log_returns) / std(log_returns))
end

@testset "test entry update" begin
    state = mock_backtest_state()
    state.close_prices[3] = 2.0
    state.entries = 2

    entry_update!(state, 3)

    @test state.enter_price == 2.0
    @test state.entries == 3
    @test state.enter_index == 3
end

@testset "test network signal exit condition" begin
    strategy = mock_strategy()
    state = mock_backtest_state()

    @test get_exit_conditions(strategy, state, 1).network_exit_signal == true

    state.network_signals = [(true, false)]

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

@testset "test exit signal" begin
    @test get_exit_signal(mock_exit_conditions(network_exit_signal=true)) == true
    @test get_exit_signal(mock_exit_conditions(take_profit=true)) == true
    @test get_exit_signal(mock_exit_conditions(stop_loss=true)) == true
    @test get_exit_signal(mock_exit_conditions(max_holding_time=true)) == true

    @test get_exit_signal((
        min_holding_time = false,
        network_exit_signal = true,
        take_profit = true,
        stop_loss = true,
        max_holding_time = true
    )) == false
end

@testset "test initial features table" begin
    features_table = initial_features_table(mock_features())
    
    @test length(features_table.feature_values) == 3
    @test length(features_table.feature_descriptions) == 3
    
    @test features_table.feature_descriptions[1] == Dict(
        "feature" => "constant feature",
        "constant" => "1.0"
    )
    @test features_table.feature_descriptions[2] == Dict(
        "feature" => "raw prices",
        "ohlc" => "low"
    )
    @test features_table.feature_descriptions[3] == Dict(
        "feature" => "comparison feature",
        "comparison" => "less_than",
        "sub_feature1" => Dict(
            "feature" => "constant feature",
            "constant" => "1.0"
        ),
        "sub_feature2" => Dict(
            "feature" => "raw prices",
            "ohlc" => "low"
        )
    )
end

@testset "test update features table" begin
    state = mock_backtest_state()
    state.close_prices = Vector{Float64}(1:10)
    state.enter_price = 2.0

    strategy = mock_strategy()

    update_features_table!(strategy, state, mock_exit_conditions(network_exit_signal=true), 1)
    update_features_table!(strategy, state, mock_exit_conditions(take_profit=true), 3)
    update_features_table!(strategy, state, mock_exit_conditions(stop_loss=true), 5),
    update_features_table!(strategy, state, mock_exit_conditions(max_holding_time=true), 7)
    update_features_table!(strategy, state, mock_exit_conditions(
        network_exit_signal=true,
        take_profit=true,
        stop_loss=true,
        max_holding_time=true
    ), 9)
    
    @test state.features_table.feature_values[1] == fill(1.0, 5)
    @test state.features_table.feature_values[2] == [1.0, 3.0, 5.0, 7.0, 9.0]
    @test state.features_table.feature_values[3] == [false, true, true, true, true]
    @test state.features_table.profit_factors == [0.5, 1.5, 2.5, 3.5, 4.5]
    @test state.features_table.network_exit_signals == [true, false, false, false, true]
    @test state.features_table.take_profit_signals == [false, true, false, false, true]
    @test state.features_table.stop_loss_signals == [false, false, true, false, true]
    @test state.features_table.max_holding_time_signals == [false, false, false, true, true]
end

@testset "test exit update" begin
    state = mock_backtest_state()
    state.balance = 100.0
    state.close_prices[3] = 20.0
    state.enter_price = 10.0
    state.total_exits = 3

    strategy = mock_strategy()

    exit_update!(strategy, state, 3, 
        get_exit_conditions=(_, _, _) -> mock_exit_conditions(),
        get_exit_signal=(_) -> true
    )

    @test state.balance == 110.0
    @test state.enter_price == -1.0
    @test state.total_exits == 4
end

@testset "test exit update mean holding time" begin
    state = mock_backtest_state()
    state.close_prices = zeros(10)
    state.enter_index = 0

    strategy = mock_strategy()

    for n = [1,3,5,7]
        exit_update!(strategy, state, n, 
            get_exit_conditions=(_, _, _) -> mock_exit_conditions(),
            get_exit_signal=(_) -> true
        )
    end

    @test isapprox(state.mean_holding_time, sum([1,3,5,7]) / 4)
end

@testset "test exit update increments" begin
    state = mock_backtest_state()
    state.signal_exits = 3
    state.take_profit_exits = 3
    state.stop_loss_exits = 3
    state.max_holding_time_exits = 3

    strategy = mock_strategy()

    exit_update!(strategy, state, 1, get_exit_conditions=(_,_,_) -> mock_exit_conditions(network_exit_signal=true))
    @test state.signal_exits == 4

    exit_update!(strategy, state, 1, get_exit_conditions=(_,_,_) -> mock_exit_conditions(take_profit=true))
    @test state.take_profit_exits == 4

    exit_update!(strategy, state, 1, get_exit_conditions=(_,_,_) -> mock_exit_conditions(stop_loss=true))
    @test state.stop_loss_exits == 4

    exit_update!(strategy, state, 1, get_exit_conditions=(_,_,_) -> mock_exit_conditions(max_holding_time=true))
    @test state.max_holding_time_exits == 4
end

@testset "test exit update multiple increments" begin
    state = mock_backtest_state()
    strategy = mock_strategy()
    
    state.signal_exits = 3
    state.take_profit_exits = 3
    state.stop_loss_exits = 3
    state.max_holding_time_exits = 3
    state.total_exits = 3

    exit_update!(strategy, state, 1, get_exit_conditions=(_,_,_) -> (
        min_holding_time = true,
        network_exit_signal = true,
        take_profit = true,
        stop_loss = true,
        max_holding_time = true
    ))

    @test state.signal_exits == 4
    @test state.take_profit_exits == 4
    @test state.stop_loss_exits == 4
    @test state.max_holding_time_exits == 4
    @test state.total_exits == 4
end

@testset "test initial backtest state" begin
    experiment = mock_experiment()
    experiment.strategy.network_signals = fill((true, false), 10)
    experiment.starting_offset = 5

    prices = mock_prices(10)

    state = initial_backtest_state(experiment, prices)

    @test state.network_signals == fill((true, false), 10)
    @test state.close_prices == prices[:close] |> values
    @test state.balance == 10.0
    @test length(state.equity) == 5
end

@testset "test backtest invalid" begin
    experiment = mock_experiment()
    prices = mock_prices(0)

    @test isnothing(backtest(experiment, prices, initial_backtest_state=(_,_) -> begin
        b = mock_backtest_state()
        b.close_prices = []
        b.entries = 10
        b.equity = [1.0, 1.0, -2.0, 1.0]
        b
    end))

    @test isnothing(backtest(experiment, prices, initial_backtest_state=(_,_) -> begin
        b = mock_backtest_state()
        b.close_prices = []
        b.entries = 0
        b.equity = ones(4)
        b
    end))
end

@testset "test backtest" begin
    experiment = mock_experiment()
    prices = mock_prices(0)
    state = mock_backtest_state()
    state.network_signals = fill((false, false), 5)
    state.network_signals[2] = (true, false)
    state.network_signals[4] = (false, true)
    state.close_prices = Vector{Float64}(1:5)
    state.equity = Vector{Float64}(undef, 5)
    state.balance = 10.0

    excess_sharpe_ratio = backtest(experiment, prices, initial_backtest_state=(_,_) -> state)

    expected_equity = [10.0, 10.0, 11.0, 12.0, 12.0]

    @test state.equity == expected_equity
    @test excess_sharpe_ratio == get_sharpe_ratio(expected_equity) - get_sharpe_ratio(Vector{Float64}(1:5))
end

end
=#