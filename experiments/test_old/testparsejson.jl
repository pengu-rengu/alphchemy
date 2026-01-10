#=
module TestParseJsonModule

include("../src/utils.jl")
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
include("../src/parsejson.jl")

using .NetworkModule
using .FeaturesModule
using .IndicatorsModule
using .MLFeaturesModule
using .FeatureValuesModule
using .FeatureDescriptionsModule
using .MLTrainingModule
using .ParseJsonModule
using Test
using JSON

@testset "test network from json" begin
    net = network_from_json(Dict(
        "nodes" => [
            Dict(
                "operation" => "AND",
                "in1_type" => "feature",
                "in1_index" => 1,
                "in2_type" => "feature",
                "in2_index" => 2
            ),
            Dict(
                "operation" => "OR",
                "in1_type" => "node",
                "in1_index" => 1,
                "in2_type" => "node",
                "in2_index" => 2
            )
        ]
    ))
    @test length(net.nodes) == 2
    @test net.nodes[1].operation == :AND
    @test net.nodes[1].in1_type == :feature
    @test net.nodes[1].in1_index == 1
    @test net.nodes[1].in2_type == :feature
    @test net.nodes[1].in2_index == 2

    @test net.nodes[2].operation == :OR
    @test net.nodes[2].in1_type == :node
    @test net.nodes[2].in1_index == 1
    @test net.nodes[2].in2_type == :node
    @test net.nodes[2].in2_index == 2
end

@testset "test constant feature from json" begin
    feature = feature_from_json(Dict(
        "feature" => "constant feature",
        "constant" => 10.0
    ))
    @test isa(feature, ConstantFeature)
    @test feature.constant == 10.0
end

@testset "test bool feature from json" begin
    feature = feature_from_json(Dict(
        "feature" => "bool feature",
        "constant" => true
    ))
    @test isa(feature, BoolFeature)
    @test feature.constant == true
end

@testset "test raw prices from json" begin
    feature = feature_from_json(Dict(
        "feature" => "raw prices",
        "ohlc" => "close"
    ))
    @test isa(feature, RawPrices)
    @test feature.ohlc == :close
end

@testset "relative prices from json" begin
    feature = feature_from_json(Dict(
        "feature" => "relative prices",
        "ohlc" => "close"
    ))
    @test isa(feature, RelativePrices)
    @test feature.ohlc == :close
end

@testset "log prices from json" begin
    feature = feature_from_json(Dict(
        "feature" => "log prices",
        "ohlc" => "close"
    ))
    @test isa(feature, LogPrices)
    @test feature.ohlc == :close
end

@testset "test sma from json" begin
    feature = feature_from_json(Dict(
        "feature" => "sma",
        "window" => 14,
        "ohlc" => "close"
    ))
    @test isa(feature, SMA)
    @test feature.window == 14
    @test feature.ohlc == :close
end

@testset "test ema from json" begin
    feature = feature_from_json(Dict(
        "feature" => "ema",
        "window" => 14,
        "wilder" => false,
        "ohlc" => "close"
    ))
    @test isa(feature, EMA)
    @test feature.window == 14
    @test feature.wilder == false
    @test feature.ohlc == :close
end

@testset "test kama from json" begin
    feature = feature_from_json(Dict(
        "feature" => "kama",
        "window" => 14,
        "fast_window" => 7,
        "slow_window" => 21,
        "ohlc" => "close"
    ))
    @test isa(feature, KAMA)
    @test feature.window == 14
    @test feature.fast_window == 7
    @test feature.slow_window == 21
    @test feature.ohlc == :close
end

@testset "test rsi from json" begin
    feature = feature_from_json(Dict(
        "feature" => "rsi",
        "window" => 14,
        "wilder" => true,
        "ohlc" => "close"
    ))
    @test isa(feature, RSI)
    @test feature.window == 14
    @test feature.wilder == true
    @test feature.ohlc == :close
end

@testset "test adx from json" begin
    feature = feature_from_json(Dict(
        "feature" => "adx",
        "window" => 14,
        "direction" => "positive"
    ))
    @test isa(feature, ADX)
    @test feature.window == 14
    @test feature.direction == :positive
end

@testset "test aroon oscillator from json" begin
    feature = feature_from_json(Dict(
        "feature" => "aroon oscillator",
        "window" => 14,
        "direction" => "up"
    ))
    @test isa(feature, AroonOscillator)
    @test feature.window == 14
    @test feature.direction == :up
end

@testset "test awesome oscillator from json" begin
    feature = feature_from_json(Dict(
        "feature" => "awesome oscillator"
    ))
    @test isa(feature, AwesomeOscillator)
end

@testset "test drpo from json" begin
    feature = feature_from_json(Dict(
        "feature" => "dpo",
        "window" => 14,
        "ohlc" => "close"
    ))
    @test isa(feature, DPO)
    @test feature.window == 14
    @test feature.ohlc == :close
end

@testset "test mass index from json" begin
    feature = feature_from_json(Dict(
        "feature" => "mass index",
        "window1" => 14,
        "window2" => 21
    ))
    @test isa(feature, MassIndex)
    @test feature.window1 == 14
    @test feature.window2 == 21
end

@testset "test trix from json" begin
    feature = feature_from_json(Dict(
        "feature" => "trix",
        "window" => 14,
        "ohlc" => "close"
    ))
    @test isa(feature, TRIX)
    @test feature.window == 14
    @test feature.ohlc == :close
end

@testset "text vortex indicator" begin
    feature = feature_from_json(Dict(
        "feature" => "vortex indicator",
        "window" => 14,
        "direction" => "positive"
    ))
    @test isa(feature, VortexIndicator)
    @test feature.window == 14
    @test feature.direction == :positive
end

@testset "test williams r" begin
    feature = feature_from_json(Dict(
        "feature" => "williams r",
        "window" => 14
    ))
    @test isa(feature, WilliamsR)
    @test feature.window == 14
end

@testset "test stochastic oscillator from json" begin
    feature = feature_from_json(Dict(
        "feature" => "stochastic oscillator",
        "window" => 14,
        "fast_window" => 7,
        "slow_window" => 21
    ))
    @test isa(feature, StochasticOscillator)
    @test feature.window == 14
    @test feature.fast_window == 7
    @test feature.slow_window == 21
end

@testset "test macd from json" begin
    feature = feature_from_json(Dict(
        "feature" => "macd",
        "fast_window" => 7,
        "slow_window" => 21,
        "signal_window" => 14,
        "ohlc" => "close",
        "output" => "signal"
    ))
    @test isa(feature, MACD)
    @test feature.fast_window == 7
    @test feature.slow_window == 21
    @test feature.signal_window == 14
    @test feature.ohlc == :close
    @test feature.output == :signal
end

@testset "test atr from json" begin
    feature = feature_from_json(Dict(
        "feature" => "atr",
        "window" => 14
    ))
    @test isa(feature, ATR)
    @test feature.window == 14
end

@testset "test bollinger bands from json" begin
    feature = feature_from_json(Dict(
        "feature" => "bollinger bands",
        "window" => 14,
        "std_multiplier" => 2.0,
        "band" => "upper",
        "ohlc" => "close"
    ))
    @test isa(feature, BollingerBands)
    @test feature.window == 14
    @test feature.std_multiplier == 2.0
    @test feature.band == :upper
    @test feature.ohlc == :close
end

@testset "test donchian channels from json" begin
    feature = feature_from_json(Dict(
        "feature" => "donchian channels",
        "window" => 14,
        "channel" => "upper"
    ))
    @test isa(feature, DonchianChannels)
    @test feature.window == 14
    @test feature.channel == :upper
end

@testset "test keltner bands from json" begin
    feature = feature_from_json(Dict(
        "feature" => "keltner bands",
        "window" => 14,
        "multiplier" => 2.0,
        "band" => :upper
    ))
    @test isa(feature, KeltnerBands)
    @test feature.window == 14
    @test feature.multiplier == 2.0
    @test feature.band == :upper
end

@testset "test arithmetic feature from json" begin
    feature = feature_from_json(Dict(
        "feature" => "arithmetic feature",
        "operation" => "add",
        "sub_feature1" => Dict(
            "feature" => "constant feature",
            "constant" => 1.0
        ),
        "sub_feature2" => Dict(
            "feature" => "constant feature",
            "constant" => 1.0
        )
    ))
    @test isa(feature, ArithmeticFeature)
    @test feature.operation == :add
    @test isa(feature.sub_feature1, ConstantFeature)
    @test isa(feature.sub_feature2, ConstantFeature)
end

@testset "test bin feature from json" begin
    feature = feature_from_json(Dict(
        "feature" => "bin feature",
        "min_value" => 1.0,
        "max_value" => 10.0,
        "inclusive" => false,
        "sub_feature" => Dict(
            "feature" => "constant feature",
            "constant" => 5.0
        )
    ))
    @test isa(feature, BinFeature)
    @test feature.min_value == 1.0
    @test feature.max_value == 10.0
    @test feature.inclusive == false
    @test isa(feature.sub_feature, ConstantFeature)
end

@testset "test feature from json throw" begin
    @test_throws "unrecognized feature: asdf" feature_from_json(Dict(
        "feature" => "asdf"
    ))
end

@testset "test actions schema from json" begin
    actions_schema = actions_schema_from_json(Dict(
        "meta_actions" => [
            Dict(
                "name" => "TEST1",
                "sub_actions" => ["NEW_AND_NODE", "NEW_OR_NODE"]
            ),
            Dict(
                "name" => "TEST2",
                "sub_actions" => ["SET_IN1_NODE", "SET_IN2_NODE"]
            )
        ],
        "allow_recurrence" => false
    ))
    @test actions_schema.meta_actions == Dict(
        "TEST1" => ["NEW_AND_NODE", "NEW_OR_NODE"],
        "TEST2" => ["SET_IN1_NODE", "SET_IN2_NODE"]
    )
end

@testset "test stop conditions from json" begin
    stop_conditions = stop_conditions_from_json(Dict(
        "time_limit" => 60.0,
        "max_iterations" => 100,
        "max_stuck_iterations" => 10,
        "max_best_score" => 0.3
    ))
    @test stop_conditions.time_limit == 60.0
    @test stop_conditions.max_iterations == 100
    @test stop_conditions.max_stuck_iterations == 10
    @test stop_conditions.max_best_score == 0.3
end

@testset "test genetic optimizer from json" begin
    opt = opt_from_json(Dict(
        "population_size" => 100,
        "sequence_length" => 50,
        "n_elites" => 5,
        "mutation_rate" => 0.1,
        "crossover_rate" => 0.7,
        "tournament_size" => 3,
        "mutation_delta" => 0.05,
        "crossover_delta" => 0.05,
        "tournament_delta" => 1,
        "mutation_min" => 0.01,
        "mutation_max" => 0.5,
        "crossover_min" => 0.5,
        "crossover_max" => 0.9,
        "tournament_min" => 2,
        "tournament_max" => 10,
        "n_length" => 10,
        "diversity_target" => 0.7
    ))
    @test opt.population_size == 100
    @test opt.sequence_length == 50
    @test opt.n_elites == 5
    @test opt.mutation_rate == 0.1
    @test opt.crossover_rate == 0.7
    @test opt.tournament_size == 3
    @test opt.mutation_delta == 0.05
    @test opt.crossover_delta == 0.05
    @test opt.tournament_delta == 1
    @test opt.mutation_min == 0.01
    @test opt.mutation_max == 0.5
    @test opt.crossover_min == 0.5
    @test opt.crossover_max == 0.9
    @test opt.tournament_min == 2
    @test opt.tournament_max == 10
    @test opt.n_length == 10
    @test opt.diversity_target == 0.7
end

@testset "test network penalties from json" begin
    penalties = network_penalties_from_json(Dict(
        "node_penalty" => 0.01,
        "recurrence_penalty" => 0.5,
        "feedforward_penalty" => 0.2,
        "used_feature_penalty" => 0.05,
        "unused_feature_penalty" => 0.1
    ))
    @test penalties.node_penalty == 0.01
    @test penalties.recurrence_penalty == 0.5
    @test penalties.feedforward_penalty == 0.2
    @test penalties.used_feature_penalty == 0.05
    @test penalties.unused_feature_penalty == 0.1
end

@testset "test node index from json" begin
    node_index = node_index_from_json(Dict(
        "index" => 2,
        "anchor" => "from_start"
    ))
    @test node_index.node_index == 2
    @test node_index.index_type == :from_start
end

end
=#