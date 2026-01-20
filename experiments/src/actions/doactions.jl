module DoActionsModule

using ..NetworkModule
using ..ActionsModule

@kwdef mutable struct ActionsState
    feat_idx::Int = 1
    node_idx::Int = 1
    selected_idx::Int = 1
    threshold_idx::Int = 1
end
export ActionsState

function threshold_value(state::ActionsState, actions::AbstractActions)::Float64
    threshold_range = actions.thresholds[state.feat_idx]
    min_threshold = threshold_range.min

    range = threshold_range.max - min_threshold
    
    divisor = max(1, actions.n_thresholds - 1)
    stride = range / divisor
    offset = (state.threshold_idx - 1) * stride
    
    return min_threshold + offset
end
export threshold_value

function do_action!(net::LogicNet, action::Symbol, state::ActionsState, actions::LogicActions)
    
    nodes = net.nodes
    
    meta_actions = actions.meta_actions
    new_node = nothing
    
    if haskey(meta_actions, action)
        for sub_action ∈ meta_actions[action]
            do_action!(net, sub_action, state, actions)
        end
    elseif action == :NEXT_FEAT
        n_feats = length(actions.thresholds)

        state.feat_idx += 1

        if state.feat_idx > n_feats
            state.feat_idx = 1
        end
    elseif action == :NEXT_THRESHOLD
        state.threshold_idx += 1

        if state.threshold_idx > actions.n_thresholds
            state.threshold_idx = 1
        end
    elseif action == :NEW_INPUT
        threshold = threshold_value(state, actions)

        new_node = InputNode(threshold = threshold)
    elseif action == :NEW_AND
        new_node = LogicNode(gate = :AND)
    elseif action == :NEW_OR
        new_node = LogicNode(gate = :OR)
    elseif action == :NEW_NAND
        new_node = LogicNode(gate = :NAND)
    elseif action == :NEW_NOR
        new_node = LogicNode(gate = :NOR)
    elseif action == :NEW_XOR
        new_node = LogicNode(gate = :XOR)
    elseif action == :NEW_XNOR
        new_node = LogicNode(gate = :XNOR)
    elseif !isempty(nodes)

        selected_idx = state.selected_idx
        node_idx = state.node_idx

        node = nodes[node_idx]

        is_feedforward = selected_idx < node_idx
        allow_connection = actions.allow_recurrence || is_feedforward

        is_input = isa(node, InputNode)
        is_logic = isa(node, LogicNode)

        if action == :NEXT_NODE
            nodes_len = length(nodes)

            state.node_idx += 1
            
            if state.node_idx > nodes_len
                state.node_idx = 1
            end
        elseif action == :SELECT_NODE
            state.selected_idx = node_idx
        elseif is_input && action == :SET_FEAT_IDX
            node.feat_idx = state.feat_idx
        elseif is_logic && allow_connection
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

function do_action!(net::DecisionNet, action::Symbol, state::ActionsState, actions::DecisionActions)

    nodes = net.nodes
    meta_actions = actions.meta_actions

    node_idx = state.node_idx
    selected_idx = state.selected_idx

    if haskey(meta_actions, action)
        for sub_action ∈ meta_actions[action]
            do_action!(net, sub_action, state, actions)
        end
    elseif action == :NEXT_FEAT
        n_feats = length(actions.thresholds)
        
        state.feat_idx += 1
        if state.feat_idx > n_feats
            state.feat_idx = 1
        end
    elseif action == :NEXT_THRESHOLD
        state.threshold_idx += 1

        if state.threshold_idx > actions.n_thresholds
            state.threshold_idx = 1
        end
    elseif action == :NEW_BRANCH
        threshold = threshold_value(state, actions)

        new_node = BranchNode(
            threshold = threshold,
            feat_idx = state.feat_idx
        )
        
        push!(nodes, new_node)
    elseif action == :NEW_REF
        new_node = RefNode()
        
        push!(nodes, new_node)
    elseif !isempty(nodes)

        node = nodes[node_idx]

        is_feedforward = selected_idx > node_idx

        is_branch = isa(node, BranchNode)
        is_ref = isa(node, RefNode)

        if action == :NEXT_NODE
            state.node_idx += 1
            
            nodes_len = length(nodes)
            if state.node_idx > nodes_len
                state.node_idx = 1
            end
        elseif action == :SELECT_NODE
            state.selected_idx = node_idx
        elseif is_branch && action == :SET_FEAT_IDX
            node.feat_idx = state.feat_idx
        elseif is_ref && action == :SET_REF_IDX
            node.ref_idx = state.selected_idx
        elseif actions.allow_cycles || is_feedforward
            if action == :SET_TRUE_IDX
                node.true_idx = selected_idx
            elseif action == :SET_FALSE_IDX
                node.false_idx = selected_idx
            end
        end
    end
end

export do_action!

function construct_net(base_net::AbstractNetwork, seq::Vector{Symbol}, actions::AbstractActions)::AbstractNetwork
    net = deepcopy(base_net)
    state = ActionsState()
    
    for action ∈ seq
        do_action!(net, action, state, actions)
    end
    
    return net
end
export construct_net

end