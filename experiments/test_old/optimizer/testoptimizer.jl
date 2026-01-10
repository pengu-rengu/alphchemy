# TODO: fix this module

#=
module TestOptimizerModule

using .OptimizerModule
using Test

function mock_optimizer()::GeneticOptimizer
    return GeneticOptimizer(
        population_size=10,
        sequence_length=5,
        n_elites=3,
        mutation_rate=0.3,
        crossover_rate=0.3,
        tournament_size=3,
        mutation_delta=0.15,
        crossover_delta=0.15,
        tournament_delta=1,
        mutation_min=0.1,
        mutation_max=0.5,
        crossover_min=0.1,
        crossover_max=0.5,
        tournament_min=2,
        tournament_max=4,
        n_length=3,
        diversity_target=0.5
    )
end

function mock_stop_conditions(;time_limit=nothing, max_iterations=nothing, max_stuck_iterations=nothing, max_best_score=nothing)::StopConditions
    return StopConditions(
        time_limit=time_limit,
        max_iterations=max_iterations,
        max_stuck_iterations=max_stuck_iterations,
        max_best_score=max_best_score
    )
end

function mock_params()::OptimizerParams
    return OptimizerParams(
        eval_func=(seq) -> 1.0,
        sample_action=() -> 1,
        stop_conditions=mock_stop_conditions()
    )
end

@testset "test init_optimizer" begin
    opt = mock_optimizer()

    init_optimizer!(opt, mock_params())

    @test opt.population == [fill(1, 5) for _ = 1:10]
    @test opt.scores == fill(0.0, 10)
end

@testset "test evaluate_scores" begin
    opt = mock_optimizer()
    params = mock_params()
    params.eval_func = (seq) -> seq[1] == 2 ? 2.0 : 1.0

    init_optimizer!(opt, params)
    opt.population[1][1] = 2

    @test evaluate_scores!(opt, params) == 2.0
    @test opt.scores == [2.0; fill(1.0, 9)]
end

@testset "test select" begin
    opt = mock_optimizer()
    params = mock_params()
    params.rand_tournament = (_, _) -> [2, 3, 5]

    init_optimizer!(opt, params)
    opt.population[3] = fill(2, 5)
    opt.scores[1] = 10.0
    opt.scores[3] = 5.0

    @test select(opt, params) == fill(2, 5)
end

@testset "test crossover" begin
    opt = mock_optimizer()
    params = mock_params()
    params.rand_crossover_number = () -> 0.1
    params.rand_crossover_index = (_) -> 3
    params.rand_first_parent = () -> true

    @test crossover(opt, params, fill(1, 5), fill(2, 5)) == [1, 1, 1, 2, 2]

    params.rand_first_parent = () -> false
    @test crossover(opt, params, fill(1, 5), fill(2, 5)) == [2, 2, 2, 1, 1]

    params.rand_crossover_number = () -> 0.5
    @test crossover(opt, params, fill(1, 5), fill(2, 5)) == fill(2, 5)

    params.rand_first_parent = () -> true
    @test crossover(opt, params, fill(1, 5), fill(2, 5)) == fill(1, 5)

end

@testset "test mutation" begin
    opt = mock_optimizer()
    params = mock_params()
    params.rand_mutation_indices = (_, _) -> [2, 5]

    @test mutate(opt, params, fill(2, 5)) == [2, 1, 2, 2, 1]
end

@testset "test mutation adjustment" begin
    opt = mock_optimizer()
    params = mock_params()
    params.rand_operator = () -> "mutation"

    adjust!(opt, params, 0.1)
    @test isapprox(opt.mutation_rate, 0.45)

    adjust!(opt, params, 0.1)
    @test opt.mutation_rate == 0.5

    opt.mutation_rate = 0.3

    adjust!(opt, params, 0.9)
    @test isapprox(opt.mutation_rate, 0.15)

    adjust!(opt, params, 0.9)
    @test opt.mutation_rate == 0.1
end

@testset "test crossover adjustment" begin
    opt = mock_optimizer()
    params = mock_params()
    params.rand_operator = () -> "crossover"

    adjust!(opt, params, 0.1)
    @test isapprox(opt.crossover_rate, 0.45)

    adjust!(opt, params, 0.1)
    @test opt.crossover_rate == 0.5

    opt.crossover_rate = 0.3

    adjust!(opt, params, 0.9)
    @test isapprox(opt.crossover_rate, 0.15)

    adjust!(opt, params, 0.9)
    @test opt.crossover_rate == 0.1
end

@testset "test tournament adjustment" begin
    opt = mock_optimizer()
    params = mock_params()
    params.rand_operator = () -> "tournament"

    adjust!(opt, params, 0.1)
    @test opt.tournament_size == 2

    adjust!(opt, params, 0.1)
    @test opt.tournament_size == 2

    opt.tournament_size = 3

    adjust!(opt, params, 0.9)
    @test opt.tournament_size == 4

    adjust!(opt, params, 0.9)
    @test opt.tournament_size == 4
end

@testset "test diversity calculation" begin
    opt = mock_optimizer()
    params = mock_params()

    init_optimizer!(opt, params)

    opt.population[1] = fill(2, 5)
    opt.population[2] = fill(3, 5)
    opt.population[3] = fill(4, 5)

    @test calculate_diversity(opt) == 4/30
end

@testset "test adjust throw" begin
    opt = mock_optimizer()
    params = mock_params()
    params.rand_operator = () -> "asdf"

    @test_throws "unrecognized operator: asdf" adjust!(opt, params, 0.5)
end

@testset "test get elites" begin
    opt = mock_optimizer()
    params = mock_params()

    init_optimizer!(opt, params)
    opt.scores[2] = 7.0
    opt.population[2] = fill(2, 5)
    opt.scores[5] = 5.0
    opt.population[5] = fill(2, 5)
    opt.scores[7] = 2.0
    opt.population[7] = fill(2, 5)

    @test get_elites(opt) == [fill(2, 5) for _ = 1:3]
end

@testset "test stop condition" begin
    @test get_stop_condition(mock_stop_conditions(time_limit=60.0), 120.0, 0, [(0, 0.0)], 0.0) == true
    @test get_stop_condition(mock_stop_conditions(time_limit=60.0), 30.0, 0, [(0, 0.0)], 0.0) == false

    @test get_stop_condition(mock_stop_conditions(max_iterations=50), 0.0, 60, [(0, 0.0)], 0.0) == true
    @test get_stop_condition(mock_stop_conditions(max_iterations=50), 0.0, 40, [(0, 0.0)], 0.0) == false

    @test get_stop_condition(mock_stop_conditions(max_stuck_iterations=10), 0.0, 50, [(35, 0.0)], 0.0) == true
    @test get_stop_condition(mock_stop_conditions(max_stuck_iterations=10), 0.0, 50, [(45, 0.0)], 0.0) == false
end

end
=#