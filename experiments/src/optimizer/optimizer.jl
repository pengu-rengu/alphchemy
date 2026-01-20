module OptimizerModule

abstract type AbstractOptimizer end
export AbstractOptimizer

abstract type PopulationOpt <: AbstractOptimizer end
export PopulationOpt

abstract type SingleOpt <: AbstractOptimizer end
export SingleOpt

@kwdef struct Improvement
    iter::Int
    score::Float64
end
export Improvement

@kwdef mutable struct ItersState
    iters::Int = 0
    train_improvements::Vector{Improvement} = []
    val_improvements::Vector{Improvement} = []

    best_seq::Vector{Symbol} = []
    best_train_score::Float64 = -Inf
    best_val_score::Float64 = -Inf
end
export ItersState

@kwdef mutable struct POState
    pop::Vector{Vector{Symbol}}
    scores::Vector{Float64}

    iters_state::ItersState
end
export POState

@kwdef mutable struct SOState
    current_seq::Vector{Symbol}
    score::Float64

    iters_state::ItersState
end
export SOState

@kwdef struct Scores
    train::Float64
    val::Float64

    best_idx::Int
end
export Scores

@kwdef struct StopConds
    max_iters::Int
    train_patience::Int
    val_patience::Int
end
export StopConds

@kwdef struct Criteria
    train::Function
    val::Function
end
export Criteria

function initial_po_state(opt::PopulationOpt, actions_list::Vector{Symbol})::POState
    pop_size = opt.pop_size

    return POState(
        pop = [[rand(actions_list) for __ ∈ 1:opt.seq_len] for _ ∈ 1:pop_size],
        scores = zeros(pop_size),
        iters_state = ItersState()
    )
end
export initial_po_state

function mutate!(opt::AbstractOptimizer, actions_list::Vector{Symbol}, seq::Vector{Symbol};
    should_mutate = (_, mut_rate) -> rand() < mut_rate,
    sample_action = (actions) -> rand(actions)
)
    for i ∈ eachindex(seq)
        if should_mutate(i, opt.mut_rate)
            seq[i] = sample_action(actions_list)
        end
    end
end
export mutate!

function should_stop(stop_conds::StopConds, state::ItersState)::Bool
    iters = state.iters

    if iters > stop_conds.max_iters
        return true
    end

    iters_since_improve = iters - state.train_improvements[end].iter
    if iters_since_improve > stop_conds.train_patience
        return true
    end

    iters_since_improve = iters - state.val_improvements[end].iter
    if iters_since_improve > stop_conds.val_patience
        return true
    end
    
    return false
end
export should_stop

function update_scores!(state::POState, criteria::Criteria)::Scores
    pop = state.pop
    
    state.scores = [criteria.train(seq) for seq ∈ pop]

    train_score, best_idx = findmax(state.scores)
    val_score = criteria.val(pop[best_idx])

    return Scores(
        train = train_score,
        val = val_score,
        best_idx = best_idx
    )
end
export update_scores!

function update_train_improvements!(state::ItersState, train_score::Float64)
    push!(state.train_improvements, Improvement(
        iter = state.iters,
        score = train_score
    ))

    state.best_train_score = train_score
end
export update_train_improvements!

function update_val_improvements!(state::ItersState, val_score::Float64)
    push!(state.val_improvements, Improvement(
        iter = state.iters,
        score = val_score
    ))

    state.best_val_score = val_score
end
export update_val_improvements!

function update_state!(state::POState, criteria::Criteria)
    iters_state = state.iters_state
    iters_state.iters += 1

    scores = update_scores!(state, criteria)
    
    train_score = scores.train
    val_score = scores.val

    if train_score > iters_state.best_train_score
        update_train_improvements!(iters_state, train_score) 
    end

    if val_score > iters_state.best_val_score
        update_val_improvements!(iters_state, val_score)
        iters_state.best_seq = copy(state.pop[scores.best_idx])
    end
end
export update_state!

end