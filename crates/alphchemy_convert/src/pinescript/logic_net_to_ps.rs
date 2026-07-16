use alphchemy_engine::network::network::NodePtr;
use alphchemy_engine::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate};

use super::net_to_ps::{NetEmit, NetToPs, bool_literal, threshold_expr};
use super::features_to_ps::feat_var;

fn node_var(idx: usize) -> String {
    format!("n{idx}")
}

fn prev_var(idx: usize) -> String {
    format!("prev_n{idx}")
}

fn input_node_expr(input: &InputNode, delay: usize) -> Result<String, String> {
    let feat_id = input.feat_id.as_ref();
    let threshold = input.threshold;
    match (feat_id, threshold) {
        (Some(feat_id), Some(threshold)) => {
            let var = feat_var(feat_id)?;
            Ok(threshold_expr(&var, threshold, delay))
        }
        _ => Ok("default_value".to_string())
    }
}

fn input_ref(node_idx: usize, in_idx: Option<usize>) -> String {
    match in_idx {
        None => "default_value".to_string(),
        Some(idx) => {
            if idx < node_idx {
                node_var(idx)
            } else {
                prev_var(idx)
            }
        }
    }
}

fn gate_node_expr(idx: usize, gate_node: &GateNode) -> String {
    match gate_node.gate {
        None => "default_value".to_string(),
        Some(gate) => {
            let left = input_ref(idx, gate_node.in1_idx);
            let right = input_ref(idx, gate_node.in2_idx);
            match gate {
                Gate::And => format!("{left} and {right}"),
                Gate::Or => format!("{left} or {right}"),
                Gate::Xor => format!("({left} and not {right}) or (not {left} and {right})"),
                Gate::Nand => format!("not ({left} and {right})"),
                Gate::Nor => format!("not ({left} or {right})"),
                Gate::Xnor => format!("not (({left} and not {right}) or (not {left} and {right}))")
            }
        }
    }
}

fn logic_node_expr(idx: usize, node: &LogicNode, delay: usize) -> Result<String, String> {
    match node {
        LogicNode::Input(input) => input_node_expr(input, delay),
        LogicNode::Gate(gate_node) => Ok(gate_node_expr(idx, gate_node))
    }
}

impl NetToPs for LogicNet {
    fn emit(&self, delay: usize) -> Result<NetEmit, String> {
        if self.nodes.is_empty() {
            return Err("logic net has no nodes".to_string());
        }

        let default_literal = bool_literal(self.default_value);

        let mut declarations = Vec::new();
        declarations.push(format!("bool default_value = {default_literal}"));
        for idx in 0..self.nodes.len() {
            declarations.push(format!("var bool {0} = {default_literal}", node_var(idx)));
        }

        let mut per_bar = Vec::new();
        for idx in 0..self.nodes.len() {
            let name = node_var(idx);
            let prev_name = prev_var(idx);
            per_bar.push(format!("{prev_name} = {name}"));
        }

        for (idx, node) in self.nodes.iter().enumerate() {
            let name = node_var(idx);
            let new_expr = logic_node_expr(idx, node, delay)?;
            per_bar.push(format!("{name} := {new_expr}"));
        }

        Ok(NetEmit {
            declarations,
            per_bar
        })
    }

    fn node_value_expr(&self, node_ptr: &NodePtr) -> String {
        let len = self.nodes.len();

        match node_ptr.abs_idx(len) {
            Some(idx) => node_var(idx),
            None => "default_value".to_string()
        }
    }
}
