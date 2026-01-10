module DecisionNetModule

using ..NetworkModule

@kwdef mutable struct BranchNode
    threshold::Float64
    feature_idx::Int
    true_idx::Int = -1
    false_idx::Int = -1
    value::Bool = false
end
export BranchNode

@kwdef mutable struct RefNode
    ref_idx::Int
    true_idx::Int = -1
    false_idx::Int = -1
    value::Bool = false
end
export RefNode

@kwdef struct DecisionNet <: AbstractNetwork
    nodes::Vector{Union{BranchNode, RefNode}}
    idx_trail::Vector{Int} = []
    default_value::Bool
    max_trail_len::Int
end
export DecisionNet

@kwdef struct DecisionPenalties <: AbstractPenalties
    node::Float64
    branch::Float64
    ref::Float64
    leaf::Float64
    non_leaf::Float64
    used_feature::Float64
    unused_feature::Float64
end
export DecisionPenalties

function eval_branch!(node::BranchNode, feat_mat::Matrix{Float64}, row::Int)
    node.value = feat_mat[row, node.feature_idx] > node.threshold
end
export eval_branch!

function eval_ref!(node::RefNode, net::DecisionNet)
    node.value = net.nodes[node.ref_idx].value
end
export eval_ref!

function update_idx!(net::DecisionNet, current_idx::Int)::Int
    node = net.nodes[current_idx]
    
    new_idx = node.value ? node.true_idx : node.false_idx
    if new_idx > 0
        push!(net.idx_trail, new_idx)
    end

    return new_idx
end
export update_idx!

function eval_decision_net!(net::DecisionNet, feat_matrix::Matrix{Float64}, row::Int)
    idx_trail = net.idx_trail

    empty!(idx_trail)
    push!(idx_trail, 1)

    idx = 1
    
    while idx > 0 && length(idx_trail) < net.max_trail_len
        node = net.nodes[idx]

        if isa(node, BranchNode)
            eval_branch!(node, feat_matrix, row)
        elseif isa(node, RefNode)
            eval_ref!(node, net)
        end

        idx = update_idx!(net, idx)
    end
end
export eval_decision_net!

function idx_trail_value(net::DecisionNet, idx::Int)::Bool
    idx_trail = net.idx_trail
    
    trail_len = length(idx_trail)
    if 1 <= idx <= trail_len
        return net.nodes[idx_trail[idx]].value
    end
    
    return net.default_value
end
export idx_trail_value

function decision_node_value(net::DecisionNet, pointer::NodePointer)::Bool
    trail_len = length(net.idx_trail)
    idx = idx_from_pointer(pointer, trail_len)

    return idx_trail_value(net, idx)
end
export decision_node_value

function nodes_penalty(net::DecisionNet, penalties::DecisionPenalties)::Float64
    nodes = net.nodes

    nodes_len = length(nodes)
    penalty = penalties.node * nodes_len

    for node ∈ nodes
        if isa(node, BranchNode)
            penalty += penalties.branch
        elseif isa(node, RefNode)
            penalty += penalties.ref
        end
    end

    return penalty
end
export nodes_penalty

function leaves_penalty(net::DecisionNet, penalties::DecisionPenalties)::Float64
    penalty = 0.0
    
    leaf_penalty = penalties.leaf
    non_leaf_penalty = penalties.non_leaf

    for node ∈ net.nodes
        if node.true_idx < 0
            penalty += leaf_penalty
        else
            penalty += non_leaf_penalty
        end

        if node.false_idx < 0
            penalty += leaf_penalty
        else
            penalty += non_leaf_penalty
        end
    end

    return penalty
end
export leaves_penalty

function features_penalty(net::DecisionNet, penalties::DecisionPenalties, n_features::Int)::Float64

    is_used = falses(n_features)

    for node = net.nodes
        if isa(node, BranchNode) && node.feature_idx > 0
            is_used[node.feature_idx] = true 
        end
    end

    n_used = sum(is_used)
    n_unused = n_features - n_used

    used_penalty = penalties.used_feature * n_used
    unused_penalty = penalties.unused_feature * n_unused

    return used_penalty + unused_penalty
end
export features_penalty

function decision_penalty(net::DecisionNet, penalties::DecisionPenalties, n_features::Int)::Float64
    penalty = 0.0

    if penalties.node + penalties.branch + penalties.ref > 0.0
        penalty += nodes_penalty(net, penalties)
    end

    if penalties.leaf + penalties.non_leaf > 0.0
        penalty += leaves_penalty(net, penalties)
    end

    if penalties.used_feature + penalties.unused_feature > 0.0
        penalty += features_penalty(net, penalties, n_features)
    end

    return penalty
end
export decision_penalty

end
