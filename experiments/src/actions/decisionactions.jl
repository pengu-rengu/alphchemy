module DecisionActionsModule

using ..ActionsModule
using ..DecisionNetModule

@kwdef struct DecisionActions <: AbstractActions
    meta_actions::Dict{Symbol, Vector{Symbol}}
    min_thresholds::Vector{Float64}
    max_thresholds::Vector{Float64}
    n_thresholds::Int
    allow_refs::Bool
    allow_cycles::Bool
end
export DecisionActions

function decision_actions_list(actions::DecisionActions)::Vector{Symbol}
    meta_keys = keys(actions.meta_actions)
    meta_keys = collect(meta_keys)

    list = vcat([:NEXT_FEATURE, :NEXT_THRESHOLD, :NEXT_NODE, :SELECT_NODE, :SET_TRUE_IDX, :SET_FALSE_IDX, :NEW_BRANCH_NODE], meta_keys)

    if actions.allow_refs
        push!(list, :NEW_REF_NODE)
    end

    return list
end
export decision_actions_list

function decision_action!(net::DecisionNet, action::Symbol, state::ActionsState, actions::DecisionActions)

    nodes = net.nodes
    meta_actions = actions.meta_actions

    node_idx = state.node_idx
    selected_idx = state.selected_idx

    if haskey(meta_actions, action)
        for sub_action = meta_actions[action]
            decision_action!(net, sub_action, state, actions)
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
    elseif action == :NEW_BRANCH_NODE
        threshold = threshold_value(state, actions)

        new_node = BranchNode(
            threshold = threshold,
            feature_idx = state.feature_idx
        )
        
        push!(nodes, new_node)
    elseif action == :NEW_REF_NODE
        new_node = RefNode(ref_idx = selected_idx)
        
        push!(nodes, new_node)
    elseif !isempty(nodes)

        node = nodes[node_idx]

        is_feedforward = selected_idx > node_idx

        if action == :NEXT_NODE
            state.node_idx += 1
            
            nodes_len = length(nodes)
            if state.node_idx > nodes_len
                state.node_idx = 1
            end
        elseif action == :SELECT_NODE
            state.selected_idx = node_idx
        elseif actions.allow_cycles || is_feedforward
            if action == :SET_TRUE_IDX
                node.true_idx = selected_idx
            elseif action == :SET_FALSE_IDX
                node.false_idx = selected_idx
            end
        end
    end
end
export decision_action!

end