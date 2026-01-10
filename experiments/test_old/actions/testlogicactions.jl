module TestActionsModule

include("../../src/utils.jl")
include("../../src/network/network.jl")
include("../../src/network/logicnetwork.jl")
include("../../src/optimizer/optimizer.jl")
include("../../src/actions/logicactions.jl")

using .LogicNetworkModule
using .LogicActionsModule
using Test

function mock_schema(;  meta_actions::Dict = Dict(), allow_recurrence::Bool = true)
    return LogicActionsSchema(
        meta_actions = meta_actions,
        allow_recurrence = allow_recurrence,
        n_features = 3
    )
end

function first_node(network::LogicNetwork)::LogicNode
    return network.nodes[1]
end

function second_node(network::LogicNetwork)::LogicNode
    return network.nodes[2]
end

function fourth_node(network::LogicNetwork)::LogicNode
    return network.nodes[4]
end

function mock_network()
    return LogicNetwork(
        nodes = fill(LogicNode(operation=:AND), 3),
        default_value = false
    )
end

@testset "test initial logic actions state" begin
    state = LogicActionsState()

    @test state.feature_index == 1
    @test state.node_index == 1
    @test state.selected_index == 1
end

@testset "test NEXT_NODE" begin
    network = mock_network()
    state = LogicActionsState(node_index = 2)
    schema = mock_schema()

    do_action!(network, :NEXT_NODE, state, schema)

    @test state.node_index == 3

    do_action!(network, :NEXT_NODE, state, schema)

    @test state.node_index == 1
end

@testset "test NEXT_FEATURE" begin
    network = mock_network()
    state = LogicActionsState(feature_index = 2)
    schema = mock_schema()

    do_action!(network, :NEXT_FEATURE, state, schema)

    @test state.feature_index == 3

    do_action!(network, :NEXT_FEATURE, state, schema)

    @test state.feature_index == 1
end

@testset "test SELECT_NODE" begin
    state = LogicActionsState(node_index = 2)

    do_action!(mock_network(), :SELECT_NODE, state, mock_schema())

    @test state.selected_index == 2
end

@testset "test SET_IN1_NODE" begin
    network = mock_network()

    do_action!(network, :SET_IN1_NODE, LogicActionsState(node_index = 2), mock_schema())

    node = network |> second_node

    @test node.input1_index == 1
    @test node.input1_type == :node
end

@testset "test SET_IN1_NODE no recurrence" begin
    network = mock_network()

    do_action!(network, :SET_IN1_NODE, LogicActionsState(selected_index = 2), mock_schema(allow_recurrence = false))

    node = network |> first_node
    
    @test node.input1_index == -1
    @test node.input1_type == :none
end

@testset "test SET_IN2_NODE" begin
    network = mock_network()

    do_action!(network, :SET_IN2_NODE, LogicActionsState(node_index = 2), mock_schema())

    node = network |> second_node

    @test node.input2_index == 1
    @test node.input2_type == :node
end

@testset "test SET_IN2_NODE no recurrence" begin
    network = mock_network()

    do_action!(network, :SET_IN2_NODE, LogicActionsState(selected_index = 2), mock_schema(allow_recurrence = false))

    node = network |> first_node

    @test node.input2_index == -1
    @test node.input2_type == :none
end

@testset "test SET_IN1_FEATURE" begin
    network = mock_network()

    do_action!(network, :SET_IN1_FEATURE, LogicActionsState(feature_index = 3), mock_schema())

    node = network |> first_node

    @test node.input1_index == 3
    @test node.input1_type == :feature
end

@testset "test SET_IN2_FEATURE" begin
    network = mock_network()

    do_action!(network, :SET_IN2_FEATURE, LogicActionsState(feature_index = 3), mock_schema())

    node = network |> first_node

    @test node.input2_index == 3
    @test node.input2_type == :feature
end

@testset "test NEW_AND_NODE" begin
    network = mock_network()
    
    do_action!(network, :NEW_AND_NODE, LogicActionsState(), mock_schema())

    @test (network |> fourth_node).operation == :AND
end

@testset "test NEW_OR_NODE" begin
    network = mock_network()

    do_action!(network, :NEW_OR_NODE, LogicActionsState(), mock_schema())

    @test (network |> fourth_node).operation == :OR
end

@testset "test NEW_NAND_NODE" begin
    network = mock_network()

    do_action!(network, :NEW_NAND_NODE, LogicActionsState(), mock_schema())
    
    @test (network |> fourth_node).operation == :NAND
end

@testset "test NEW_NOR_NODE" begin
    network = mock_network()

    do_action!(network, :NEW_NOR_NODE, LogicActionsState(), mock_schema())

    @test (network |> fourth_node).operation == :NOR
end

@testset "test meta actions" begin
    network = mock_network()

    do_action!(network, :TEST, LogicActionsState(), mock_schema(meta_actions = Dict(
        :TEST => [:NEW_AND_NODE, :NEW_OR_NODE]
    )))

    @test (network |> fourth_node).operation == :AND
    @test network.nodes[5].operation == :OR
end

end