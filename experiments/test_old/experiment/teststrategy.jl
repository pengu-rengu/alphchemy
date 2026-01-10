module TestStrategyModule

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

using .TestUtilitiesModule
using .NetworkModule
using .LogicNetworkModule
using .FeaturesModule
using .OptimizerModule
using .LogicActionsModule
using .StrategyModule
using Test

struct NoOptimizer <: AbstractOptimizer end

#=
function mock_strategy()::Strategy
    strategy = Strategy(
        base_network=LogicNetwork(nodes=[
            LogicNode(
                operation=:AND,
                input1_index=1,
                input1_type=:feature,
                input2_index=2,
                input2_type=:feature
            ),
            LogicNode(
                operation=:OR,
                input1_index=3,
                input1_type=:feature,
                input2_index=1,
                input2_type=:node
            ),
            LogicNode(
                operation=:OR,
                input1_index=2,
                input1_type=:node,
                input2_index=4,
                input2_type=:node
            ),
            LogicNode(
                operation=:AND,
                input1_index=4,
                input1_type=:node,
                input2_index=4,
                input2_type=:feature
            )
        ]),
        features=[
            BoolFeature(constant=true),
            BoolFeature(constant=false),
            BoolFeature(constant=true),
            BoolFeature(constant=false),
            BoolFeature(constant=true),
        ],
        network_opt=nothing,
        entry_node=NodePointer(
            anchor=:from_start,
            index=1,
        ),
        exit_node=NodeIndex(
            anchor=:from_start,
            index=2,
        ),
        take_profit=nothing,
        stop_loss=nothing,
        min_holding_time=nothing,
        max_holding_time=nothing
    )
    strategy.network = deepcopy(strategy.base_network)
    return strategy
end

function strategy_with_penalties(;node_penalty=0.0, recurrence_penalty=0.0, feedforward_penalty=0.0, used_feature_penalty=0.0, unused_feature_penalty=0.0)::Strategy
    strategy = mock_strategy()
    strategy.network_opt = NetworkOptimizer(
        action_schema=ActionsSchema(
            meta_actions=Dict([]),
            allow_recurrence=true,
        ),
        penalties=NetworkPenalties(
            node_penalty=node_penalty,
            recurrence_penalty=recurrence_penalty,
            feedforward_penalty=feedforward_penalty,
            used_feature_penalty=used_feature_penalty,
            unused_feature_penalty=unused_feature_penalty
        ),
        stop_conditions=StopConditions(
            time_limit=nothing,
            max_iterations=nothing,
            max_stuck_iterations=nothing,
            max_best_score=nothing
        ),
        optimizer=NoOptimizer(),
    )
    return strategy
end


@testset "test network penalties" begin
    @test get_penalty(strategy_with_penalties(node_penalty=1.0)) == 4.0
    @test get_penalty(strategy_with_penalties(recurrence_penalty=1.0)) == 2.0
    @test get_penalty(strategy_with_penalties(feedforward_penalty=1.0)) == 2.0
    @test get_penalty(strategy_with_penalties(used_feature_penalty=1.0)) == 4.0
    @test get_penalty(strategy_with_penalties(unused_feature_penalty=1.0)) == 1.0
end


@testset "test reshape feature values" begin
    strategy = mock_strategy()
    get_values!(strategy.features, mock_prices(5))

    @test reshape_feature_values(strategy.features) == fill([true, false, true, false, true], 5)
end


@testset "test get node value" begin
    strategy = mock_strategy()

    evaluate!(strategy.network, [true, false, true, false])

    @test get_node_value(strategy.network, NodeIndex(
        node_index = 2,
        index_type = :from_start
    )) == true

    @test get_node_value(strategy.network, NodeIndex(
        node_index = 1,
        index_type = :from_end
    )) == false
end
=#

function get_entry_signal(strategy::Strategy, index::Int)::Bool
    return strategy.network_signals[index].entry_signal
end

function get_exit_signal(strategy::Strategy, index::Int)::Bool
    return strategy.network_signals[index].exit_signal
end


function mock_constant(number::Int)::ConstantFeature
    return ConstantFeature(
        id = number |> string,
        constant = 0.0
    )
end

#=
function mock_penalties(;
    node_penalty::Float64 = 0.0,
    recurrence_penalty::Float64 = 0.0,
    feedforward_penalty::Float64 = 0.0,
    used_feature_penalty::Float64 = 0.0,
    unused_feature_penalty::Float64 = 0.0
)
    return NetworkPenalties(
        node_penalty = node_penalty,
        recurrence_penalty = recurrence_penalty,
        feedforward_penalty = feedforward_penalty,
        used_feature_penalty = used_feature_penalty,
        unused_feature_penalty = unused_feature_penalty
    )
end
=#

function feature_id(features::Vector{<:AbstractFeature}, index::Int)::String
    return features[index].id
end

strategy = Strategy(
    base_network = LogicNetwork(
        nodes = [
            LogicNode(
                operation=:AND,
                input1_index = 1,
                input1_type = :feature,
                input2_index = 2,
                input2_type = :feature
            ),
            LogicNode(
                operation=:AND,
                input1_index = 1,
                input1_type = :node,
                input2_index = 2,
                input2_type = :node
            )
        ],
        default_value = false
    ),
    features = [
        ConstantFeature(
            id = "feature 1",
            constant = 0.0,
            values = [1.0, 2.0, 3.0]
        ),
        ConstantFeature(
            id = "feature 2",
            constant = 0.0,
            values = 3 |> zeros
        ),
        ConstantFeature(
            id = "feature 3",
            constant = 0.0,
            values = 3 |> zeros
        )
    ],
    network_optimizer = nothing,
    entry_pointer = NodePointer(
        anchor = :from_start,
        index = 1
    ),
    exit_pointer = NodePointer(
        anchor = :from_end,
        index = 1
    ),
    stop_loss = nothing,
    take_profit = nothing,
    min_holding_time = nothing,
    max_holding_time = nothing
)
strategy.network = strategy.base_network

# TODO: test penalties

@testset "test get network signals" begin

    feature_values = Float64[]

    get_network_signals!(strategy,
        (evaluate!) = (_, input_vector) -> begin
            push!(feature_values, input_vector[1])
        end,
        get_node_value = (_, _) -> begin
            return true
        end
    )

    @test feature_values == [1.0, 2.0]

    @test get_entry_signal(strategy, 1) == false
    @test get_exit_signal(strategy, 1) == false

    @test get_entry_signal(strategy, 2) == true
    @test get_exit_signal(strategy, 2) == true

    @test get_entry_signal(strategy, 3) == true
    @test get_exit_signal(strategy, 3) == true
end

@testset "test get flattened features" begin
    flattened_features = get_flattened_features([
        ComparisonFeature(
            id = "comparison",
            sub_feature1 = 1 |> mock_constant,
            sub_feature2 = 2 |> mock_constant
        ),
        RollingMean(
            id = "rolling mean",
            window = 0,
            sub_feature = 3 |> mock_constant
        ),
        RollingStd(
            id = "rolling std",
            window = 0,
            sub_feature = 4 |> mock_constant
        ),
        RollingQuantile(
            id = "rolling quantile",
            window = 0,
            quantile = 0.0,
            sub_feature = 5 |> mock_constant
        ),
        NetworkFeature(
            id = "network feature",
            sub_features = [
                6 |> mock_constant,
                7 |> mock_constant
            ],
            network = LogicNetwork(
                nodes = [],
                default_value = false
            ),
            output_pointer = NodePointer(
                anchor = :from_start,
                index = 1
            )
        )
    ])

    @test feature_id(flattened_features, 1) == "1"
    @test feature_id(flattened_features, 2) == "2"
    @test feature_id(flattened_features, 3) == "comparison"
    @test feature_id(flattened_features, 4) == "3"
    @test feature_id(flattened_features, 5)== "rolling mean"
    @test feature_id(flattened_features, 6) == "4"
    @test feature_id(flattened_features, 7) == "rolling std"
    @test feature_id(flattened_features, 8) == "5"
    @test feature_id(flattened_features, 9) == "rolling quantile"
    @test feature_id(flattened_features, 10) == "6"
    @test feature_id(flattened_features, 11) == "7"
    @test feature_id(flattened_features, 12) == "network feature"
end

end