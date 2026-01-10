module TestLogicNetworkModule

"../../src/utils.jl" |> include
"../../src/network/network.jl" |> include
"../../src/network/logicnetwork.jl" |> include
"networkutilities.jl" |> include

using .NetworkModule
using .LogicNetworkModule
using .NetworkUtilitiesModule
using Test

function mock_network(nodes::Vector{LogicNode})::LogicNetwork
    return LogicNetwork(
        nodes = nodes,
        default_value = false
    )
end

function mock_single_network(operation::Symbol)::LogicNetwork
    return [LogicNode(
        operation = operation,
        input1_index = 1,
        input1_type = :feature,
        input2_index = 2,
        input2_type = :feature
    )] |> mock_network
end

function mock_true_network()::LogicNetwork
    return [LogicNode(
        operation=:AND,
        value=true
    )] |> mock_network
end


@testset "test logic get input value" begin
    network = mock_true_network()

    @test get_input_value(:none, 0, network, []) == false
    @test get_input_value(:feature, 2, network, [false, true]) == true
    @test get_input_value(:node, 1, network, []) == true
end

@testset "test logic reset state" begin
    network = mock_true_network()

    network |> reset_state!

    @test network |> first_value == false
end

@testset "test logic AND operation" begin
    network = :AND |> mock_single_network

    evaluate!(network, [true, true])
    @test network |> first_value == true

    evaluate!(network, [false, true])
    @test network |> first_value == false
end

@testset "test logic node OR operation" begin
    network = :OR |> mock_single_network

    evaluate!(network, [false, true])
    @test network |> first_value == true

    evaluate!(network, [false, false])
    @test network |> first_value == false
end

@testset "test logic NAND operation" begin
    network = :NAND |> mock_single_network

    evaluate!(network, [true, true])
    @test network |> first_value == false

    evaluate!(network, [false, true])
    @test network |> first_value == true
end

@testset "test logic NOR operation" begin
    network = :NOR |> mock_single_network

    evaluate!(network, [false, false])
    @test network |> first_value == true

    evaluate!(network, [false, true])
    @test network |> first_value == false
end

@testset "test logic XOR evaluation" begin
    network = :XOR |> mock_single_network

    evaluate!(network, [true, true])
    @test network |> first_value == false

    evaluate!(network, [false, true])
    @test network |> first_value == true
end

@testset "test logic XNOR evaluation" begin
    network = :XNOR |> mock_single_network

    evaluate!(network, [true, true])
    @test network |> first_value == true

    evaluate!(network, [false, true])
    @test network |> first_value == false
end

@testset "test network default evaluation" begin
    network = mock_true_network()
    
    first_node = network.nodes[1]
    
    evaluate!(network, Bool[])

    @test network |> first_value == false
end

@testset "test network feedforward evaluation" begin
    network = [
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
        )
    ] |> mock_network
    
    evaluate!(network, [false, true, true])

    @test network |> first_value == false
    @test network |> second_value == true

    evaluate!(network, [true, true, false])

    @test network |> first_value == true
    @test network |> second_value == true
end

@testset "test network recurrent evaluation" begin
    network = [
        LogicNode(
            operation=:OR,
            input1_index=1,
            input1_type=:feature,
            input2_index=2,
            input2_type=:node
        ),
        LogicNode(
            operation=:AND,
            input1_index=2,
            input1_type=:feature,
            input2_index=3,
            input2_type=:feature
        )
    ] |> mock_network
    
    evaluate!(network, [false, true, true])

    @test network |> first_value == false
    @test network |> second_value == true

    evaluate!(network, [false, true, false])

    @test network |> first_value == true
    @test network |> second_value == false
end

end

