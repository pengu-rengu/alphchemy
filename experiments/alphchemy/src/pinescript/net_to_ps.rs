use crate::network::network::NodePtr;

pub struct NetEmit {
    pub declarations: Vec<String>,
    pub per_bar: Vec<String>
}

pub trait NetToPs {
    fn emit(&self, delay: usize) -> Result<NetEmit, String>;
    fn node_value_expr(&self, node_ptr: &NodePtr) -> String;
}

pub fn bool_literal(value: bool) -> &'static str {
    if value {
        "true"
    } else {
        "false"
    }
}

pub fn threshold_expr(feat_var: &str, threshold: f64, delay: usize) -> String {
    if delay == 0 {
        format!("{feat_var} > {threshold}")
    } else {
        format!("{feat_var}[{delay}] > {threshold}")
    }
}
