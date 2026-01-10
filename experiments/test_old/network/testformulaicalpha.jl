module TestFormulaicAlphaModule

include("../../src/utils.jl")
include("../../src/network/network.jl")
include("../../src/network/formulaicalpha.jl")
include("networkutils.jl")

using .NetworkModule
using .FormulaicAlphaModule
using .NetworkUtilsModule
using Test

function mock_alpha(nodes::Vector{<:FormulaicOperator})::FormulaicAlpha
    return FormulaicAlpha(
        nodes=nodes,
        default_value=0.0
    )
end

function mock_single_alpha(operation::Symbol)::FormulaicAlpha
    return [SingleOperator(
        operation=operation,
        input_index=1,
        input_type=:feature
    )] |> mock_alpha
end

function mock_multi_alpha(operation::Symbol)::FormulaicAlpha
    return [MultiOperator(
        operation=operation,
        input_indices=[1,2,3],
        input_types=fill(:feature, 3)
    )] |> mock_alpha
end

@testset "test alpha get input value" begin
    alpha = [SingleOperator(
        operation=:negate,
        value=67.0
    )] |> mock_alpha
    alpha.default_value = 67.0

    @test get_input_value(:none, 0, alpha, []) == 67.0
    @test get_input_value(:feature, 2, alpha, [0.0, 67.0]) == 67.0
    @test get_input_value(:node, 1, alpha, []) == 67.0
end

@testset "test alpha reset state" begin
    alpha = [SingleOperator(
        operation=:negate,
        value=0.0
    )] |> mock_alpha

    alpha.default_value = 67.0
    alpha |> reset_state!

    @test alpha |> first_value == 67.0
end

@testset "test alpha default evaluation" begin
    alpha = mock_alpha([SingleOperator(operation=:negate)])

    @test alpha.nodes[1].input_type == :none
    @test alpha.nodes[1].input_index == -1

    alpha.default_value = 67.0
    evaluate!(alpha, [0.0])

    @test alpha |> first_value == -67.0
end

@testset "test alpha negate evaluation" begin
    alpha = :negate |> mock_single_alpha

    evaluate!(alpha, [67.0])

    @test alpha |> first_value == -67.0
end

@testset "test alpha logarithm evaluation" begin
    alpha = :logarithm |> mock_single_alpha

    evaluate!(alpha, [67.0])

    @test isapprox(alpha |> first_value, 67.0 |> log)
end

@testset "test alpha exponent evaluation" begin
    alpha = :exponent |> mock_single_alpha

    evaluate!(alpha, [67.0])

    @test isapprox(alpha |> first_value, 67.0 |> exp)
end

@testset "test alpha sine evaluation" begin
    alpha = :sine |> mock_single_alpha

    evaluate!(alpha, [67.0])

    @test isapprox(alpha |> first_value, 67.0 |> sin)
end

@testset "test alpha cosine evaluation" begin
    alpha = :cosine |> mock_single_alpha

    evaluate!(alpha, [67.0])

    @test isapprox(alpha |> first_value, 67.0 |> cos)
end

@testset "test alpha tangent evaluation" begin
    alpha = :tangent |> mock_single_alpha

    evaluate!(alpha, [67.0])

    @test isapprox(alpha |> first_value, 67.0 |> tan)
end

@testset "test alpha add evaluation" begin
    alpha = :add |> mock_multi_alpha

    evaluate!(alpha, [1.0, 2.0, 3.0])

    @test alpha |> first_value == 6.0
end

@testset "test alpha subtract evaluation" begin
    alpha = :subtract |> mock_multi_alpha

    evaluate!(alpha, [1.0, 2.0, 3.0])

    @test alpha |> first_value == -4.0
end

@testset "test alpha multiply evaluation" begin
    alpha = :multiply |> mock_multi_alpha

    evaluate!(alpha, [4.0, 2.0, 1.0])

    @test alpha |> first_value == 8.0
end

@testset "test alpha divide evaluation" begin
    alpha = :divide |> mock_multi_alpha

    evaluate!(alpha, [4.0, 2.0, 1.0])

    @test alpha |> first_value == 2.0

    alpha.default_value = 67.0
    evaluate!(alpha, [4.0, 2.0, 0.0])

    @test alpha |> first_value == 67.0
end

@testset "test alpha max evaluation" begin
    alpha = :max |> mock_multi_alpha

    evaluate!(alpha, [7.0, 11.0, 9.0])

    @test alpha |> first_value == 11.0
end

@testset "test alpha min evaluation" begin
    alpha = :min |> mock_multi_alpha

    evaluate!(alpha, [7.0, 11.0, 9.0])

    @test alpha |> first_value == 7.0
end

@testset "test alpha feedforward evaluation" begin
    alpha = [
        SingleOperator(
            operation=:sine,
            input_index=1,
            input_type=:feature
        ),
        SingleOperator(
            operation=:cosine,
            input_index=1,
            input_type=:node
        )
    ] |> mock_alpha
    evaluate!(alpha, [67.0])
    
    @test isapprox(alpha |> first_value, 67.0 |> sin)
    @test isapprox(alpha |> second_value, 67.0 |> sin |> cos)
end

@testset "test alpha recurrent evaluation" begin
    alpha = [
        SingleOperator(
            operation=:cosine,
            input_index=2,
            input_type=:node
        ),
        SingleOperator(
            operation=:sine,
            input_index=1,
            input_type=:feature
        )
    ] |> mock_alpha

    alpha.default_value = 1.0
    alpha |> reset_state!

    evaluate!(alpha, [67.0])

    @test isapprox(alpha |> first_value, 1.0 |> cos)
    @test isapprox(alpha |> second_value, 67.0 |> sin)

    evaluate!(alpha, [1.0])

    @test isapprox(alpha |> first_value, 67.0 |> sin |> cos)
    @test isapprox(alpha |> second_value, 1.0 |> sin)
end

@testset "test alpha throw" begin
    alpha = [SingleOperator(
        operation=:negate,
        input_type=:asdf
    )] |> mock_alpha
    @test_throws "unrecognized input type: asdf" evaluate!(alpha, [67.0])

    set_first_node!(alpha, MultiOperator(
        operation=:add,
        input_types=[:asdf],
        input_indices=[-1]
    ))
    @test_throws "unrecognized input type: asdf" evaluate!(alpha, [67.0])

    set_first_node!(alpha, SingleOperator(
        operation=:asdf
    ))
    @test_throws "unrecognized single node operation: asdf" evaluate!(alpha, [67.0])

    set_first_node!(alpha, MultiOperator(
        operation=:asdf
    ))
    @test_throws "unrecognized multi node operation: asdf" evaluate!(alpha, [67.0])
end

end