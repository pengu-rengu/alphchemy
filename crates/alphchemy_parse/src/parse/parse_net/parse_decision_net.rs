use alphchemy_engine::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode, DecisionPenalties};
use crate::utils::expect_non_neg;
use super::super::parse::Fields;
use super::parse_net::{feat_id_set, validate_idx, indexed_nodes};

const MAX_TRAIL_LEN: usize = 25;

fn parse_decision_node(fields: &Fields) -> Result<DecisionNode, String> {
    let node_type = fields.string(&["type"], "")?;

    match node_type.as_str() {
        "branch" => {
            let threshold = fields.option_f64(&["threshold", "thresh"])?;
            let feat_id = fields.option_string(&["feat_id", "feature_id"])?;
            let true_idx = fields.option_usize(&["true_idx", "true_index"])?;
            let false_idx = fields.option_usize(&["false_idx", "false_index"])?;
            let node = BranchNode { threshold, feat_id, true_idx, false_idx, value: false };
            Ok(DecisionNode::Branch(node))
        }
        "ref" => {
            let ref_idx = fields.option_usize(&["ref_idx", "ref_index", "reference_idx", "reference_index"])?;
            let true_idx = fields.option_usize(&["true_idx", "true_index"])?;
            let false_idx = fields.option_usize(&["false_idx", "false-idx", "false_index"])?;
            let node = RefNode { ref_idx, true_idx, false_idx, value: false };
            Ok(DecisionNode::Ref(node))
        }
        _ => Err(format!("invalid decision node type: {node_type}"))
    }
}

pub fn parse_decision_net(fields: Option<Fields>, feat_ids: &[String]) -> Result<DecisionNet, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let default_value = fields.bool(&["default_value", "default-value", "default"], false)?;
    let max_trail_len = fields.usize(&["max_trail_len", "max-trail-len", "max_trail_length", "max-trail-length"], 8)?;
    let node_fields = fields.child_fields(&["nodes", "decision_nodes"])?;
    let nodes = indexed_nodes(node_fields, parse_decision_node)?;

    if max_trail_len == 0 {
        return Err("max_trail_len must be > 0".to_string());
    }
    if max_trail_len > MAX_TRAIL_LEN {
        return Err(format!("max_trail_len must be <= {MAX_TRAIL_LEN}"));
    }

    let ids = feat_id_set(feat_ids);
    let n_nodes = nodes.len();
    for node in &nodes {
        match node {
            DecisionNode::Branch(branch) => {
                if let Some(feat_id) = branch.feat_id.as_ref() && !ids.contains(feat_id.as_str()) {
                    return Err(format!("feat_id not found: {feat_id}"));
                }
                validate_idx(branch.true_idx, n_nodes, "true_idx")?;
                validate_idx(branch.false_idx, n_nodes, "false_idx")?;
            }
            DecisionNode::Ref(ref_node) => {
                validate_idx(ref_node.ref_idx, n_nodes, "ref_idx")?;
                validate_idx(ref_node.true_idx, n_nodes, "true_idx")?;
                validate_idx(ref_node.false_idx, n_nodes, "false_idx")?;
            }
        }
    }

    let net = DecisionNet { nodes, max_trail_len, default_value, idx_trail: Vec::new() };
    Ok(net)
}

pub fn parse_decision_penalties(fields: Option<Fields>) -> Result<DecisionPenalties, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let node = fields.f64(&["node", "node_penalty", "node-penalty"], 0.0)?;
    let branch = fields.f64(&["branch", "branch_penalty", "branch-penalty"], 0.0)?;
    let ref_ = fields.f64(&["ref", "ref_penalty", "ref-penalty", "reference", "reference_penalty", "reference-penalty"], 0.0)?;
    let leaf = fields.f64(&["leaf"], 0.0)?;
    let non_leaf = fields.f64(&["non_leaf"], 0.0)?;
    let used_feat = fields.f64(&["used_feat"], 0.0)?;
    let unused_feat = fields.f64(&["unused_feat"], 0.0)?;

    expect_non_neg(node, "node")?;
    expect_non_neg(branch, "branch")?;
    expect_non_neg(ref_, "ref")?;
    expect_non_neg(leaf, "leaf")?;
    expect_non_neg(non_leaf, "non_leaf")?;
    expect_non_neg(used_feat, "used_feat")?;
    expect_non_neg(unused_feat, "unused_feat")?;

    let penalties = DecisionPenalties {
        node, branch, ref_, leaf, non_leaf, used_feat, unused_feat
    };
    Ok(penalties)
}
