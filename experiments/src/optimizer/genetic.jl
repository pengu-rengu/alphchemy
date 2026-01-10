module GeneticModule

using ..OptimizerModule
using StatsBase

@kwdef struct GeneticOpt <: PopulationOpt
    pop_size::Int
    seq_len::Int

    n_elites::Int

    mutation_rate::Float64
    crossover_rate::Float64
    tournament_size::Int
end
export GeneticOpt

function select(opt::GeneticOpt, state::POState;
    tournament_indices = (pop_size, tournament_size) -> sample(1:pop_size, tournament_size, replace = false)
)::Vector{Symbol}

    indices = tournament_indices(opt.pop_size, opt.tournament_size)
    best_idx = argmax(idx -> state.scores[idx], indices)
    
    return state.pop[best_idx]
end
export select

function crossover(opt::GeneticOpt, parent1::Vector{Symbol}, parent2::Vector{Symbol};
    crossover_chance = rand,
    crossover_idx = (seq_len) -> rand(1:seq_len),
    parent_order = () -> rand(Bool)
)::Vector{Symbol}

    if crossover_chance() < opt.crossover_rate
        first = crossover_idx(opt.seq_len)
        second = first + 1

        if parent_order()
            return vcat((@view parent1[1:first]), (@view parent2[second:end]))
        end

        return vcat((@view parent2[1:first]), (@view parent1[second:end]))
    end

    if parent_order()
        return copy(parent1)
    end
    return copy(parent2)
end
export crossover

function get_elites(opt::GeneticOpt, state::POState)::Vector{Vector{Symbol}}
    if opt.n_elites == 0
        return []
    end
    
    return state.pop[partialsortperm(state.scores, 1:opt.n_elites, rev = true)]
end
export get_elites

function new_child(opt::GeneticOpt, state::POState, actions_list::Vector{Symbol})::Vector{Symbol}

    parent1 = select(opt, state)
    parent2 = select(opt, state)

    child = crossover(opt, parent1, parent2)
    mutate!(opt, actions_list, child)

    return child
end
export new_child

function new_population!(opt::GeneticOpt, state::POState, actions_list::Vector{Symbol})
    n_elites = opt.n_elites
    pop_size = opt.pop_size

    n_non_elites = pop_size - n_elites

    new_pop = Vector{Vector{Symbol}}(undef, pop_size)
    new_pop[1:n_elites] .= get_elites(opt, state)
    new_pop[n_elites + 1:end] .= [new_child(opt, state, actions_list) for _ ∈ 1:n_non_elites]

    state.pop = new_pop
end
export new_population!

function optimize(opt::GeneticOpt, stop_conditions::StopConditions, actions_list::Vector{Symbol}, criteria::Criteria)::ItersState

    state = initial_po_state(opt, actions_list)

    update_state!(state, criteria)

    while !should_stop(stop_conditions, state.iters_state)
        new_population!(opt, state, actions_list)

        update_state!(state, criteria)
    end

    return state.iters_state
end
export optimize

end

