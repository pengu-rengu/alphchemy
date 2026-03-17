module NetworkModule

abstract type AbstractNetwork end
export AbstractNetwork

@kwdef mutable struct InputNode
    threshold::Float64
    feat_idx::Int = -1
    value::Bool = false
end
export InputNode

@kwdef mutable struct LogicNode
    gate::Symbol
    in1_idx::Int = -1
    in2_idx::Int = -1
    value::Bool = false
end
export LogicNode

@kwdef struct LogicNet <: AbstractNetwork
    nodes::Vector{Union{InputNode, LogicNode}}
    default_value::Bool
end
export LogicNet

@kwdef mutable struct BranchNode
    threshold::Float64
    feat_idx::Int = -1
    true_idx::Int = -1
    false_idx::Int = -1
    value::Bool = false
end
export BranchNode

@kwdef mutable struct RefNode
    ref_idx::Int = -1
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

@kwdef struct NodePtr
    anchor::Symbol
    idx::Int
end
export NodePtr

function idx_from_ptr(ptr::NodePtr, len::Int)::Int
    anchor = ptr.anchor
    idx = ptr.idx

    if anchor == :from_start
        return idx
    elseif anchor == :from_end
        return len - idx + 1
    end
end
export idx_from_ptr

function idx_trail_value(net::DecisionNet, idx::Int)::Bool
    idx_trail = net.idx_trail
    
    trail_len = length(idx_trail)
    if 1 ≤ idx ≤ trail_len
        return net.nodes[idx_trail[idx]].value
    end
    
    return net.default_value
end
export idx_trail_value

function node_value(net::LogicNet, pointer::NodePtr)::Bool
    nodes_len = length(net.nodes)
    
    idx = idx_from_ptr(pointer, nodes_len)

    if 1 ≤ idx ≤ nodes_len
        return net.nodes[idx].value
    end
    
    return net.default_value
end

function node_value(net::DecisionNet, pointer::NodePtr)::Bool
    trail_len = length(net.idx_trail)
    idx = idx_from_ptr(pointer, trail_len)

    return idx_trail_value(net, idx)
end

export node_value

function reset_state!(network::AbstractNetwork)
    for node ∈ network.nodes
        node.value = network.default_value
    end
end
export reset_state!

end