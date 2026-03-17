module PenaltiesModule

using ..NetworkModule

abstract type AbstractPenalties end
export AbstractPenalties

@kwdef struct LogicPenalties <: AbstractPenalties
    node::Float64
    input::Float64
    logic::Float64
    recurrence::Float64
    feedforward::Float64
    used_feat::Float64
    unused_feat::Float64
end
export LogicPenalties

@kwdef struct DecisionPenalties <: AbstractPenalties
    node::Float64
    branch::Float64
    ref::Float64
    leaf::Float64
    non_leaf::Float64
    used_feat::Float64
    unused_feat::Float64
end
export DecisionPenalties

function nodes_penalty(net::LogicNet, penalties::LogicPenalties)::Float64
    penalty = 0.0

    for node ∈ net.nodes
        penalty += penalties.node

        if isa(node, InputNode)
            penalty += penalties.input
        elseif isa(node, LogicNode)
            penalty += penalties.logic
        end
    end

    return penalty
end

function nodes_penalty(net::DecisionNet, penalties::DecisionPenalties)::Float64
    penalty = 0.0

    for node ∈ net.nodes
        penalty += penalties.node

        if isa(node, BranchNode)
            penalty += penalties.branch
        elseif isa(node, RefNode)
            penalty += penalties.ref
        end
    end

    return penalty
end

export nodes_penalty

function feats_penalty(net::AbstractNetwork, penalties::AbstractPenalties, n_feats::Int)::Float64
    is_used = falses(n_feats)

    for node ∈ net.nodes
        if isa(node, Union{InputNode, BranchNode})
            feat_idx = node.feat_idx

            if feat_idx > 0
                is_used[feat_idx] = true
            end
        end
    end

    n_used = sum(is_used)
    n_unused = n_feats - n_used

    used_penalty = penalties.used_feat * n_used
    unused_penalty = penalties.unused_feat * n_unused

    return used_penalty + unused_penalty
end
export feats_penalty

function direction_penalty(in_idx::Int, idx::Int, penalties::LogicPenalties)::Float64
    if in_idx > 0
        if in_idx ≥ idx
            return penalties.recurrence
        else
            return penalties.feedforward
        end
    end

    return 0.0
end
export direction_penalty

function directions_penalty(net::LogicNet, penalties::LogicPenalties)::Float64
    nodes = net.nodes
    penalty = 0.0

    for i ∈ eachindex(nodes)

        node = nodes[i]
        
        if !isa(node, LogicNode)
            continue
        end
        
        penalty += direction_penalty(node.in1_idx, i, penalties)
        penalty += direction_penalty(node.in2_idx, i, penalties)
    end

    return penalty
end
export directions_penalty

function leaf_penalty(out_idx::Int, penalties::DecisionPenalties)::Float64
    return out_idx < 0 ? penalties.leaf : penalties.non_leaf
end
export leaf_penalty

function leaves_penalty(net::DecisionNet, penalties::DecisionPenalties)::Float64
    penalty = 0.0

    for node ∈ net.nodes
        penalty += leaf_penalty(node.true_idx, penalties)
        penalty += leaf_penalty(node.false_idx, penalties)
    end
    
    return penalty
end
export leaves_penalty

function get_penalty(net::LogicNet, penalties::LogicPenalties, n_feats::Int)::Float64
    penalty = 0.0

    if penalties.node + penalties.input + penalties.logic > 0.0
        penalty += nodes_penalty(net, penalties)
    end

    if penalties.recurrence + penalties.feedforward > 0.0
        penalty += directions_penalty(net, penalties)
    end
    
    if penalties.used_feat + penalties.unused_feat > 0.0
        penalty += feats_penalty(net, penalties, n_feats)
    end
    
    return penalty
end

function get_penalty(net::DecisionNet, penalties::DecisionPenalties, n_feats::Int)::Float64
    penalty = 0.0

    if penalties.node + penalties.branch + penalties.ref > 0.0
        penalty += nodes_penalty(net, penalties)
    end

    if penalties.leaf + penalties.non_leaf > 0.0
        penalty += leaves_penalty(net, penalties)
    end

    if penalties.used_feat + penalties.unused_feat > 0.0
        penalty += feats_penalty(net, penalties, n_feats)
    end

    return penalty
end
export get_penalty

end