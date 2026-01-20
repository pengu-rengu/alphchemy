module ActionsModule

abstract type AbstractActions end
export AbstractActions

@kwdef struct ThresholdRange
    min::Float64
    max::Float64
end
export ThresholdRange

@kwdef struct LogicActions <: AbstractActions
    meta_actions::Dict{Symbol, Vector{Symbol}}
    thresholds::Vector{ThresholdRange}
    n_thresholds::Int
    allow_recurrence::Bool
    allow_and::Bool
    allow_or::Bool
    allow_nand::Bool
    allow_nor::Bool
    allow_xor::Bool
    allow_xnor::Bool
end
export LogicActions

@kwdef struct DecisionActions <: AbstractActions
    meta_actions::Dict{Symbol, Vector{Symbol}}
    thresholds::Vector{ThresholdRange}
    n_thresholds::Int
    allow_refs::Bool
    allow_cycles::Bool
end
export DecisionActions

function get_meta_actions(actions::AbstractActions)::Vector{Symbol}
    meta_keys = keys(actions.meta_actions)
    meta_keys = collect(meta_keys)
    return sort(meta_keys)
end
export get_meta_actions

function actions_list(actions::LogicActions)::Vector{Symbol}
    meta_actions = get_meta_actions(actions)

    list = vcat([:NEXT_FEAT, :NEXT_THRESHOLD, :NEXT_NODE, :SELECT_NODE, :SET_FEAT_IDX, :SET_IN1_IDX, :SET_IN2_IDX, :NEW_INPUT], meta_actions)

    if actions.allow_and
        push!(list, :NEW_AND)
    end

    if actions.allow_or
        push!(list, :NEW_OR)
    end
    
    if actions.allow_nand
        push!(list, :NEW_NAND)
    end

    if actions.allow_nor
        push!(list, :NEW_NOR)
    end

    if actions.allow_xor
        push!(list, :NEW_XOR)
    end

    if actions.allow_xnor
        push!(list, :NEW_XNOR)
    end
    
    return list
end

function actions_list(actions::DecisionActions)::Vector{Symbol}
    meta_actions = get_meta_actions(actions)

    list = vcat([:NEXT_FEAT, :NEXT_THRESHOLD, :NEXT_NODE, :SELECT_NODE, :SET_FEAT_IDX, :SET_REF_IDX, :SET_TRUE_IDX, :SET_FALSE_IDX, :NEW_BRANCH], meta_actions)

    if actions.allow_refs
        push!(list, :NEW_REF)
    end
    
    return list
end

export actions_list

end