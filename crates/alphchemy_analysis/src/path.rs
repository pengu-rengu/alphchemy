use serde_json::Value;

#[cfg(test)]
use mockall::automock;

#[derive(Clone, Debug, PartialEq)]
pub(crate) enum PathSegment {
    Key(String),
    Aggregate { func: String, inner_segments: Vec<PathSegment> },
    SelfPath
}

#[cfg_attr(test, automock)]
pub(crate) trait PathDeps {
    fn parse_path<'a>(&self, tokens: &[&'a str]) -> Result<Vec<PathSegment>, String> {
        _parse_path(&PathDepsImpl, tokens)
    }

    fn parse_segment<'a>(&self, token: &'a str, remaining_tokens: &[&'a str]) -> Result<PathSegment, String> {
        _parse_segment(&PathDepsImpl, token, remaining_tokens)
    }

    fn parse_aggregate_segment<'a>(&self, func: &'a str, first_inner_key: &'a str, remaining_tokens: &[&'a str]) -> Result<PathSegment, String> {
        _parse_aggregate_segment(&PathDepsImpl, func, first_inner_key, remaining_tokens)
    }

    fn numeric_values(&self, values: &[Value]) -> Vec<f64> {
        let mut numbers = Vec::new();

        for value in values {
            if let Some(flag) = value.as_bool() {
                let num = f64::from(flag);
                numbers.push(num);
            } else if let Some(num) = value.as_f64() {
                numbers.push(num);
            }
        }

        numbers
    }

    fn apply_aggregate(&self, func: &str, values: &[f64]) -> Result<f64, String> {
        match func {
            "mean" => Ok(values.iter().sum::<f64>() / values.len() as f64),
            "std" => {
                let mean = values.iter().sum::<f64>() / values.len() as f64;
                let squared_total = values.iter().map(|value| (value - mean).powi(2)).sum::<f64>();
                Ok((squared_total / values.len() as f64).sqrt())
            }
            "min" => {
                let maybe_min = values.iter().min_by(|a, b| {
                    a.total_cmp(b)
                });
                if let Some(min) = maybe_min {
                    Ok(*min)
                } else {
                    Err("No elements for min aggregate".to_string())
                }

            },
            "max" => {
                let maybe_max = values.iter().max_by(|a, b| {
                    a.total_cmp(b)
                });
                if let Some(max) = maybe_max { Ok(*max) } else { Err("No elements for max aggregate".to_string()) }
            },
            _ => Err(format!("Unrecognized aggregate: {func}"))
        }
    }

    fn resolve_self_aggregate(&self, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> {
        _resolve_self_aggregate(&PathDepsImpl, current, func, inner_segments, full_path)
    }

    fn resolve_item_aggregate(&self, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> {
        _resolve_item_aggregate(&PathDepsImpl, current, func, inner_segments, full_path)
    }

    fn resolve_aggregate(&self, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> {
        _resolve_aggregate(&PathDepsImpl, current, func, inner_segments, full_path)
    }

    fn resolve_aggregate_segment(&self, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Value, String> {
        _resolve_aggregate_segment(&PathDepsImpl, current, func, inner_segments, full_path)
    }

    fn resolve_key_segments<'a>(&self, object: &Value, keys: &[&'a str], full_path: &str) -> Result<Value, String> {
        let mut current = object;

        for key in keys {
            let Some(map) = current.as_object() else {
                let message = format!("Encountered a non-dictionary while resolving {full_path}");
                return Err(message);
            };
            let Some(value) = map.get(*key) else {
                return Err("Missing".to_string());
            };
            current = value;
        }

        Ok(current.clone())
    }

    fn resolve_segments(&self, object: &Value, segments: &[PathSegment], full_path: &str) -> Result<Value, String> {
        _resolve_segments(&PathDepsImpl, object, segments, full_path)
    }
}

pub(crate) struct PathDepsImpl;
impl PathDeps for PathDepsImpl {}

fn _parse_path<T>(deps: &T, tokens: &[&str]) -> Result<Vec<PathSegment>, String> where T: PathDeps {
    let mut segments = Vec::new();

    for (i, token) in tokens.iter().enumerate() {
        let segment = deps.parse_segment(token, &tokens[i + 1..])?;

        let is_aggregate = matches!(&segment, PathSegment::Aggregate { .. });
        segments.push(segment);

        if is_aggregate { return Ok(segments) }
    }

    Ok(segments)
}

fn _parse_aggregate_segment<T>(deps: &T, func: &str, first_inner_key: &str, remaining_tokens: &[&str]) -> Result<PathSegment, String> where T: PathDeps {
    if !matches!(func, "len" | "mean" | "std" | "min" | "max") {
        return Err(format!("Unknown aggregate `{func}`"));
    }
    if first_inner_key.is_empty() {
        return Err(format!("Aggregate `{func}` requires an inner path"));
    }

    let mut inner_tokens = vec![first_inner_key];
    inner_tokens.extend_from_slice(remaining_tokens);
    let inner_segments = deps.parse_path(&inner_tokens)?;

    Ok(PathSegment::Aggregate { func: func.to_string(), inner_segments })
}

fn _parse_segment<T>(deps: &T, token: &str, remaining_tokens: &[&str]) -> Result<PathSegment, String> where T: PathDeps {
    if matches!(token, "len" | "mean" | "std" | "min" | "max") {
        let message = format!("Aggregate `{token}` must use colon syntax, e.g. `results.{token}:path.to.value`");
        return Err(message);
    }

    if token == "self" {
        if !remaining_tokens.is_empty() {
            return Err("`self` must be the final segment".to_string());
        }
        return Ok(PathSegment::SelfPath);
    }

    let Some((func, first_inner_key)) = token.split_once(":") else {
        return Ok(PathSegment::Key(token.to_string()));
    };

    deps.parse_aggregate_segment(func, first_inner_key, remaining_tokens)
}

fn _resolve_self_aggregate<T>(deps: &T, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> where T: PathDeps {
    let target = deps.resolve_segments(current, &inner_segments[..inner_segments.len() - 1], full_path)?;
    let Value::Array(items) = target else {
        let message = format!("Aggregate `{func}` with .self requires a list target while resolving `{full_path}`");
        return Err(message);
    };
    Ok(items)
}

fn _resolve_item_aggregate<T>(deps: &T, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> where T: PathDeps {
    let Some(array) = current.as_array() else {
        let message = format!("Aggregate `{func}` requires a list target while resolving `{full_path}`");
        return Err(message);
    };
    let mut values = Vec::new();

    for item in array {
        match deps.resolve_segments(item, inner_segments, full_path) {
            Ok(value) => values.push(value),
            Err(error) if error.starts_with("Missing") => continue,
            Err(error) => return Err(error)
        }
    }

    Ok(values)
}

fn _resolve_aggregate<T>(deps: &T, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> where T: PathDeps {
    if matches!(inner_segments.last(), Some(PathSegment::SelfPath)) {
        deps.resolve_self_aggregate(current, func, inner_segments, full_path)
    } else {
        deps.resolve_item_aggregate(current, func, inner_segments, full_path)
    }
}


fn _resolve_aggregate_segment<T>(deps: &T, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Value, String> where T: PathDeps {
    let values = deps.resolve_aggregate(current, func, inner_segments, full_path)?;

    if func == "len" {
        return Ok(Value::from(values.len() as f64));
    }

    let numbers = deps.numeric_values(&values);
    if numbers.is_empty() {
        return Err("Missing".to_string());
    }

    let aggregate = deps.apply_aggregate(func, &numbers)?;
    return Ok(Value::from(aggregate));
}

fn _resolve_segments<T>(deps: &T, object: &Value, segments: &[PathSegment], full_path: &str) -> Result<Value, String> where T: PathDeps {
    let mut keys = Vec::new();
    let mut aggregate = None;

    for segment in segments {
        match segment {
            PathSegment::SelfPath => continue,
            PathSegment::Key(key) => keys.push(key.as_str()),
            PathSegment::Aggregate { func, inner_segments } => {
                aggregate = Some((func, inner_segments));
                break;
            }
        }
    }

    let resolved = deps.resolve_key_segments(object, &keys, full_path)?;
    let Some((func, inner_segments)) = aggregate else {
        return Ok(resolved);
    };
    deps.resolve_aggregate_segment(&resolved, func, inner_segments, full_path)
}

fn _resolve_path<T>(deps: &T, object: &Value, path: &str) -> Result<Value, String> where T: PathDeps {
    let tokens = path.split('.').collect::<Vec<_>>();
    let segments = deps.parse_path(&tokens)?;
    let result = deps.resolve_segments(object, &segments, path)?;

    if result.is_string() || result.is_boolean() || result.is_number() {
        return Ok(result);
    }

    Err("Resolved value must be a string, bool, or number".to_string())
}

pub fn resolve_path(object: &Value, path: &str) -> Result<Value, String> {
    _resolve_path(&PathDepsImpl, object, path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alphchemy_test_utils::{FLOAT_MAX, gen_f64_between, gen_text, gen_usize, gen_usize_with_min, gen_vec};
    use approx::assert_relative_eq;
    use mockall::{Sequence, predicate::eq};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    fn gen_path_segment(tc: TestCase) -> PathSegment {
        if tc.draw(booleans()) {
            PathSegment::SelfPath
        } else if tc.draw(booleans()) {
            let key = tc.draw(gen_text());
            PathSegment::Key(key)
        } else {
            let func = tc.draw(sampled_from(vec!["len", "mean", "std", "min", "max"]));
            let len = tc.draw(gen_usize_with_min(1));
            let mut inner_segments = Vec::new();
            for _ in 0..len {
                inner_segments.push(PathSegment::Key(tc.draw(gen_text())));
            }
            PathSegment::Aggregate { func: func.to_string(), inner_segments }
        }
    }

    #[hegel::composite]
    fn gen_scalar_value(tc: TestCase) -> Value {
        if tc.draw(booleans()) {
            Value::from(tc.draw(booleans()))
        } else if tc.draw(booleans()) {
            Value::from(tc.draw(gen_f64_between(-FLOAT_MAX, FLOAT_MAX)))
        } else {
            Value::from(tc.draw(gen_text()))
        }
    }

    mod parse_path_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_segments: Vec<PathSegment>,
            result: Result<Vec<PathSegment>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let len = tc.draw(gen_usize_with_min(1));
            let tokens = tc.draw(gen_vec(gen_text(), len));

            let segment = tc.draw(gen_path_segment());
            let is_aggregate = matches!(&segment, PathSegment::Aggregate { .. });
            let call_count = if draw_invalid || is_aggregate { 1 } else { len };
            let parse_segment_result = if draw_invalid {
                Err(String::new())
            } else {
                Ok(segment.clone())
            };

            let mut mock_deps = MockPathDeps::new();
            mock_deps.expect_parse_segment().times(call_count).return_const(parse_segment_result);

            let token_refs = tokens.iter().map(String::as_str).collect::<Vec<_>>();
            let result = _parse_path(&mock_deps, &token_refs);

            TestContext { expected_segments: vec![segment; call_count], result }
        }

        #[hegel::test]
        fn test_parse_path(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_segments));
        }

        #[hegel::test]
        fn test_parse_path_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_aggregate_segment_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_aggregate_segment: PathSegment,
            result: Result<PathSegment, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_agg = if draw_invalid { tc.draw(booleans()) } else { false };
            let invalid_empty_inner = if draw_invalid { !invalid_agg } else { false };

            let invalid_func = tc.draw(gen_text());
            let func = if invalid_agg {
                let is_invalid = matches!(invalid_func.as_str(), "len" | "mean" | "std" | "min" | "max");
                tc.assume(!is_invalid);
                invalid_func.as_str()
            } else {
                tc.draw(sampled_from(vec!["len", "mean", "std", "min", "max"]))
            };
            let tokens_len = tc.draw(gen_usize_with_min(1));
            let tokens = tc.draw(gen_vec(gen_text(), tokens_len));
            let first_inner_key = if invalid_empty_inner { String::new() } else {
                let first_token = tokens[0].clone();
                tc.assume(!first_token.is_empty());
                first_token
            };
            let remaining_tokens = tokens[1..].iter().map(String::as_str).collect::<Vec<_>>();

            let expected_tokens = tokens.clone();
            let inner_len = tc.draw(gen_usize_with_min(1));
            let expected_inner_segments = tc.draw(gen_vec(gen_path_segment(), inner_len));

            let mut mock_deps = MockPathDeps::new();
            mock_deps.expect_parse_path().times(usize::from(!draw_invalid)).withf(move |actual_tokens| {
                if actual_tokens.len() != tokens_len { return false }
                for (i, actual_token) in actual_tokens.iter().enumerate() {
                    if *actual_token != expected_tokens[i] { return false }
                }
                true
            }).return_const(Ok(expected_inner_segments.clone()));

            let expected_aggregate_segment = PathSegment::Aggregate { func: func.to_string(), inner_segments: expected_inner_segments };
            let result = _parse_aggregate_segment(&mock_deps, func, &first_inner_key, &remaining_tokens);
            TestContext { expected_aggregate_segment, result }
        }

        #[hegel::test]
        fn test_parse_aggregate_segment(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_aggregate_segment));
        }

        #[hegel::test]
        fn test_parse_aggregate_segment_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err())
        }
    }

    mod parse_segment_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            token: String,
            expected_aggregate_segment: Option<PathSegment>,
            result: Result<PathSegment, String>
        }

        #[derive(PartialEq)]
        enum ParseSegmentCase { SelfPath, Key, Aggregate, Invalid }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: ParseSegmentCase) -> TestContext {
            let is_invalid = case == ParseSegmentCase::Invalid;
            let invalid_no_colon = is_invalid && tc.draw(booleans());
            let invalid_self = is_invalid && !invalid_no_colon;

            let remaining_tokens = if case == ParseSegmentCase::SelfPath { Vec::new() } else {
                let len = tc.draw(gen_usize_with_min(1));
                tc.draw(gen_vec(gen_text(), len))
            };

            let mut mock_deps = MockPathDeps::new();
            let mut expected_aggregate_segment = None;
            let token = if invalid_no_colon {
                let aggregate_func = tc.draw(sampled_from(vec!["len", "mean", "std", "min", "max"]));
                aggregate_func.to_string()
            } else if invalid_self || case == ParseSegmentCase::SelfPath { "self".to_string()
            } else if case == ParseSegmentCase::Key {
                let key = tc.draw(gen_text());

                let is_aggregate_or_self = matches!(key.as_str(), "len" | "mean" | "std" | "min" | "max" | "self");
                let has_colon = key.contains(":");
                tc.assume(!is_aggregate_or_self && !has_colon);

                key
            } else if case == ParseSegmentCase::Aggregate {
                let func = tc.draw(gen_text());
                let func_has_colon = func.contains(":");
                tc.assume(!func_has_colon);
                let first_inner_key = tc.draw(gen_text());

                let expected_func = func.clone();
                let expected_first_inner_key = first_inner_key.clone();
                let expected_remaining = remaining_tokens.clone();

                let token = format!("{func}:{first_inner_key}");

                let len = tc.draw(gen_usize_with_min(1));
                let inner_segments = tc.draw(gen_vec(gen_path_segment(), len));
                let aggregate_segment = PathSegment::Aggregate { func, inner_segments };
                expected_aggregate_segment = Some(aggregate_segment.clone());

                mock_deps.expect_parse_aggregate_segment()
                    .times(1)
                    .withf(move |actual_func, actual_first_inner_key, actual_remaining| {
                        if *actual_func != expected_func { return false }
                        if *actual_first_inner_key != expected_first_inner_key { return false }
                        if actual_remaining.len() != expected_remaining.len() { return false }
                        for i in 0..actual_remaining.len() {
                            if actual_remaining[i] != expected_remaining[i] { return false }
                        }
                        true
                    })
                    .return_const(Ok(aggregate_segment));
                token
            } else { panic!("Invalid case") };

            let remaining_token_refs = remaining_tokens.iter().map(String::as_str).collect::<Vec<_>>();
            let result = _parse_segment(&mock_deps, &token, &remaining_token_refs);

            TestContext { token, expected_aggregate_segment, result }
        }

        #[hegel::test]
        fn test_parse_segment_self(tc: TestCase) {
            let ctx = tc.draw(gen_context(ParseSegmentCase::SelfPath));
            assert_eq!(ctx.result, Ok(PathSegment::SelfPath));
        }

        #[hegel::test]
        fn test_parse_segment_key(tc: TestCase) {
            let ctx = tc.draw(gen_context(ParseSegmentCase::Key));
            let expected_segment = PathSegment::Key(ctx.token);
            assert_eq!(ctx.result, Ok(expected_segment));
        }

        #[hegel::test]
        fn test_parse_segment_aggregate(tc: TestCase) {
            let ctx = tc.draw(gen_context(ParseSegmentCase::Aggregate));
            assert_eq!(ctx.result, Ok(ctx.expected_aggregate_segment.unwrap()));
        }

        #[hegel::test]
        fn test_parse_segment_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(ParseSegmentCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    #[hegel::test]
    fn test_numeric_values(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let numbers = tc.draw(gen_vec(gen_f64_between(-FLOAT_MAX, FLOAT_MAX), len));
        let flags = tc.draw(gen_vec(booleans(), len));
        let texts = tc.draw(gen_vec(gen_text(), len));
        let mut values = Vec::new();
        let mut expected = Vec::new();

        for i in 0..len {
            let number = Value::from(numbers[i]);
            values.push(number);
            expected.push(numbers[i]);

            let flag = Value::from(flags[i]);
            values.push(flag);
            let flag_number = f64::from(flags[i]);
            expected.push(flag_number);

            let text = Value::from(texts[i].clone());
            values.push(text);
        }

        let result = PathDepsImpl.numeric_values(&values);
        assert_eq!(result, expected);
    }

    mod apply_aggregate_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            mean: f64,
            std: f64,
            min: f64,
            max: f64,
            result: Result<f64, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, maybe_func: Option<&str>) -> TestContext {
            let invalid_func = tc.draw(gen_text());
            let func = maybe_func.unwrap_or_else(|| {
                let is_invalid = matches!(invalid_func.as_str(), "mean" | "std" | "min" | "max");
                tc.assume(!is_invalid);

                invalid_func.as_str()
            });
            let len = tc.draw(gen_usize_with_min(1));
            let value_gen = gen_f64_between(-FLOAT_MAX, FLOAT_MAX);
            let values = tc.draw(gen_vec(value_gen, len));

            let count = len as f64;
            let mean = values.iter().sum::<f64>() / count;
            let mut squared_total = 0.0;
            let mut min = values[0];
            let mut max = values[0];

            for value in &values {
                squared_total += (value - mean).powi(2);
                min = min.min(*value);
                max = max.max(*value);
            }

            let result = PathDepsImpl.apply_aggregate(&func, &values);

            TestContext { mean, std: (squared_total / count).sqrt(), min, max, result }
        }

        #[hegel::test]
        fn test_apply_mean(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some("mean")));
            assert_relative_eq!(ctx.result.unwrap(), ctx.mean, epsilon = 1e-5);
        }

        #[hegel::test]
        fn test_apply_std(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some("std")));
            assert_relative_eq!(ctx.result.unwrap(), ctx.std, epsilon = 1e-5);
        }

        #[hegel::test]
        fn test_apply_min(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some("min")));
            assert_relative_eq!(ctx.result.unwrap(), ctx.min, epsilon = 1e-5);
        }

        #[hegel::test]
        fn test_apply_max(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some("max")));
            assert_relative_eq!(ctx.result.unwrap(), ctx.max, epsilon = 1e-5);
        }

        #[test]
        fn test_apply_min_empty() {
            let result = PathDepsImpl.apply_aggregate("min", &[]);
            assert!(result.is_err());
        }

        #[test]
        fn test_apply_max_empty() {
            let result = PathDepsImpl.apply_aggregate("max", &[]);
            assert!(result.is_err());
        }

        #[hegel::test]
        fn test_apply_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(None));
            assert!(ctx.result.is_err());
        }
    }

    mod resolve_self_aggregate_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_values: Vec<Value>,
            result: Result<Vec<Value>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let current = tc.draw(gen_scalar_value());
            let func = tc.draw(gen_text());
            let full_path = tc.draw(gen_text());

            let inner_len = tc.draw(gen_usize_with_min(1));
            let mut inner_segments = tc.draw(gen_vec(gen_path_segment(), inner_len));
            inner_segments.push(PathSegment::SelfPath);
            let expected_segments = inner_segments[..inner_segments.len() - 1].to_vec();

            let values_len = tc.draw(gen_usize_with_min(1));
            let expected_values = tc.draw(gen_vec(gen_scalar_value(), values_len));

            let mut mock_deps = MockPathDeps::new();
            mock_deps.expect_resolve_segments().times(1).withf(move |_, actual_segments, _| {
                if actual_segments.len() != expected_segments.len() { return false }
                for (i, actual_segment) in actual_segments.iter().enumerate() {
                    if *actual_segment != expected_segments[i] { return false }
                }
                true
            }).return_const(if draw_invalid && tc.draw(booleans()) { Err(String::new())
            } else if draw_invalid { Ok(tc.draw(gen_scalar_value())) } else {
                Ok(Value::Array(expected_values.clone()))
            });

            let result = _resolve_self_aggregate(&mock_deps, &current, &func, &inner_segments, &full_path);
            TestContext { expected_values, result }
        }

        #[hegel::test]
        fn test_resolve_self_aggregate(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_values));
        }

        #[hegel::test]
        fn test_resolve_self_aggregate_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod resolve_item_aggregate_tests {
        use super::*;

        #[derive(Clone, Copy, PartialEq)]
        enum ResolveItemAggregateCase { Values, Missing, Invalid }

        #[derive(Debug)]
        struct TestContext {
            resolved_values: Vec<Value>,
            missing_values: Vec<Value>,
            result: Result<Vec<Value>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: ResolveItemAggregateCase) -> TestContext {
            let items_len = tc.draw(gen_usize_with_min(1));
            let items = tc.draw(gen_vec(gen_scalar_value(), items_len));
            let invalid_current = case == ResolveItemAggregateCase::Invalid && tc.draw(booleans());
            let current = if invalid_current { tc.draw(gen_scalar_value()) } else { Value::Array(items.clone()) };

            let func = tc.draw(gen_text());
            let full_path = tc.draw(gen_text());
            let inner_len = tc.draw(gen_usize());
            let inner_segments = tc.draw(gen_vec(gen_path_segment(), inner_len));

            let resolved_values = tc.draw(gen_vec(gen_scalar_value(), items_len));
            let missing_flags = tc.draw(gen_vec(booleans(), items_len));
            let mut missing_values = Vec::new();
            let mut resolve_results = Vec::new();

            match case {
                ResolveItemAggregateCase::Values => {
                    for value in &resolved_values {
                        resolve_results.push(Ok(value.clone()));
                    }
                }
                ResolveItemAggregateCase::Missing => {
                    let has_missing = missing_flags.contains(&true);
                    tc.assume(has_missing);

                    for i in 0..items_len {
                        if missing_flags[i] {
                            resolve_results.push(Err("Missing".to_string()));
                        } else {
                            let value = resolved_values[i].clone();
                            missing_values.push(value.clone());
                            resolve_results.push(Ok(value));
                        }
                    }
                }
                ResolveItemAggregateCase::Invalid => {
                    if !invalid_current {
                        resolve_results.push(Err(String::new()));
                    }
                }
            }

            let mut mock_deps = MockPathDeps::new();
            let mut sequence = Sequence::new();
            for (i, resolve_result) in resolve_results.into_iter().enumerate() {
                mock_deps.expect_resolve_segments()
                    .in_sequence(&mut sequence)
                    .times(1)
                    .with(eq(items[i].clone()), eq(inner_segments.clone()), eq(full_path.clone()))
                    .return_const(resolve_result);
            }

            let result = _resolve_item_aggregate(&mock_deps, &current, &func, &inner_segments, &full_path);
            TestContext { resolved_values, missing_values, result }
        }

        #[hegel::test]
        fn test_resolve_item_aggregate(tc: TestCase) {
            let ctx = tc.draw(gen_context(ResolveItemAggregateCase::Values));
            assert_eq!(ctx.result, Ok(ctx.resolved_values));
        }

        #[hegel::test]
        fn test_resolve_item_aggregate_missing(tc: TestCase) {
            let ctx = tc.draw(gen_context(ResolveItemAggregateCase::Missing));
            assert_eq!(ctx.result, Ok(ctx.missing_values));
        }

        #[hegel::test]
        fn test_resolve_item_aggregate_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(ResolveItemAggregateCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod resolve_aggregate_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            self_values: Vec<Value>,
            item_values: Vec<Value>,
            result: Result<Vec<Value>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, is_self: bool) -> TestContext {
            let current = tc.draw(gen_scalar_value());
            let func = tc.draw(gen_text());
            let full_path = tc.draw(gen_text());

            let inner_len = tc.draw(gen_usize_with_min(1));
            let mut inner_segments = tc.draw(gen_vec(gen_path_segment(), inner_len));
            if is_self {
                inner_segments.push(PathSegment::SelfPath);
            } else {
                inner_segments.push(PathSegment::Key(tc.draw(gen_text())));
            }

            let self_values_len = tc.draw(gen_usize_with_min(1));
            let self_values = tc.draw(gen_vec(gen_scalar_value(), self_values_len));
            let item_values_len = tc.draw(gen_usize_with_min(1));
            let item_values = tc.draw(gen_vec(gen_scalar_value(), item_values_len));
            tc.assume(self_values != item_values);

            let mut mock_deps = MockPathDeps::new();
            mock_deps.expect_resolve_self_aggregate()
                .times(usize::from(is_self))
                .return_const(Ok(self_values.clone()));

            mock_deps.expect_resolve_item_aggregate()
                .times(usize::from(!is_self))
                .return_const(Ok(item_values.clone()));

            let result = _resolve_aggregate(&mock_deps, &current, &func, &inner_segments, &full_path);
            TestContext { self_values, item_values, result }
        }

        #[hegel::test]
        fn test_resolve_aggregate_self(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert_eq!(ctx.result, Ok(ctx.self_values));
        }

        #[hegel::test]
        fn test_resolve_aggregate_items(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.item_values));
        }
    }

    mod resolve_aggregate_segment_tests {
        use super::*;

        #[derive(Clone, Copy, PartialEq)]
        enum ResolveAggregateSegmentCase { Len, Numeric, Invalid }

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Resolve, NoNumericValues, Apply }

        #[derive(Debug)]
        struct TestContext {
            expected_len: Value,
            expected_aggregate: Value,
            result: Result<Value, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: ResolveAggregateSegmentCase) -> TestContext {
            let current = tc.draw(gen_scalar_value());
            let func = if case == ResolveAggregateSegmentCase::Len { "len".to_string() } else {
                tc.draw(sampled_from(vec!["mean", "std", "min", "max"])).to_string()
            };
            let inner_len = tc.draw(gen_usize());
            let inner_segments = tc.draw(gen_vec(gen_path_segment(), inner_len));
            let full_path = tc.draw(gen_text());

            let values_len = tc.draw(gen_usize_with_min(1));
            let values = tc.draw(gen_vec(gen_scalar_value(), values_len));

            let numbers_len = tc.draw(gen_usize_with_min(1));
            let number_gen = gen_f64_between(-FLOAT_MAX, FLOAT_MAX);
            let numbers = tc.draw(gen_vec(number_gen, numbers_len));

            let aggregate = tc.draw(gen_f64_between(-FLOAT_MAX, FLOAT_MAX));

            let invalid_case = if case == ResolveAggregateSegmentCase::Invalid {
                Some(tc.draw(sampled_from(vec![InvalidCase::Resolve, InvalidCase::NoNumericValues, InvalidCase::Apply])))
            } else { None };

            let numeric_values = if invalid_case == Some(InvalidCase::NoNumericValues) { Vec::new() } else { numbers.clone() };

            let mut mock_deps = MockPathDeps::new();
            mock_deps.expect_resolve_aggregate()
                .times(1)
                .with(eq(current.clone()), eq(func.clone()), eq(inner_segments.clone()), eq(full_path.clone()))
                .return_const(if invalid_case == Some(InvalidCase::Resolve) { Err(String::new()) } else { Ok(values.clone()) });

            mock_deps.expect_numeric_values()
                .times(usize::from(case != ResolveAggregateSegmentCase::Len && invalid_case != Some(InvalidCase::Resolve)))
                .with(eq(values.clone()))
                .return_const(numeric_values.clone());

            mock_deps.expect_apply_aggregate()
                .times(usize::from(case == ResolveAggregateSegmentCase::Numeric || invalid_case == Some(InvalidCase::Apply)))
                .with(eq(func.clone()), eq(numeric_values))
                .return_const(if invalid_case == Some(InvalidCase::Apply) { Err(String::new()) } else { Ok(aggregate) });

            let expected_len = Value::from(values.len() as f64);
            let expected_aggregate = Value::from(aggregate);
            let result = _resolve_aggregate_segment(&mock_deps, &current, &func, &inner_segments, &full_path);
            TestContext { expected_len, expected_aggregate, result }
        }

        #[hegel::test]
        fn test_resolve_aggregate_segment_len(tc: TestCase) {
            let ctx = tc.draw(gen_context(ResolveAggregateSegmentCase::Len));
            assert_eq!(ctx.result, Ok(ctx.expected_len));
        }

        #[hegel::test]
        fn test_resolve_aggregate_segment_numeric(tc: TestCase) {
            let ctx = tc.draw(gen_context(ResolveAggregateSegmentCase::Numeric));
            assert_eq!(ctx.result, Ok(ctx.expected_aggregate));
        }

        #[hegel::test]
        fn test_resolve_aggregate_segment_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(ResolveAggregateSegmentCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod resolve_segments_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_value: Value,
            result: Result<Value, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let path_len = tc.draw(gen_usize_with_min(1));
            let path = tc.draw(gen_vec(gen_path_segment(), path_len));
            if draw_invalid {
                let has_resolver = path.iter().any(|segment| {
                    !matches!(segment, PathSegment::SelfPath)
                });
                tc.assume(has_resolver);
            }

            let object = tc.draw(gen_scalar_value());
            let full_path = tc.draw(gen_text());

            let mut expected_keys = Vec::new();
            let mut aggregate = None;

            for segment in &path {
                match segment {
                    PathSegment::SelfPath => continue,
                    PathSegment::Key(key) => expected_keys.push(key.clone()),
                    PathSegment::Aggregate { func, inner_segments } => {
                        aggregate = Some((func.clone(), inner_segments.clone()));
                        break;
                    }
                }
            }

            let keys_error = draw_invalid && !expected_keys.is_empty();
            let keys_value = tc.draw(gen_scalar_value());
            let expected_object = object.clone();
            let expected_full_path = full_path.clone();

            let mut mock_deps = MockPathDeps::new();
            let mut sequence = Sequence::new();

            mock_deps.expect_resolve_key_segments()
                .in_sequence(&mut sequence)
                .times(1)
                .withf(move |actual_object, actual_keys, actual_path| {
                    if *actual_object != expected_object { return false }
                    if actual_keys.len() != expected_keys.len() { return false }
                    for (i, actual_key) in actual_keys.iter().enumerate() {
                        if *actual_key != expected_keys[i] { return false }
                    }
                    actual_path == expected_full_path
                })
                .return_const(if keys_error { Err(String::new()) } else { Ok(keys_value.clone()) });

            let mut expected_value = keys_value;
            if let Some((func, inner_segments)) = aggregate {
                let aggregate_value = tc.draw(gen_scalar_value());
                mock_deps.expect_resolve_aggregate_segment()
                    .in_sequence(&mut sequence)
                    .times(usize::from(!keys_error))
                    .with(eq(expected_value.clone()), eq(func), eq(inner_segments), eq(full_path.clone()))
                    .return_const(if draw_invalid { Err(String::new()) } else { Ok(aggregate_value.clone()) });
                expected_value = aggregate_value;
            }

            let result = _resolve_segments(&mock_deps, &object, &path, &full_path);
            TestContext { expected_value, result }
        }

        #[hegel::test]
        fn test_resolve_segments(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_value));
        }

        #[hegel::test]
        fn test_resolve_segments_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod resolve_path_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { ParseErr, ResolveErr, NonScalar }

        #[derive(Debug)]
        struct TestContext {
            expected_value: Value,
            result: Result<Value, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let object = tc.draw(gen_scalar_value());
            let path = tc.draw(gen_text());

            let segments_len = tc.draw(gen_usize());
            let segments = tc.draw(gen_vec(gen_path_segment(), segments_len));

            let expected_value = tc.draw(gen_scalar_value());

            let invalid_case = if draw_invalid {
                Some(tc.draw(sampled_from(vec![InvalidCase::ParseErr, InvalidCase::ResolveErr, InvalidCase::NonScalar])))
            } else { None };

            let mut mock_deps = MockPathDeps::new();
            let expected_path = path.clone();
            mock_deps.expect_parse_path()
                .times(1)
                .withf(move |tokens| {
                    tokens.join(".") == expected_path
                })
                .return_const(if invalid_case == Some(InvalidCase::ParseErr) { Err(String::new()) } else { Ok(segments.clone()) });

            mock_deps.expect_resolve_segments()
                .times(usize::from(invalid_case != Some(InvalidCase::ParseErr)))
                .with(eq(object.clone()), eq(segments), eq(path.clone()))
                .return_const(if invalid_case == Some(InvalidCase::ResolveErr) {
                    Err(String::new())
                } else if invalid_case == Some(InvalidCase::NonScalar) {
                    let invalid_len = tc.draw(gen_usize());
                    let invalid_values = tc.draw(gen_vec(gen_scalar_value(), invalid_len));
                    Ok(Value::Array(invalid_values))
                } else { Ok(expected_value.clone()) });

            let result = _resolve_path(&mock_deps, &object, &path);
            TestContext { expected_value, result }
        }

        #[hegel::test]
        fn test_resolve_path(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_value));
        }

        #[hegel::test]
        fn test_resolve_path_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}
