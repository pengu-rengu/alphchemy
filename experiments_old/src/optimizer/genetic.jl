module GeneticModule

using ..OptimizerModule
using StatsBase

@kwdef struct GeneticOpt <: PopulationOpt
    pop_size::Int
    seq_len::Int
    
    n_elites::Int

    mut_rate::Float64
    cross_rate::Float64
    tourn_size::Int
end
export GeneticOpt

function select(opt::GeneticOpt, state::POState;
    tourn_indices = (pop_size, tourn_size) -> sample(1:pop_size, tourn_size, replace = false)
)::Vector{Symbol}

    tournament = tourn_indices(opt.pop_size, opt.tourn_size)
    best_idx = argmax(idx -> state.scores[idx], tournament)
    
    return state.pop[best_idx]
end
export select

function crossover(opt::GeneticOpt, parent1::Vector{Symbol}, parent2::Vector{Symbol};
    cross_chance = rand,
    cross_idx = (seq_len) -> rand(1:(seq_len - 1)),
    parent_order = () -> rand(Bool)
)::Vector{Symbol}

    if cross_chance() < opt.cross_rate
        split = cross_idx(opt.seq_len)

        if parent_order()
            return vcat((@view parent1[1:split]), (@view parent2[split + 1:end]))
        end
        
        return vcat((@view parent2[1:split]), (@view parent1[split + 1:end]))
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

function new_pop!(opt::GeneticOpt, state::POState, actions_list::Vector{Symbol})
    n_elites = opt.n_elites
    pop_size = opt.pop_size

    n_non_elites = pop_size - n_elites

    new_pop = Vector{Vector{Symbol}}(undef, pop_size)
    new_pop[1:n_elites] .= get_elites(opt, state)
    new_pop[n_elites + 1:end] .= [new_child(opt, state, actions_list) for _ ∈ 1:n_non_elites]

    state.pop = new_pop
end
export new_pop!

function run_genetic(opt::GeneticOpt, stop_conds::StopConds, actions_list::Vector{Symbol}, criteria::Criteria)::ItersState

    state = initial_po_state(opt, actions_list)

    update_state!(state, criteria)

    while !should_stop(stop_conds, state.iters_state)
        new_pop!(opt, state, actions_list)

        update_state!(state, criteria)
    end

    return state.iters_state
end
export run_genetic

end

