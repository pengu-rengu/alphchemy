use std::collections::HashMap;

use alphchemy::actions::actions::Action;
use alphchemy::parse::parse_actions::parse_action;
use alphchemy::parse::parse_experiment::parse_experiment;

fn meta_actions() -> HashMap<String, Vec<Action>> {
    let mut meta_actions = HashMap::new();
    let label = "rewire".to_string();
    let sub_actions = vec![Action::NextFeat];
    meta_actions.insert(label, sub_actions);
    meta_actions
}

#[test]
fn parse_action_parses_builtin_without_meta_context() {
    let result = parse_action("next_feat", None);

    assert_eq!(result.unwrap(), Action::NextFeat);
}

#[test]
fn parse_action_parses_meta_action_with_context() {
    let meta_actions = meta_actions();
    let result = parse_action("rewire", Some(&meta_actions));
    let action = result.unwrap();
    let expected = Action::MetaAction("rewire".to_string());

    assert_eq!(action, expected);
}

#[test]
fn parse_action_rejects_meta_action_without_context() {
    let result = parse_action("rewire", None);

    assert!(result.is_err());
}

#[test]
fn parse_action_rejects_unknown_action_with_context() {
    let meta_actions = meta_actions();
    let result = parse_action("missing", Some(&meta_actions));
    let error = result.unwrap_err();

    assert!(error.contains("invalid action: missing"));
}

#[test]
fn parse_experiment_rejects_builtin_meta_action_label() {
    let source = "strategy:
  base_net:
    type: logic
  actions:
    meta_actions:
      next_feat:
        sub_actions: set_feat
";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("built-in meta-action label should fail");
    };

    assert!(error.contains("meta action label conflicts with built-in action: next_feat"));
}
