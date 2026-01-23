module NetworkUtilsModule 

using ..TestUtilsModule
using ..NetworkModule
using Supposition

const MAX_NODES = 10
const MAX_FEATS = 10

bool_gen = Data.Booleans()

feat_idx_gen = Data.Integers(1, MAX_FEATS)
node_idx_gen = Data.Integers(1, MAX_NODES)

is_in_gen = Data.Vectors(bool_gen, max_size = MAX_NODES)
gate_gen = Data.SampledFrom([:AND, :OR, :XOR, :NAND, :NOR, :XNOR])

input_node_gen = @composed (
   threshold = float_gen,
   feat_idx = feat_idx_gen,
   value = bool_gen 
) -> InputNode(
    threshold = threshold,
    feat_idx = feat_idx,
    value = value
)
export input_node_gen

gate_node_gen = @composed (
    in1_idx = node_idx_gen,
    in2_idx = node_idx_gen,
    in1_unset = bool_gen,
    in2_unset = bool_gen,
    gate = gate_gen,
    value = bool_gen
) -> LogicNode(
    gate = gate,
    in1_idx = in1_unset ? -1 : in1_idx,
    in2_idx = in2_unset ? -1 : in2_idx,
    value = value
)
export gate_node_gen

logic_node_gen = @composed (
    is_input = bool_gen,
    input_node = input_node_gen,
    gate_node = gate_node_gen
) -> is_input ? input_node : gate_node
export logic_node_gen

logic_nodes_gen = Data.Vectors(logic_node_gen, min_size = 1, max_size = MAX_NODES)
export logic_nodes_gen

logic_net_gen = @composed (
    nodes = logic_nodes_gen,
    default_value = bool_gen
) -> begin
    nodes_len = length(nodes)
    valid_indices = true

    for node ∈ nodes
        if isa(node, LogicNode)
            in1_invalid = node.in1_idx > nodes_len
            in2_invalid = node.in2_idx > nodes_len

            if in1_invalid || in2_invalid
                valid_indices = false
            end
        end
    end

    assume!(valid_indices)

    return LogicNet(
        nodes = nodes,
        default_value = default_value
    )
end
export logic_net_gen

branch_node_gen = @composed (
    threshold = float_gen,
    feat_idx = feat_idx_gen,
    true_idx = node_idx_gen,
    false_idx = node_idx_gen,
    value = bool_gen
) -> BranchNode(
    threshold = threshold,
    feat_idx = feat_idx,
    true_idx = true_idx,
    false_idx = false_idx,
    value = value
)
export branch_node_gen

ref_node_gen = @composed (
    ref_idx = node_idx_gen,
    true_idx = node_idx_gen,
    false_idx = node_idx_gen,
    value = bool_gen
) -> RefNode(
    ref_idx = ref_idx,
    true_idx = true_idx,
    false_idx = false_idx,
    value = value
)
export ref_node_gen

decision_node_gen = @composed (
    is_branch = bool_gen,
    branch_node = branch_node_gen,
    ref_node = ref_node_gen
) -> is_branch ? branch_node : ref_node
export decision_node_gen

decision_nodes_gen = Data.Vectors(decision_node_gen, min_size = 1, max_size = MAX_NODES)
export decision_nodes_gen



end