module EvaluateModule

using ..NetworkModule

function eval_input!(node::InputNode, net::LogicNet, feat_mat::Matrix{Float64}, row::Int)
    feat_idx = node.feat_idx
    
    if feat_idx < 0
        node.value = net.default_value
        return
    end

    node.value = feat_mat[row, feat_idx] > node.threshold
end
export eval_input!

function input_value(in_idx::Int, net::LogicNet)::Bool
    if in_idx < 0
        return net.default_value
    end

    return net.nodes[in_idx].value
end
export input_value

function eval_logic!(node::LogicNode, net::LogicNet)
    gate = node.gate

    value1 = input_value(node.in1_idx, net)
    value2 = input_value(node.in2_idx, net)

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

function eval_branch!(node::BranchNode, net::DecisionNet, feat_matrix::Matrix{Float64}, row::Int)
    feat_idx = node.feat_idx

    if feat_idx < 0
        node.value = net.default_value
        return
    end

    node.value = feat_matrix[row, feat_idx] > node.threshold
end
export eval_branch!

function eval_ref!(node::RefNode, net::DecisionNet)
    ref_idx = node.ref_idx

    if ref_idx < 0
        node.value = net.default_value
        return
    end

    node.value = net.nodes[ref_idx].value
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

function eval!(net::LogicNet, feat_matrix::Matrix{Float64}, row::Int)
    for node ∈ net.nodes
        if isa(node, InputNode)
            eval_input!(node, net, feat_matrix, row)
        elseif isa(node, LogicNode)
            eval_logic!(node, net)
        end
    end
end

function eval!(net::DecisionNet, feat_matrix::Matrix{Float64}, row::Int)
    nodes = net.nodes
    idx_trail = net.idx_trail

    if isempty(nodes)
        return
    end

    empty!(idx_trail)
    push!(idx_trail, 1)
    
    idx = 1
    
    while idx > 0 && length(idx_trail) < net.max_trail_len
        node = nodes[idx]

        if isa(node, BranchNode)
            eval_branch!(node, net, feat_matrix, row)
        elseif isa(node, RefNode)
            eval_ref!(node, net)
        end

        idx = update_idx!(net, idx)
    end
end

export eval!

end