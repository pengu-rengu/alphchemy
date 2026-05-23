use crate::network::network::{NodePtr, Anchor};
use crate::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode};

use super::net_to_ps::{NetEmit, NetToPs, bool_literal, threshold_expr};
use super::features_to_ps::feat_var;

fn idx_or_neg(idx: Option<usize>) -> String {
    match idx {
        None => "-1".to_string(),
        Some(value) => value.to_string()
    }
}

fn branch_node_expr(branch: &BranchNode, delay: usize) -> Result<String, String> {
    let feat_id = branch.feat_id.as_ref();
    let threshold = branch.threshold;
    match (feat_id, threshold) {
        (Some(feat_id), Some(threshold)) => {
            let var = feat_var(feat_id)?;
            Ok(threshold_expr(&var, threshold, delay))
        }
        _ => Ok("default_value".to_string())
    }
}

fn ref_node_expr(ref_node: &RefNode) -> String {
    match ref_node.ref_idx {
        None => "default_value".to_string(),
        Some(ref_idx) => format!("array.get(node_vals, {ref_idx})")
    }
}

fn decision_node_expr(node: &DecisionNode, delay: usize) -> Result<(String, Option<usize>, Option<usize>), String> {
    match node {
        DecisionNode::Branch(branch) => {
            let expr = branch_node_expr(branch, delay)?;
            Ok((expr, branch.true_idx, branch.false_idx))
        }
        DecisionNode::Ref(ref_node) => {
            let expr = ref_node_expr(ref_node);
            Ok((expr, ref_node.true_idx, ref_node.false_idx))
        }
    }
}

impl NetToPs for DecisionNet {
    fn emit(&self, delay: usize) -> Result<NetEmit, String> {
        if self.nodes.is_empty() {
            return Err("decision net has no nodes".to_string());
        }

        let default_literal = bool_literal(self.default_value);
        let max_trail_len = self.max_trail_len;

        let mut declarations = Vec::new();
        declarations.push(format!("bool default_value = {default_literal}"));
        declarations.push(format!("var array<bool> node_vals = array.new<bool>({0}, default_value)", self.nodes.len()));
        declarations.push("var array<int> trail = array.new<int>()".to_string());

        let mut per_bar = Vec::new();
        per_bar.push("array.clear(trail)".to_string());
        per_bar.push("array.push(trail, 0)".to_string());
        per_bar.push("int current_idx = 0".to_string());
        per_bar.push("bool keep_iterating = true".to_string());
        let max_iter = max_trail_len - 1;
        per_bar.push(format!("for step = 0 to {max_iter}"));
        per_bar.push("    if not keep_iterating".to_string());
        per_bar.push("        break".to_string());
        per_bar.push(format!("    if array.size(trail) >= {max_trail_len}"));
        per_bar.push("        break".to_string());
        per_bar.push("    bool new_val = default_value".to_string());
        per_bar.push("    int next_idx = -1".to_string());

        for (idx, node) in self.nodes.iter().enumerate() {
            let branch_keyword = if idx == 0 {
                "if"
            } else {
                "else if"
            };
            per_bar.push(format!("    {branch_keyword} current_idx == {idx}"));

            let (eval_expr, true_idx, false_idx) = decision_node_expr(node, delay)?;

            per_bar.push(format!("        new_val := {eval_expr}"));
            let true_str = idx_or_neg(true_idx);
            let false_str = idx_or_neg(false_idx);
            per_bar.push(format!("        next_idx := new_val ? {true_str} : {false_str}"));
        }

        per_bar.push("    array.set(node_vals, current_idx, new_val)".to_string());
        per_bar.push("    if next_idx < 0".to_string());
        per_bar.push("        keep_iterating := false".to_string());
        per_bar.push("    else".to_string());
        per_bar.push("        array.push(trail, next_idx)".to_string());
        per_bar.push("        current_idx := next_idx".to_string());

        Ok(NetEmit {
            declarations,
            per_bar
        })
    }

    fn node_value_expr(&self, node_ptr: &NodePtr) -> String {
        let idx = node_ptr.idx;
        match node_ptr.anchor {
            Anchor::FromStart => {
                format!("(array.size(trail) > {idx} ? array.get(node_vals, array.get(trail, {idx})) : default_value)")
            }
            Anchor::FromEnd => {
                format!("(array.size(trail) > {idx} ? array.get(node_vals, array.get(trail, array.size(trail) - {idx} - 1)) : default_value)")
            }
        }
    }
}
