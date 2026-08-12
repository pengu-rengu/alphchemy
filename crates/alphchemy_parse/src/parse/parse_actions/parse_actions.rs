use std::collections::{HashMap, HashSet};

use alphchemy_engine::features::features::{Feature, BBOutput, DCOutput, feat_ids as engine_feat_ids};
use alphchemy_engine::actions::actions::{Action, ThresholdRange};
use crate::parse::parse::{Entry, Line};

use super::super::parse::Fields;

#[cfg(test)]
use mockall::automock;

const MAX_SUBACTIONS: usize = 5;
const MAX_META_ACTIONS: usize = 25;

#[cfg_attr(test, automock)]
trait ParseActionsDeps {
    fn string<'a>(&self, fields: &Fields, keys: &[&'a str], default: &str) -> Result<String, String> {
        fields.string(keys, default)
    }

    fn string_list<'a>(&self, fields: &Fields, keys: &[&'a str], default: Vec<String>) -> Result<Vec<String>, String> {
        fields.string_list(keys, default)
    }

    fn usize<'a>(&self, fields: &Fields, keys: &[&'a str], default: usize) -> Result<usize, String> {
        fields.usize(keys, default)
    }

    fn f64<'a>(&self, fields: &Fields, keys: &[&'a str], default: f64) -> Result<f64, String> {
        fields.f64(keys, default)
    }

    fn child_fields<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Result<Option<Fields>, String> {
        fields.child_fields(keys)
    }

    fn fields_from_lines(&self, lines: &[Line]) -> Result<Fields, String> {
        Fields::from_lines(lines)
    }

    fn feat_ids(&self, feats: &[Feature]) -> Vec<String> {
        engine_feat_ids(feats)
    }

    fn parse_action<'a>(&self, text: &str, meta_actions: Option<&'a HashMap<String, Vec<Action>>>) -> Result<Action, String> {
        match text {
            "next_feat" => Ok(Action::NextFeat),
            "next_threshold" => Ok(Action::NextThreshold),
            "next_node" => Ok(Action::NextNode),
            "select_node" => Ok(Action::SelectNode),
            "next_gate" => Ok(Action::NextGate),
            "set_feat" => Ok(Action::SetFeat),
            "set_threshold" => Ok(Action::SetThreshold),
            "set_gate" => Ok(Action::SetGate),
            "set_in1_idx" => Ok(Action::SetIn1Idx),
            "set_in2_idx" => Ok(Action::SetIn2Idx),
            "set_true_idx" => Ok(Action::SetTrueIdx),
            "set_false_idx" => Ok(Action::SetFalseIdx),
            "set_ref_idx" => Ok(Action::SetRefIdx),
            "new_input" => Ok(Action::NewInput),
            "new_gate" => Ok(Action::NewGate),
            "new_branch" => Ok(Action::NewBranch),
            "new_ref" => Ok(Action::NewRef),
            _ => {
                if let Some(actions) = meta_actions && actions.contains_key(text) {
                    return Ok(Action::MetaAction(text.to_string()));
                }
                Err(format!("invalid action: {text}"))
            }
        }
    }

    fn parse_sub_actions(&self, texts: &[String]) -> Result<Vec<Action>, String> {
        _parse_sub_actions(&ParseActionsDepsImpl, texts)
    }

    fn meta_action_from_entry(&self, entry: &Entry) -> Result<(String, Vec<Action>), String> {
        _meta_action_from_entry(&ParseActionsDepsImpl, entry)
    }

    fn parse_meta_actions(&self, fields: Option<Fields>) -> Result<HashMap<String, Vec<Action>>, String> {
        _parse_meta_actions(&ParseActionsDepsImpl, fields)
    }

    fn default_threshold_range(&self, feat: &Feature) -> ThresholdRange {
        match feat {
            Feature::Constant(feat) => {
                let constant = feat.constant;
                let min = constant - 0.5;
                ThresholdRange { min, max: constant + 0.5 }
            }
            Feature::RawReturns(_) => ThresholdRange { min: -0.1, max: 0.1 },
            Feature::NormalizedSMA(_) | Feature::NormalizedEMA(_) => ThresholdRange { min: 0.9, max: 1.1 },
            Feature::NormalizedMACD(_) => ThresholdRange { min: -0.1, max: 0.1 },
            Feature::RSI(_) | Feature::Stochastic(_) => ThresholdRange { min: 0.0, max: 100.0 },
            Feature::NormalizedBB(feat) => match feat.output {
                BBOutput::Upper | BBOutput::Lower => ThresholdRange { min: 0.9, max: 1.1 },
                BBOutput::Width => ThresholdRange { min: 0.0, max: 0.2 }
            },
            Feature::NormalizedATR(_) => ThresholdRange { min: 0.0, max: 0.1 },
            Feature::ROC(_) => ThresholdRange { min: 0.9, max: 1.1 },
            Feature::NormalizedDC(feat) => match feat.output {
                DCOutput::Upper | DCOutput::Lower | DCOutput::Middle => ThresholdRange { min: 0.9, max: 1.1 },
                DCOutput::Width => ThresholdRange { min: 0.0, max: 0.2 }
            }
        }
    }

    fn validate_thresholds(&self, thresholds: &HashMap<String, ThresholdRange>, feats: &[Feature]) -> Result<(), String> {
        _validate_thresholds(&ParseActionsDepsImpl, thresholds, feats)
    }

    fn range_from_entry(&self, entry: &Entry, thresholds: &HashMap<String, ThresholdRange>) -> Result<ThresholdRange, String> {
        _range_from_entry(&ParseActionsDepsImpl, entry, thresholds)
    }

    fn parse_thresholds(&self, fields: Option<Fields>, feats: &[Feature]) -> Result<HashMap<String, ThresholdRange>, String> {
        _parse_thresholds(&ParseActionsDepsImpl, fields, feats)
    }

    fn validate_feat_order(&self, feat_order: &[String], feats: &[Feature]) -> Result<(), String> {
        _validate_feat_order(&ParseActionsDepsImpl, feat_order, feats)
    }

    fn parse_actions_shared(&self, fields: &Fields, feats: &[Feature], expected_type: &str) -> Result<ActionsShared, String> {
        _parse_actions_shared(&ParseActionsDepsImpl, fields, feats, expected_type)
    }
}

struct ParseActionsDepsImpl;
impl ParseActionsDeps for ParseActionsDepsImpl {}

pub fn parse_action(text: &str, meta_actions: Option<&HashMap<String, Vec<Action>>>) -> Result<Action, String> {
    ParseActionsDepsImpl.parse_action(text, meta_actions)
}

fn _parse_sub_actions<T>(deps: &T, texts: &[String]) -> Result<Vec<Action>, String> where T: ParseActionsDeps {
    let n_sub_actions = texts.len();
    if n_sub_actions > MAX_SUBACTIONS { return Err(format!("Meta actions cannot have more than {MAX_SUBACTIONS} sub actions")) }

    let mut actions = Vec::with_capacity(n_sub_actions);

    for text in texts {
        let action = deps.parse_action(text, None)?;
        actions.push(action);
    }

    Ok(actions)
}

fn _meta_action_from_entry<T>(deps: &T, entry: &Entry) -> Result<(String, Vec<Action>), String> where T: ParseActionsDeps {
    if deps.parse_action(&entry.key, None).is_ok() {
        return Err(format!("meta action label conflicts with built-in action: {}", entry.key));
    }

    let sub_fields = deps.fields_from_lines(&entry.child_lines)?;
    let sub_action_texts = deps.string_list(&sub_fields, &["sub_actions"], Vec::new())?;
    let sub_actions = deps.parse_sub_actions(&sub_action_texts)?;
    Ok((entry.key.to_string(), sub_actions))
}

fn _parse_meta_actions<T>(deps: &T, fields: Option<Fields>) -> Result<HashMap<String, Vec<Action>>, String> where T: ParseActionsDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut meta_actions = HashMap::new();

    for entry in &fields.entries {
        let (key, sub_actions) = deps.meta_action_from_entry(entry)?;
        meta_actions.insert(key, sub_actions);
    }

    if meta_actions.len() > MAX_META_ACTIONS { return Err(format!("Cannot have more than {MAX_META_ACTIONS} meta actions")) }

    Ok(meta_actions)
}

fn _validate_thresholds<T>(deps: &T, thresholds: &HashMap<String, ThresholdRange>, feats: &[Feature]) -> Result<(), String> where T: ParseActionsDeps {
    let ids = deps.feat_ids(feats);
    let id_set = ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();

    if thresholds.len() != ids.len() {
        return Err("length of thresholds must be == # of features".to_string());
    }

    for (feat_id, range) in thresholds {
        if !id_set.contains(feat_id.as_str()) {
            return Err(format!("feature with id \"{feat_id}\" not found"));
        }
        if range.max <= range.min {
            return Err(format!("threshold for feature id \"{feat_id}\" max must be > min"));
        }
    }

    Ok(())
}

fn _range_from_entry<T>(deps: &T, entry: &Entry, thresholds: &HashMap<String, ThresholdRange>) -> Result<ThresholdRange, String> where T: ParseActionsDeps {
    let feat_id = entry.key.to_string();
    let maybe_default_range = thresholds.get(&feat_id);
    let default_range = maybe_default_range.ok_or_else(|| {
        format!("feature with id \"{feat_id}\" not found")
    })?;
    let range_fields = deps.fields_from_lines(&entry.child_lines)?;
    let min = deps.f64(&range_fields, &["min", "minimum"], default_range.min)?;
    let max = deps.f64(&range_fields, &["max", "maximum"], default_range.max)?;
    let range = ThresholdRange { min, max };
    Ok(range)
}

fn _parse_thresholds<T>(deps: &T, fields: Option<Fields>, feats: &[Feature]) -> Result<HashMap<String, ThresholdRange>, String> where T: ParseActionsDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut thresholds = HashMap::new();

    for feat in feats {
        let feat_id = feat.id();
        let threshold_range = deps.default_threshold_range(feat);
        thresholds.insert(feat_id, threshold_range);
    }

    let mut threshold_ids = HashSet::new();

    for entry in &fields.entries {
        if !threshold_ids.insert(entry.key.clone()) {
            return Err(format!("duplicate threshold for feature id \"{}\"", entry.key));
        }
    }

    for entry in &fields.entries {
        let range = deps.range_from_entry(entry, &thresholds)?;
        thresholds.insert(entry.key.clone(), range);
    }

    deps.validate_thresholds(&thresholds, feats)?;
    Ok(thresholds)
}

fn _validate_feat_order<T>(deps: &T, feat_order: &[String], feats: &[Feature]) -> Result<(), String> where T: ParseActionsDeps {
    let ids = deps.feat_ids(feats);
    let id_set = ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();
    let mut order_set = HashSet::new();

    for feat_id in feat_order {
        if !id_set.contains(feat_id.as_str()) {
            return Err(format!("feature with id \"{feat_id}\" not found"));
        }
        if !order_set.insert(feat_id.as_str()) {
            return Err("feat_order cannot contain duplicate feature ids".to_string());
        }
    }

    Ok(())
}

#[derive(Debug, PartialEq)]
pub(super) struct ActionsShared {
    pub meta_actions: HashMap<String, Vec<Action>>,
    pub thresholds: HashMap<String, ThresholdRange>,
    pub n_thresholds: usize,
    pub feat_order: Vec<String>
}

fn _parse_actions_shared<T>(deps: &T, fields: &Fields, feats: &[Feature], expected_type: &str) -> Result<ActionsShared, String> where T: ParseActionsDeps {
    let action_type = deps.string(fields, &["type", "actions_type"], expected_type)?;
    if action_type != expected_type {
        return Err(format!("invalid actions type: {action_type}"));
    }

    let meta_fields = deps.child_fields(fields, &["meta_actions", "grouped_actions"])?;
    let meta_actions = deps.parse_meta_actions(meta_fields)?;

    let threshold_fields = deps.child_fields(fields, &["thresholds", "thresholds_grid"])?;
    let thresholds = deps.parse_thresholds(threshold_fields, feats)?;

    let n_thresholds = deps.usize(fields, &["n_thresholds"], 5)?;
    let default_feat_order = deps.feat_ids(feats);
    let feat_order = deps.string_list(fields, &["feat_order"], default_feat_order)?;

    if n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }
    deps.validate_feat_order(&feat_order, feats)?;

    Ok(ActionsShared { meta_actions, thresholds, n_thresholds, feat_order })
}

pub(super) fn parse_actions_shared(fields: &Fields, feats: &[Feature], expected_type: &str) -> Result<ActionsShared, String> {
    ParseActionsDepsImpl.parse_actions_shared(fields, feats, expected_type)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::parse::tests::{gen_entry, gen_fields};
    use alphchemy_engine::features::features::Constant;
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};
    use std::cell::Cell;

    #[hegel::composite]
    fn gen_action(tc: TestCase) -> Action {
        tc.draw(sampled_from(&[
            Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode,
            Action::NextGate, Action::SetFeat, Action::SetThreshold, Action::SetGate,
            Action::SetIn1Idx, Action::SetIn2Idx, Action::SetTrueIdx, Action::SetFalseIdx,
            Action::SetRefIdx, Action::NewInput, Action::NewGate, Action::NewBranch, Action::NewRef
        ]))
    }

    #[hegel::composite]
    fn gen_range(tc: TestCase) -> ThresholdRange {
        let min = tc.draw(gen_f64());
        ThresholdRange { min, max: min + tc.draw(gen_f64()) + 1.0 }
    }

    mod parse_sub_actions_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_actions: Vec<Action>,
            result: Result<Vec<Action>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_too_many = draw_invalid && tc.draw(booleans());
            let invalid_parse = draw_invalid && !invalid_too_many;

            let n_actions = if invalid_too_many {
                MAX_SUBACTIONS + tc.draw(gen_usize_between(1, 10))
            } else if invalid_parse {
                tc.draw(gen_usize_between(1, MAX_SUBACTIONS))
            } else {
                tc.draw(gen_usize_with_max(MAX_SUBACTIONS))
            };
            let invalid_idx = if invalid_parse { tc.draw(gen_usize_with_max(n_actions - 1)) } else { 0 };

            let texts = tc.draw(gen_vec(gen_text(), n_actions));
            let mut expected_actions = Vec::new();
            for _ in 0..n_actions {
                expected_actions.push(tc.draw(gen_action()));
            }

            let mut mock_deps = MockParseActionsDeps::new();
            let parse_idx = Cell::new(0);
            let actions_for_parse = expected_actions.clone();
            mock_deps.expect_parse_action()
                .times(if invalid_too_many { 0 } else if invalid_parse { invalid_idx + 1 } else { n_actions })
                .withf(|_, meta| meta.is_none())
                .returning(move |_, _| {
                    let idx = parse_idx.get();
                    if invalid_parse && idx == invalid_idx {
                        return Err(String::new())
                    }
                    parse_idx.set(idx + 1);
                    Ok(actions_for_parse[idx].clone())
                });

            let result = _parse_sub_actions(&mock_deps, &texts);
            TestContext { expected_actions, result }
        }

        #[hegel::test]
        fn test_parse_sub_actions(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_actions));
        }

        #[hegel::test]
        fn test_parse_sub_actions_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod meta_action_from_entry_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Conflict, SubFields, SubTexts, ParseSubActions }

        #[derive(Debug)]
        struct TestContext {
            expected_key: String,
            expected_actions: Vec<Action>,
            result: Result<(String, Vec<Action>), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[InvalidCase::Conflict, InvalidCase::SubFields, InvalidCase::SubTexts, InvalidCase::ParseSubActions]));

            let entry = tc.draw(gen_entry(None, None));
            let sub_fields = tc.draw(gen_fields());
            let n_actions = tc.draw(gen_usize_with_max(MAX_SUBACTIONS));
            let sub_action_texts = tc.draw(gen_vec(gen_text(), n_actions));

            let expected_actions = tc.draw(gen_vec(gen_action(), n_actions));

            let mut mock_deps = MockParseActionsDeps::new();

            mock_deps.expect_parse_action()
                .times(1)
                .withf({
                    let expected_key = entry.key.clone();
                    move |text, meta_action| text == expected_key && meta_action.is_none()
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Conflict {
                    Ok(tc.draw(gen_action()))
                } else { Err(String::new()) });

            mock_deps.expect_fields_from_lines()
                .times(usize::from(!draw_invalid || invalid_case != InvalidCase::Conflict))
                .withf({
                    let expected_lines = entry.child_lines.clone();
                    move |lines| *lines == expected_lines
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::SubFields { Err(String::new()) } else {
                    Ok(sub_fields.clone())
                });

            mock_deps.expect_string_list()
                .times(usize::from(!draw_invalid || ![InvalidCase::Conflict, InvalidCase::SubFields].contains(&invalid_case)))
                .withf({
                    let expected_fields = sub_fields.clone();
                    move |fields, keys, default| {
                        *fields == expected_fields && *keys == ["sub_actions"] && default.is_empty()
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::SubTexts { Err(String::new()) } else {
                    Ok(sub_action_texts.clone())
                });

            mock_deps.expect_parse_sub_actions()
                .times(usize::from(!draw_invalid || ![InvalidCase::Conflict, InvalidCase::SubFields, InvalidCase::SubTexts].contains(&invalid_case)))
                .withf({
                    let expected_texts = sub_action_texts.clone();
                    move |texts| *texts == expected_texts
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::ParseSubActions { Err(String::new()) } else {
                    Ok(expected_actions.clone())
                });

            let expected_key = entry.key.clone();
            let result = _meta_action_from_entry(&mock_deps, &entry);
            TestContext { expected_key, expected_actions, result }
        }

        #[hegel::test]
        fn test_meta_action_from_entry(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok((ctx.expected_key, ctx.expected_actions)));
        }

        #[hegel::test]
        fn test_meta_action_from_entry_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_meta_actions_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_meta: HashMap<String, Vec<Action>>,
            result: Result<HashMap<String, Vec<Action>>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_too_many = draw_invalid && tc.draw(booleans());
            let invalid_entry = draw_invalid && !invalid_too_many;

            let n_meta_actions = if invalid_too_many {
                MAX_META_ACTIONS + tc.draw(gen_usize_between(1, 10))
            } else if invalid_entry {
                tc.draw(gen_usize_between(1, MAX_META_ACTIONS))
            } else {
                tc.draw(gen_usize_with_max(MAX_META_ACTIONS))
            };
            let invalid_idx = if invalid_entry { tc.draw(gen_usize_with_max(n_meta_actions - 1)) } else { 0 };

            let mut entries = Vec::new();
            let mut expected_actions_list = Vec::new();
            let mut expected_meta = HashMap::new();
            for i in 0..n_meta_actions {
                let mut entry = tc.draw(gen_entry(None, None));
                entry.key = i.to_string();

                let n_actions = tc.draw(gen_usize_with_max(MAX_SUBACTIONS));
                let actions = tc.draw(gen_vec(gen_action(), n_actions));
                expected_meta.insert(entry.key.clone(), actions.clone());
                expected_actions_list.push(actions);
                entries.push(entry);
            }

            let fields = if n_meta_actions == 0 {
                if tc.draw(booleans()) { Some(Fields { entries }) } else { None }
            } else {
                Some(Fields { entries })
            };

            let mut mock_deps = MockParseActionsDeps::new();
            let parse_idx = Cell::new(0);
            let entries_for_parse = fields.as_ref().map(|fields| fields.entries.clone()).unwrap_or_default();
            mock_deps.expect_meta_action_from_entry()
                .times(if invalid_entry { invalid_idx + 1 } else { n_meta_actions })
                .returning(move |_entry| {
                    let idx = parse_idx.get();
                    if invalid_entry && idx == invalid_idx {
                        return Err(String::new())
                    }
                    parse_idx.set(idx + 1);
                    Ok((entries_for_parse[idx].key.clone(), expected_actions_list[idx].clone()))
                });

            let result = _parse_meta_actions(&mock_deps, fields);
            TestContext { expected_meta, result }
        }

        #[hegel::test]
        fn test_parse_meta_actions(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_meta));
        }

        #[hegel::test]
        fn test_parse_meta_actions_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod validate_thresholds_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { LenMismatch, UnknownId, BadRange }

        #[derive(Debug)]
        struct TestContext {
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[InvalidCase::LenMismatch, InvalidCase::UnknownId, InvalidCase::BadRange]));

            let n_ids = tc.draw(gen_usize_between(1, 10));
            let mut ids = Vec::new();
            for i in 0..n_ids {
                ids.push(i.to_string());
            }

            let mut thresholds = HashMap::new();
            for feat_id in &ids {
                thresholds.insert(feat_id.clone(), tc.draw(gen_range()));
            }
            if draw_invalid {
                if invalid_case == InvalidCase::LenMismatch {
                    if tc.draw(booleans()) {
                        let keep_ids = ids[..tc.draw(gen_usize_with_max(n_ids - 1))].to_vec();
                        thresholds.retain(|feat_id, _| keep_ids.contains(feat_id));
                    } else {
                        let n_extra = tc.draw(gen_usize_between(1, 5));
                        for _ in 0..n_extra {
                            let extra_id = tc.draw(gen_text());
                            let contains_id = ids.contains(&extra_id);
                            tc.assume(!contains_id);
                            thresholds.insert(extra_id, tc.draw(gen_range()));
                        }
                    }
                } else if invalid_case == InvalidCase::UnknownId {
                    let replace_idx = tc.draw(gen_usize_with_max(n_ids - 1));
                    let range = thresholds.remove(&ids[replace_idx].clone()).unwrap();
                    let missing_id = tc.draw(gen_text());

                    let contains_id = ids.contains(&missing_id);
                    tc.assume(!contains_id);

                    thresholds.insert(missing_id, range);
                } else if invalid_case == InvalidCase::BadRange {
                    let bad_idx = tc.draw(gen_usize_with_max(n_ids - 1));
                    let range = thresholds.get_mut(&ids[bad_idx]).unwrap();
                    if tc.draw(booleans()) {
                        range.max = range.min;
                    } else {
                        let delta = tc.draw(gen_f64()).abs() + 1.0;
                        range.max = range.min - delta;
                    }
                }
            }

            let mut mock_deps = MockParseActionsDeps::new();
            mock_deps.expect_feat_ids()
                .times(1)
                .return_const(ids);

            let result = _validate_thresholds(&mock_deps, &thresholds, &[]);
            TestContext { result }
        }

        #[hegel::test]
        fn test_validate_thresholds(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(()));
        }

        #[hegel::test]
        fn test_validate_thresholds_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod range_from_entry_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { MissingId, RangeFields, Min, Max }

        #[derive(Debug)]
        struct TestContext {
            expected_range: ThresholdRange,
            result: Result<ThresholdRange, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[
                InvalidCase::MissingId, InvalidCase::RangeFields, InvalidCase::Min, InvalidCase::Max
            ]));

            let entry = tc.draw(gen_entry(None, None));
            let range_fields = tc.draw(gen_fields());

            let default_range = tc.draw(gen_range());
            let expected_range = tc.draw(gen_range());

            let mut thresholds = HashMap::new();
            if !(draw_invalid && invalid_case == InvalidCase::MissingId) {
                thresholds.insert(entry.key.clone(), default_range.clone());
            }
            let n_extra = tc.draw(gen_usize_with_max(10));
            for _ in 0..n_extra {
                let extra_id = tc.draw(gen_text());
                tc.assume(extra_id != entry.key);
                thresholds.insert(extra_id, tc.draw(gen_range()));
            }

            let mut mock_deps = MockParseActionsDeps::new();

            mock_deps.expect_fields_from_lines()
                .times(usize::from(!draw_invalid || invalid_case != InvalidCase::MissingId))
                .withf({
                    let expected_lines = entry.child_lines.clone();
                    move |lines| *lines == expected_lines
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::RangeFields { Err(String::new()) } else {
                    Ok(range_fields.clone())
                });

            mock_deps.expect_f64()
                .times(usize::from(!draw_invalid || ![InvalidCase::MissingId, InvalidCase::RangeFields].contains(&invalid_case)))
                .withf({
                    let expected_fields = range_fields.clone();
                    let expected_default = default_range.min;
                    move |fields, keys, default| {
                        *fields == expected_fields && *keys == ["min", "minimum"] && *default == expected_default
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Min { Err(String::new()) } else {
                    Ok(expected_range.min)
                });

            mock_deps.expect_f64()
                .times(usize::from(!draw_invalid || ![InvalidCase::MissingId, InvalidCase::RangeFields, InvalidCase::Min].contains(&invalid_case)))
                .withf({
                    let expected_fields = range_fields.clone();
                    let expected_default = default_range.max;
                    move |fields, keys, default| {
                        *fields == expected_fields && *keys == ["max", "maximum"] && *default == expected_default
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Max { Err(String::new()) } else {
                    Ok(expected_range.max)
                });

            let result = _range_from_entry(&mock_deps, &entry, &thresholds);
            TestContext { expected_range, result }
        }

        #[hegel::test]
        fn test_range_from_entry(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_range));
        }

        #[hegel::test]
        fn test_range_from_entry_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_thresholds_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Duplicate, RangeFromEntry, Validate }

        #[derive(Debug)]
        struct TestContext {
            expected: HashMap<String, ThresholdRange>,
            result: Result<HashMap<String, ThresholdRange>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[InvalidCase::Duplicate, InvalidCase::RangeFromEntry, InvalidCase::Validate]));

            let n_feats = tc.draw(gen_usize_with_max(10));
            let n_entries = if draw_invalid && invalid_case == InvalidCase::Duplicate {
                tc.draw(gen_usize_between(2, 10))
            } else if draw_invalid && invalid_case == InvalidCase::RangeFromEntry {
                tc.draw(gen_usize_between(1, 10))
            } else {
                tc.draw(gen_usize_with_max(10))
            };
            let invalid_idx = if draw_invalid && invalid_case == InvalidCase::RangeFromEntry {
                tc.draw(gen_usize_with_max(n_entries - 1))
            } else { 0 };

            let mut feats = Vec::new();
            let mut default_ranges = Vec::new();
            let mut expected = HashMap::new();
            for i in 0..n_feats {
                let feat_id = i.to_string();
                let constant = Constant { id: feat_id.clone(), constant: tc.draw(gen_f64()) };
                let feature = Feature::Constant(constant);
                feats.push(feature);

                let range = tc.draw(gen_range());
                expected.insert(feat_id, range.clone());
                default_ranges.push(range);
            }

            let mut entries = Vec::new();
            let mut overlay_ranges = Vec::new();
            for i in 0..n_entries {
                let mut entry = tc.draw(gen_entry(None, None));
                entry.key = i.to_string();
                let range = tc.draw(gen_range());
                expected.insert(entry.key.clone(), range.clone());
                overlay_ranges.push(range);
                entries.push(entry);
            }
            if draw_invalid && invalid_case == InvalidCase::Duplicate {
                let dup_idx = tc.draw(gen_usize_with_max(n_entries - 1));
                let src_idx = tc.draw(gen_usize_with_max(n_entries - 1 ));
                tc.assume(dup_idx != src_idx);
                entries[dup_idx].key = entries[src_idx].key.clone();
            }

            let fields = if n_entries == 0 {
                if tc.draw(booleans()) { Some(Fields { entries }) } else { None }
            } else {
                Some(Fields { entries })
            };

            let mut mock_deps = MockParseActionsDeps::new();
            let default_idx = Cell::new(0);
            let defaults_for_parse = default_ranges.clone();
            mock_deps.expect_default_threshold_range()
                .times(n_feats)
                .returning(move |_| {
                    let idx = default_idx.get();
                    default_idx.set(idx + 1);
                    defaults_for_parse[idx].clone()
                });

            let parse_idx = Cell::new(0);
            let overlays_for_parse = overlay_ranges.clone();
            mock_deps.expect_range_from_entry()
                .times(if draw_invalid && invalid_case == InvalidCase::Duplicate {
                    0
                } else if draw_invalid && invalid_case == InvalidCase::RangeFromEntry {
                    invalid_idx + 1
                } else { n_entries })
                .returning(move |_, _| {
                    let idx = parse_idx.get();
                    if draw_invalid && invalid_case == InvalidCase::RangeFromEntry && idx == invalid_idx {
                        return Err(String::new())
                    }
                    parse_idx.set(idx + 1);
                    Ok(overlays_for_parse[idx].clone())
                });

            mock_deps.expect_validate_thresholds()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::Validate))
                .withf({
                    let expected_thresholds = expected.clone();
                    move |thresholds, _feats| *thresholds == expected_thresholds
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Validate { Err(String::new()) } else { Ok(()) });

            let result = _parse_thresholds(&mock_deps, fields, &feats);
            TestContext { expected, result }
        }

        #[hegel::test]
        fn test_parse_thresholds(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected));
        }

        #[hegel::test]
        fn test_parse_thresholds_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_actions_shared_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase {
            Type, TypeMismatch, MetaFields, ParseMeta, ThresholdFields, ParseThresholds, NThresholds, FeatOrder, NThresholdsZero, Validate
        }

        #[derive(Debug)]
        struct TestContext {
            expected: ActionsShared,
            result: Result<ActionsShared, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[
                InvalidCase::Type, InvalidCase::TypeMismatch, InvalidCase::MetaFields,
                InvalidCase::ParseMeta, InvalidCase::ThresholdFields, InvalidCase::ParseThresholds,
                InvalidCase::NThresholds, InvalidCase::FeatOrder, InvalidCase::NThresholdsZero,
                InvalidCase::Validate
            ]));

            let fields = tc.draw(gen_fields());
            let expected_type = tc.draw(gen_text());
            let action_type = if draw_invalid && invalid_case == InvalidCase::TypeMismatch {
                format!("{expected_type}x")
            } else {
                expected_type.clone()
            };

            let meta_fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };
            let threshold_fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };

            let n_meta = tc.draw(gen_usize_with_max(10));
            let mut meta_actions = HashMap::new();
            for i in 0..n_meta {
                let n_actions = tc.draw(gen_usize_with_max(MAX_SUBACTIONS));
                meta_actions.insert(i.to_string(), tc.draw(gen_vec(gen_action(), n_actions)));
            }

            let n_thresholds_map = tc.draw(gen_usize_with_max(10));
            let mut thresholds = HashMap::new();
            for i in 0..n_thresholds_map {
                thresholds.insert(i.to_string(), tc.draw(gen_range()));
            }

            let n_thresholds = if draw_invalid && invalid_case == InvalidCase::NThresholdsZero { 0 } else {
                tc.draw(gen_usize_between(1, 10))
            };

            let n_feats = tc.draw(gen_usize_with_max(10));
            let mut feats = Vec::new();
            let mut default_feat_order = Vec::new();
            for i in 0..n_feats {
                let feat_id = i.to_string();
                let constant = Constant { id: feat_id.clone(), constant: tc.draw(gen_f64()) };
                let feature = Feature::Constant(constant);
                feats.push(feature);
                default_feat_order.push(feat_id);
            }
            let n_order = tc.draw(gen_usize_with_max(10));
            let feat_order = tc.draw(gen_vec(gen_text(), n_order));

            let expected = ActionsShared {
                meta_actions: meta_actions.clone(),
                thresholds: thresholds.clone(),
                n_thresholds,
                feat_order: feat_order.clone()
            };

            let mut mock_deps = MockParseActionsDeps::new();

            mock_deps.expect_string()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_default = expected_type.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["type", "actions_type"] && *default == expected_default
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Type {
                    Err(String::new())
                } else { Ok(action_type) });

            mock_deps.expect_child_fields()
                .times(usize::from(!draw_invalid || ![InvalidCase::Type, InvalidCase::TypeMismatch].contains(&invalid_case)))
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys| {
                        *actual_fields == expected_fields && *keys == ["meta_actions", "grouped_actions"]
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::MetaFields {
                    Err(String::new())
                } else { Ok(meta_fields.clone()) });

            mock_deps.expect_parse_meta_actions()
                .times(usize::from(!draw_invalid || ![
                    InvalidCase::Type, InvalidCase::TypeMismatch, InvalidCase::MetaFields
                ].contains(&invalid_case)))
                .withf({
                    let expected_meta_fields = meta_fields.clone();
                    move |actual_fields| *actual_fields == expected_meta_fields
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::ParseMeta {
                    Err(String::new())
                } else { Ok(meta_actions) });

            mock_deps.expect_child_fields()
                .times(usize::from(!draw_invalid || ![
                    InvalidCase::Type, InvalidCase::TypeMismatch, InvalidCase::MetaFields, InvalidCase::ParseMeta
                ].contains(&invalid_case)))
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys| {
                        *actual_fields == expected_fields && *keys == ["thresholds", "thresholds_grid"]
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::ThresholdFields {
                    Err(String::new())
                } else { Ok(threshold_fields.clone()) });

            mock_deps.expect_parse_thresholds()
                .times(usize::from(!draw_invalid || ![
                    InvalidCase::Type, InvalidCase::TypeMismatch, InvalidCase::MetaFields,
                    InvalidCase::ParseMeta, InvalidCase::ThresholdFields
                ].contains(&invalid_case)))
                .withf({
                    let expected_threshold_fields = threshold_fields.clone();
                    move |actual_fields, _feats| *actual_fields == expected_threshold_fields
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::ParseThresholds {
                    Err(String::new())
                } else { Ok(thresholds) });

            mock_deps.expect_usize()
                .times(usize::from(!draw_invalid || ![
                    InvalidCase::Type, InvalidCase::TypeMismatch, InvalidCase::MetaFields,
                    InvalidCase::ParseMeta, InvalidCase::ThresholdFields, InvalidCase::ParseThresholds
                ].contains(&invalid_case)))
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["n_thresholds"] && *default == 5
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::NThresholds {
                    Err(String::new())
                } else { Ok(n_thresholds) });

            mock_deps.expect_feat_ids()
                .times(usize::from(!draw_invalid || ![
                    InvalidCase::Type, InvalidCase::TypeMismatch, InvalidCase::MetaFields,
                    InvalidCase::ParseMeta, InvalidCase::ThresholdFields, InvalidCase::ParseThresholds,
                    InvalidCase::NThresholds
                ].contains(&invalid_case)))
                .return_const(default_feat_order.clone());

            mock_deps.expect_string_list()
                .times(usize::from(!draw_invalid || ![
                    InvalidCase::Type, InvalidCase::TypeMismatch, InvalidCase::MetaFields,
                    InvalidCase::ParseMeta, InvalidCase::ThresholdFields, InvalidCase::ParseThresholds,
                    InvalidCase::NThresholds
                ].contains(&invalid_case)))
                .withf({
                    let expected_fields = fields.clone();
                    let expected_default = default_feat_order.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["feat_order"] && *default == expected_default
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::FeatOrder {
                    Err(String::new())
                } else { Ok(feat_order.clone()) });

            mock_deps.expect_validate_feat_order()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::Validate))
                .withf({
                    let expected_order = feat_order.clone();
                    move |actual_order, _feats| *actual_order == expected_order
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Validate {
                    Err(String::new())
                } else { Ok(()) });

            let result = _parse_actions_shared(&mock_deps, &fields, &feats, &expected_type);
            TestContext { expected, result }
        }

        #[hegel::test]
        fn test_parse_actions_shared(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected));
        }

        #[hegel::test]
        fn test_parse_actions_shared_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}