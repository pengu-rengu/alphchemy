module LogicActionsModule

using ..ActionsModule
using ..LogicNetModule

@kwdef struct LogicActions <: AbstractActions
    meta_actions::Dict{Symbol, Vector{Symbol}}
    min_thresholds::Vector{Float64}
    max_thresholds::Vector{Float64}
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

function logic_actions_list(actions::LogicActions)::Vector{Symbol}
    meta_keys = keys(actions.meta_actions)
    meta_keys = collect(meta_keys)

    list = vcat([:NEXT_FEATURE, :NEXT_THRESHOLD, :NEXT_NODE, :SELECT_NODE, :SET_IN1_IDX, :SET_IN2_IDX, :NEW_INPUT_NODE], meta_keys)

    if actions.allow_and
        push!(list, :NEW_AND_NODE)
    end

    if actions.allow_or
        push!(list, :NEW_OR_NODE)
    end
    
    if actions.allow_nand
        push!(list, :NEW_NAND_NODE)
    end

    if actions.allow_nor
        push!(list, :NEW_NOR_NODE)
    end

    if actions.allow_xor
        push!(list, :NEW_XOR_NODE)
    end

    if actions.allow_xnor
        push!(list, :NEW_XNOR_NODE)
    end
    
    return list
end
export logic_actions_list

function logic_action!(net::LogicNet, action::Symbol, state::ActionsState, actions::LogicActions)
    
    nodes = net.nodes
    
    meta_actions = actions.meta_actions
    new_node = nothing

    selected_idx = state.selected_idx
    node_idx = state.node_idx
    
    if haskey(meta_actions, action)
        for sub_action ∈ meta_actions[action]
            logic_action!(net, sub_action, state, actions)
        end
    elseif action == :NEXT_FEATURE
        n_features = length(actions.min_thresholds)

        state.feature_idx += 1

        if state.feature_idx > n_features
            state.feature_idx = 1
        end
    elseif action == :NEXT_THRESHOLD
        state.threshold_idx += 1

        if state.threshold_idx > actions.n_thresholds
            state.threshold_idx = 1
        end
    elseif action == :NEW_INPUT_NODE
        threshold = threshold_value(state, actions)

        new_node = InputNode(
            threshold = threshold,
            feature_idx = state.feature_idx
        )
    elseif action == :NEW_AND_NODE
        new_node = LogicNode(gate = :AND)
    elseif action == :NEW_OR_NODE
        new_node = LogicNode(gate = :OR)
    elseif action == :NEW_NAND_NODE
        new_node = LogicNode(gate = :NAND)
    elseif action == :NEW_NOR_NODE
        new_node = LogicNode(gate = :NOR)
    elseif action == :NEW_XOR_NODE
        new_node = LogicNode(gate = :XOR)
    elseif action == :NEW_XNOR_NODE
        new_node = LogicNode(gate = :XNOR)
    elseif !isempty(nodes)

        node = nodes[node_idx]

        is_feedforward = selected_idx < node_idx
        allow_connection = actions.allow_recurrence || is_feedforward

        if action == :NEXT_NODE
            nodes_len = length(nodes)

            state.node_idx += 1
            
            if state.node_idx > nodes_len
                state.node_idx = 1
            end
        elseif action == :SELECT_NODE
            state.selected_idx = node_idx
        elseif isa(node, LogicNode) && allow_connection
            if action == :SET_IN1_IDX
                node.in1_idx = selected_idx
            elseif action == :SET_IN2_IDX
                node.in2_idx = selected_idx
            end
        end
    end

    if !isnothing(new_node)
        push!(nodes, new_node)
    end
end
export logic_action!

end