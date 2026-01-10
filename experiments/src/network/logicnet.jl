module LogicNetModule

using ..NetworkModule

@kwdef mutable struct InputNode
    threshold::Float64
    feature_idx::Int
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

@kwdef struct LogicPenalties <: AbstractPenalties
    node::Float64
    input::Float64
    logic::Float64
    recurrence::Float64
    feedforward::Float64
    used_feature::Float64
    unused_feature::Float64
end
export LogicPenalties

function eval_input!(node::InputNode, feat_mat::Matrix{Float64}, row::Int)
    node.value = feat_mat[row, node.feature_idx] > node.threshold
end
export eval_input!

function eval_logic!(node::LogicNode, net::LogicNet)
    nodes = net.nodes

    gate = node.gate
    in1_idx = node.in1_idx
    in2_idx = node.in2_idx

    if in1_idx < 0
        value1 = net.default_value
    else
        value1 = nodes[node.in1_idx].value
    end
    
    if in2_idx < 0
        value2 = net.default_value
    else
        value2 = nodes[node.in2_idx].value
    end

    if gate == :AND
        result = value1 && value2
    elseif gate == :OR
        result = value1 || value2
    elseif gate == :XOR
        result = xor(value1, value2)
    elseif gate == :NAND
        result = !(value1 && value2)
    elseif gate == :NOR
        result = !(value1 || value2)
    elseif gate == :XNOR
        result = !xor(value1, value2)
    end

    node.value = result
end
export eval_logic!

function eval_logic_net!(net::LogicNet, features_matrix::Matrix{Float64}, row::Int)
    for node ∈ net.nodes
        if isa(node, InputNode)
            eval_input!(node, features_matrix, row)
        elseif isa(node, LogicNode)
            eval_logic!(node, net)
        end
    end
end
export eval_logic_net!

function logic_node_value(net::LogicNet, pointer::NodePointer)::Bool
    nodes_len = length(net.nodes)
    
    idx = idx_from_pointer(pointer, nodes_len)

    if 1 ≤ idx ≤ nodes_len
        return net.nodes[idx].value
    end
    
    return net.default_value
end
export logic_node_value

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
export nodes_penalty

function directions_penalty(net::LogicNet, penalties::LogicPenalties)::Float64
    nodes = net.nodes
    
    penalty = 0.0

    recurrence_penalty = penalties.recurrence
    feedforward_penalty = penalties.feedforward

    node_indices = eachindex(nodes)
    for i ∈ node_indices

        node = nodes[i]
        
        if !isa(node, LogicNode)
            continue
        end
        
        in1_idx = node.in1_idx
        in2_idx = node.in2_idx


        if in1_idx > 0
            if in1_idx ≥ i
                penalty += recurrence_penalty
            else
                penalty += feedforward_penalty
            end
        end

        if in2_idx > 0
            if in2_idx ≥ i
                penalty += recurrence_penalty
            else
                penalty += feedforward_penalty
            end
        end
    end

    return penalty
end
export directions_penalty

function features_penalty(net::LogicNet, penalties::LogicPenalties, n_features::Int)::Float64

    is_used = falses(n_features)

    for node ∈ net.nodes
        if isa(node, InputNode)
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

function logic_penalty(net::LogicNet, penalties::LogicPenalties, n_features::Int)::Float64
    penalty = 0.0

    if penalties.node + penalties.input + penalties.logic > 0.0
        penalty += nodes_penalty(net, penalties)
    end

    if penalties.recurrence + penalties.feedforward > 0.0
        penalty += directions_penalty(net, penalties)
    end
    
    if penalties.used_feature + penalties.unused_feature > 0.0
        penalty += features_penalty(net, penalties, n_features)
    end

    return penalty
end
export logic_penalty

end