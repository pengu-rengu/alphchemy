module TestDecisionNetworkModule

"../../src/utils.jl" |> include
"../../src/network/network.jl" |> include
"../../src/network/decisionnetwork.jl" |> include
"networkutilities.jl" |> include

using .NetworkModule
using .DecisionNetworkModule
using .NetworkUtilitiesModule
using Test

function mock_network(nodes::Vector{<:DecisionNode})::DecisionNetwork
    return DecisionNetwork(
        nodes = nodes,
        default_value = false
    )
end

function mock_branch_node(;
    input_index = -1,
    true_index = -1,
    false_index = -1,
    value = false
)::BranchNode
    return BranchNode(
        threshold = 0.5,
        input_index = input_index,
        true_index = true_index,
        false_index = false_index,
        value = value
    )
end

function mock_true_network()::DecisionNetwork
    return [mock_branch_node(value = true)] |> mock_network
end

function mock_empty_network()
    return DecisionNode[] |> mock_network
end

@testset "test decision reset state" begin
    network = mock_true_network()

    network |> reset_state!

    @test network |> first_value == false
end

@testset "test branch node" begin
    network = mock_empty_network()

    node = mock_branch_node()

    get_branch_node_value!(node, network, Float64[])
    @test node.value == false

    node.input_index = 1

    get_branch_node_value!(node, network, [1.0])
    @test node.value == true

    get_branch_node_value!(node, network, [0.0])
    @test node.value == false
end

@testset "test reference node" begin
    network = mock_true_network()

    node = RecursiveReferenceNode()
    @test node.reference_index == -1
    @test node.true_index == -1
    @test node.false_index == -1

    get_reference_node_value!(node, network)
    @test node.value == false

    node.reference_index = 1

    get_reference_node_value!(node, network)
    @test node.value == true
end

@testset "test update index" begin
    network = [
        mock_branch_node(false_index = 2),
        mock_branch_node(true_index = 5, value = true)
    ] |> mock_network

    @test update_index!(network, 1) == 2
    @test network.index_trail == [2]

    @test update_index!(network, 2) == 5
    @test network.index_trail == [2, 5]
end

@testset "test decision network evaluation" begin
    network = [
        mock_branch_node(),
        RecursiveReferenceNode()
    ] |> mock_network

    branch_node_index = -1
    reference_node_index = -1

    index = -1

    evaluate!(network, Float64[],
        get_branch_node_value! = (_, _, _) -> begin
            branch_node_index = index
        end,
        get_reference_node_value! = (_, _) -> begin
            reference_node_index = index
        end,
        update_index! = (_, current_index) -> begin
            new_index = current_index + 1
            index = new_index

            return new_index >= 3 ? -1 : new_index
        end
    )

    @test branch_node_index == -1
    @test reference_node_index == 2
    @test network.index_trail == [1]
end

@testset "test get index trail value" begin
    network = [
        mock_branch_node(value = true),
        mock_branch_node(),
        mock_branch_node(value = true)
    ] |> mock_network
    network.index_trail = [3, 1, 2]

    @test get_index_trail_value(network, 1) == true
    @test get_index_trail_value(network, 3) == false
end

@testset "test get decision node value" begin
    network = mock_empty_network()
    network.index_trail = 5 |> zeros
    
    current_index = -1

    mock_get_node_value = (anchor) -> begin
        get_node_value(network, NodePointer(
            anchor = anchor,
            index = 2
        ), get_index_trail_value = (_, index) -> begin
            current_index = index
            return false
        end)
    end

    mock_get_node_value(:from_start)
    @test current_index == 2

    mock_get_node_value(:from_end)
    @test current_index == 4
end

end