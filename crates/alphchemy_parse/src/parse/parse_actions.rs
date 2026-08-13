pub mod parse_actions;
pub mod parse_logic_actions;
pub mod parse_decision_actions;

#[cfg(test)]
pub mod tests {
    use super::parse_actions::{tests::{gen_action, gen_range}, ActionsShared};
    use alphchemy_test_utils::{gen_text, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::TestCase;
    use std::collections::HashMap;

    #[hegel::composite]
    pub fn gen_actions_shared(tc: TestCase) -> ActionsShared {
        let n_meta = tc.draw(gen_usize_with_max(10));
        let mut meta_actions = HashMap::new();
        for i in 0..n_meta {
            let n_actions = tc.draw(gen_usize_with_max(10));
            meta_actions.insert(i.to_string(), tc.draw(gen_vec(gen_action(), n_actions)));
        }
        let n_thresholds_map = tc.draw(gen_usize_with_max(10));
        let mut thresholds = HashMap::new();
        for i in 0..n_thresholds_map {
            thresholds.insert(i.to_string(), tc.draw(gen_range()));
        }
        let n_thresholds = tc.draw(gen_usize_between(1, 10));
        let n_order = tc.draw(gen_usize_with_max(10));
        let feat_order = tc.draw(gen_vec(gen_text(), n_order));
        ActionsShared { meta_actions, thresholds, n_thresholds, feat_order }
    }
}
