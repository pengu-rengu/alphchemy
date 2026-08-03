use alphchemy_utils::parse_timestamp;

#[cfg(test)]
use mockall::automock;

use crate::filters::{Filter, FilterOperator, FilterValue};
use crate::query::{Query, Selection, SortSpec, Visibility};

#[cfg_attr(test, automock)]
pub(crate) trait ParseQueryDeps {
    fn parse_operator(&self, operator: &str) -> Result<FilterOperator, String> {
        match operator {
            "==" => Ok(FilterOperator::Equal),
            ">=" => Ok(FilterOperator::GreaterEqual),
            ">" => Ok(FilterOperator::Greater),
            "<=" => Ok(FilterOperator::LessEqual),
            "<" => Ok(FilterOperator::Less),
            _ => Err(format!("Unknown operator: {operator}"))
        }
    }

    fn build_filter(&self, path: String, operator_text: &str, value_text: &str) -> Result<Filter, String> {
        _build_filter(&ParseQueryDepsImpl, path, operator_text, value_text)
    }

    fn parse_filter(&self, line: &str) -> Result<Filter, String> {
        _parse_filter(&ParseQueryDepsImpl, line)
    }

    fn split_wrapper(&self, line: &str) -> Result<Option<(String, String)>, String> {
        let message = format!("Invalid selection wrapper: {line}");
        let Some((prefix, rest)) = line.split_once('(') else {
            if line.contains(')') { return Err(message) }
            return Ok(None);
        };

        let Some(path) = rest.strip_suffix(')') else { return Err(message) };
        if path.is_empty() { return Err(message) }
        let owned_prefix = prefix.to_string();
        Ok(Some((owned_prefix, path.to_string())))
    }

    fn parse_window(&self, prefix: &str) -> Option<(usize, usize)> {
        let parts = prefix.split_once('+');
        let (limit_text, offset_text) = match parts {
            Some((limit_text, offset_text)) => (limit_text, Some(offset_text)),
            None => (prefix, None)
        };
        let limit = limit_text.parse::<usize>().ok()?;
        let offset = match offset_text {
            Some(offset_text) => offset_text.parse::<usize>().ok()?,
            None => 0
        };
        Some((limit, offset))
    }

    fn parse_wrapped_selection(&self, line: &str, prefix: &str, path: &str) -> Result<Selection, String> {
        _parse_wrapped_selection(&ParseQueryDepsImpl, line, prefix, path)
    }

    fn parse_selection(&self, line: &str) -> Result<Selection, String> {
        _parse_selection(&ParseQueryDepsImpl, line)
    }

    fn parse_visibility(&self, line: &str) -> Result<Visibility, String> {
        let line_split = line.split_once(':');
        let value = line_split.ok_or_else(|| {
            format!("Missing colon in visibility: {line}")
        })?.1.trim();

        match value {
            "all" => Ok(Visibility::All),
            "public" => Ok(Visibility::Public),
            "private" => Ok(Visibility::Private),
            _ => Err(format!("visibility must be all, public, or private, got {value}"))
        }
    }

    fn parse_sort(&self, line: &str, has_sort: bool) -> Result<SortSpec, String> {
        let ascending_path = line.strip_prefix("sort_asc:");
        let descending_path = line.strip_prefix("sort_desc:");
        let (path, descending) = match (ascending_path, descending_path) {
            (Some(path), None) => (path, false),
            (None, Some(path)) => (path, true),
            _ => return Err(format!("Invalid sort: {line}"))
        };
        if has_sort { return Err("Only one of sort_asc or sort_desc may be set".to_string()) }

        let path = path.trim_start().to_string();

        if path.is_empty() { return Err("Sort path cannot be empty".to_string()) }
        if path == "id" { return Err("`id` cannot be sorted".to_string()) }
        if path == "user_id" { return Err("`user_id` cannot be sorted".to_string()) }
        Ok(SortSpec {
            path,
            descending
        })
    }
}

pub(crate) struct ParseQueryDepsImpl;
impl ParseQueryDeps for ParseQueryDepsImpl {}

fn _build_filter<T>(deps: &T, path: String, operator_text: &str, value_text: &str) -> Result<Filter, String> where T: ParseQueryDeps {
    let operator = deps.parse_operator(operator_text)?;
    let quoted = value_text.starts_with('"');
    let text = if quoted { value_text.trim_matches('"') } else { value_text };

    if let Ok(timestamp) = parse_timestamp(text) {
        return Ok(Filter {
            path,
            operator,
            value: FilterValue::Timestamp(timestamp)
        });
    }

    if quoted {
        if operator != FilterOperator::Equal { return Err(format!("String filter only supports ==, got {operator_text}")) }
        return Ok(Filter {
            path,
            operator,
            value: FilterValue::Text(text.to_string())
        });
    }

    if matches!(text, "true" | "false") {
        if operator != FilterOperator::Equal {
            let message = format!("Bool filter only supports ==, got {operator_text}");
            return Err(message);
        }
        return Ok(Filter {
            path,
            operator,
            value: FilterValue::Bool(text == "true")
        });
    }

    let number = text.parse::<f64>().map_err(|error| error.to_string())?;
    Ok(Filter {
        path,
        operator,
        value: FilterValue::Number(number)
    })
}

fn _parse_filter<T>(deps: &T, line: &str) -> Result<Filter, String> where T: ParseQueryDeps {
    let tokens = line.split_whitespace().collect::<Vec<_>>();
    if tokens.len() < 3 {
        return Err(format!("Invalid filter: {line}"));
    }
    let value_text = tokens[2..].join(" ");
    deps.build_filter(tokens[0].to_string(), tokens[1], &value_text)
}

fn _parse_wrapped_selection<T>(deps: &T, line: &str, prefix: &str, path: &str) -> Result<Selection, String> where T: ParseQueryDeps {
    if matches!(prefix, "mean" | "max" | "min" | "std") {
        return Ok(Selection {
            text: line.to_string(),
            path: path.to_string(),
            aggregate: Some(prefix.to_string()),
            limit: None,
            offset: 0
        });
    }

    if let Some((limit, offset)) = deps.parse_window(prefix) {
        if !(1..=25).contains(&limit) {
            let message = format!("limit must be between 1 and 25, got {limit}");
            return Err(message);
        }
        if offset > 10000 {
            let message = format!("offset must be at most 10000, got {offset}");
            return Err(message);
        }
        return Ok(Selection {
            text: line.to_string(),
            path: path.to_string(),
            aggregate: None,
            limit: Some(limit),
            offset
        });
    }

    Err(format!("Invalid selection wrapper: {line}"))
}

fn _parse_selection<T>(deps: &T, line: &str) -> Result<Selection, String> where T: ParseQueryDeps {
    if line == "count" {
        return Ok(Selection {
            text: line.to_string(),
            path: String::new(),
            aggregate: Some(line.to_string()),
            limit: None,
            offset: 0
        });
    }

    if let Some((prefix, path)) = deps.split_wrapper(line)? {
        return deps.parse_wrapped_selection(line, &prefix, &path)
    }

    Ok(Selection {
        text: line.to_string(),
        path: line.to_string(),
        aggregate: None,
        limit: Some(25),
        offset: 0
    })
}

fn _parse_query<T>(deps: &T, query: &mut Query) -> Result<(), String> where T: ParseQueryDeps {
    query.select.clear();
    query.filters.clear();
    query.visibility = Visibility::All;
    query.sort = None;
    let mut section = None;

    for line in query.query.lines() {
        let stripped = line.trim();
        if stripped.is_empty() {
            continue;
        }
        if stripped == "select:" {
            section = Some("select");
            continue;
        }
        if stripped == "filters:" {
            section = Some("filters");
            continue;
        }
        if stripped.starts_with("visibility:") {
            query.visibility = deps.parse_visibility(stripped)?;
            section = None;
            continue;
        }
        if stripped.starts_with("sort_asc:") || stripped.starts_with("sort_desc:") {
            query.sort = Some(deps.parse_sort(stripped, query.sort.is_some())?);
            section = None;
            continue;
        }

        match section {
            Some("select") => {
                let selection = deps.parse_selection(stripped)?;
                if selection.path == "id" {
                    return Err("`id` cannot be selected".to_string());
                }
                if selection.path == "user_id" {
                    return Err("`user_id` cannot be selected".to_string());
                }
                query.select.push(selection);
            }
            Some("filters") => {
                let filter = deps.parse_filter(stripped)?;
                if filter.path == "id" {
                    return Err("`id` cannot be filtered".to_string());
                }
                if filter.path == "user_id" {
                    return Err("`user_id` cannot be filtered".to_string());
                }
                query.filters.push(filter);
            }
            _ => return Err(format!("Line outside any section: {stripped}"))
        }
    }

    if query.select.is_empty() {
        return Err("Query must select at least one path".to_string());
    }

    Ok(())
}

pub fn parse_query(query: &mut Query) -> Result<(), String> {
    _parse_query(&ParseQueryDepsImpl, query)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    fn gen_filter(tc: TestCase) -> Filter {
        let path = tc.draw(gen_text());
        let operator = tc.draw(sampled_from(vec![FilterOperator::Equal, FilterOperator::GreaterEqual, FilterOperator::Greater, FilterOperator::LessEqual, FilterOperator::Less]));
        let value = if tc.draw(booleans()) {
            FilterValue::Number(tc.draw(gen_f64()))
        } else if tc.draw(booleans()) {
            FilterValue::Text(tc.draw(gen_text()))
        } else if tc.draw(booleans()) {
            FilterValue::Bool(tc.draw(booleans()))
        } else {
            FilterValue::Timestamp(tc.draw(gen_text()))
        };
        Filter { path, operator, value }
    }

    #[hegel::composite]
    fn gen_selection(tc: TestCase) -> Selection {
        let text = tc.draw(gen_text());
        let path = tc.draw(gen_text());
        let aggregate = if tc.draw(booleans()) {
            let func = tc.draw(sampled_from(vec!["mean", "max", "min", "std", "count"]));
            Some(func.to_string())
        } else {
            None
        };
        let limit = if tc.draw(booleans()) { Some(tc.draw(gen_usize_between(1, 25))) } else { None };
        let offset = tc.draw(gen_usize_between(0, 10000));
        Selection { text, path, aggregate, limit, offset }
    }

    mod build_filter_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            path: String,
            operator: FilterOperator,
            date: String,
            text: String,
            flag: bool,
            number: f64,
            result: Result<Filter, String>
        }

        #[derive(Clone, Copy, PartialEq)]
        enum BuildFilterCase { Timestamp, Text, Bool, Number, Invalid }

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { ParseOperator, TextOperator, BoolOperator, Number }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: BuildFilterCase) -> TestContext {
            let path = tc.draw(gen_text());
            let operator_text = tc.draw(gen_text());

            let invalid_case = tc.draw(sampled_from(vec![InvalidCase::ParseOperator, InvalidCase::TextOperator, InvalidCase::BoolOperator, InvalidCase::Number]));
            let is_invalid = case == BuildFilterCase::Invalid;

            let operator = if matches!(case, BuildFilterCase::Text | BuildFilterCase::Bool) {
                FilterOperator::Equal 
            } else if is_invalid && matches!(invalid_case, InvalidCase::TextOperator | InvalidCase::BoolOperator) {
                tc.draw(sampled_from(vec![FilterOperator::GreaterEqual, FilterOperator::Greater, FilterOperator::LessEqual, FilterOperator::Less]))
            } else {
                tc.draw(sampled_from(vec![FilterOperator::Equal, FilterOperator::GreaterEqual, FilterOperator::Greater, FilterOperator::LessEqual, FilterOperator::Less]))
            };
            let mut mock_deps = MockParseQueryDeps::new();

            let expected_operator_text = operator_text.clone();
            mock_deps.expect_parse_operator()
                .times(1)
                .withf(move |actual_operator_text| *actual_operator_text == expected_operator_text)
                .return_const(if is_invalid && invalid_case == InvalidCase::ParseOperator { Err(String::new()) } else { Ok(operator) });

            let year = tc.draw(gen_usize_between(2000, 2030));
            let month = tc.draw(gen_usize_between(1, 12));
            let day = tc.draw(gen_usize_between(1, 28));
            let date = format!("{year:04}-{month:02}-{day:02}");

            let text = tc.draw(gen_text());
            let has_quote = text.contains('"');
            let is_timestamp = parse_timestamp(&text).is_ok();
            tc.assume(!has_quote && !is_timestamp);

            let flag = tc.draw(booleans());
            let number = tc.draw(gen_f64());

            let value_text = match case {
                BuildFilterCase::Timestamp => date.clone(),
                BuildFilterCase::Text => format!("\"{text}\""),
                BuildFilterCase::Bool => flag.to_string(),
                BuildFilterCase::Number => number.to_string(),
                BuildFilterCase::Invalid => match invalid_case {
                    InvalidCase::ParseOperator => number.to_string(),
                    InvalidCase::TextOperator => format!("\"{text}\""),
                    InvalidCase::BoolOperator => flag.to_string(),
                    InvalidCase::Number => {
                        let is_number = text.parse::<f64>().is_ok();
                        let is_bool = matches!(text.as_str(), "true" | "false");
                        tc.assume(!is_number && !is_bool);
                        text.clone()
                    }
                }
            };

            let result = _build_filter(&mock_deps, path.clone(), &operator_text, &value_text);
            TestContext { path, operator, date, text, flag, number, result }
        }

        #[hegel::test]
        fn test_build_filter_timestamp(tc: TestCase) {
            let ctx = tc.draw(gen_context(BuildFilterCase::Timestamp));

            let timestamp = format!("{}T00:00:00", ctx.date);
            let expected_value = FilterValue::Timestamp(timestamp);
            let expected_filter = Filter { path: ctx.path, operator: ctx.operator, value: expected_value };
            assert_eq!(ctx.result, Ok(expected_filter));
        }

        #[hegel::test]
        fn test_build_filter_text(tc: TestCase) {
            let ctx = tc.draw(gen_context(BuildFilterCase::Text));

            let expected_value = FilterValue::Text(ctx.text);
            let expected_filter = Filter { path: ctx.path, operator: FilterOperator::Equal, value: expected_value };
            assert_eq!(ctx.result, Ok(expected_filter));
        }

        #[hegel::test]
        fn test_build_filter_bool(tc: TestCase) {
            let ctx = tc.draw(gen_context(BuildFilterCase::Bool));

            let expected_value = FilterValue::Bool(ctx.flag);
            let expected_filter = Filter { path: ctx.path, operator: FilterOperator::Equal, value: expected_value };
            assert_eq!(ctx.result, Ok(expected_filter));
        }

        #[hegel::test]
        fn test_build_filter_number(tc: TestCase) {
            let ctx = tc.draw(gen_context(BuildFilterCase::Number));

            let expected_value = FilterValue::Number(ctx.number);
            let expected_filter = Filter { path: ctx.path, operator: ctx.operator, value: expected_value };
            assert_eq!(ctx.result, Ok(expected_filter));
        }

        #[hegel::test]
        fn test_build_filter_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(BuildFilterCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_filter_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_filter: Filter,
            result: Result<Filter, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let short_line = draw_invalid && tc.draw(booleans());
            let build_filter_invalid = draw_invalid && !short_line;

            let token_count = if short_line { tc.draw(gen_usize_with_max(2)) } else { tc.draw(gen_usize_between(3, 5)) };
            let tokens = tc.draw(gen_vec(gen_text(), token_count));

            for token in &tokens {
                let has_space = token.contains(char::is_whitespace);
                tc.assume(!token.is_empty() && !has_space);
            }

            let expected_filter = tc.draw(gen_filter());

            let expected_tokens = tokens.clone();
            let mut mock_deps = MockParseQueryDeps::new();
            mock_deps.expect_build_filter()
                .times(usize::from(!short_line))
                .withf(move |path, operator_text, value_text| {
                    if *path != expected_tokens[0] { return false }
                    if *operator_text != expected_tokens[1] { return false }
                    *value_text == expected_tokens[2..].join(" ")
                })
                .return_const(if build_filter_invalid { Err(String::new()) } else { Ok(expected_filter.clone()) });

            let line = tokens.join(" ");
            let result = _parse_filter(&mock_deps, &line);
            TestContext { expected_filter, result }
        }

        #[hegel::test]
        fn test_parse_filter(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_filter));
        }

        #[hegel::test]
        fn test_parse_filter_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_wrapped_selection_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            line: String,
            path: String,
            prefix: String,
            limit: usize,
            offset: usize,
            result: Result<Selection, String>
        }

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum WrappedSelectionCase { Aggregate, Window, Invalid }

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { IncorrectWrapper, LimitZero, LimitTooLarge, OffsetTooLarge }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: WrappedSelectionCase) -> TestContext {
            let line = tc.draw(gen_text());
            let path = tc.draw(gen_text());

            let is_aggregate_case = case == WrappedSelectionCase::Aggregate;
            let aggregate = tc.draw(sampled_from(vec!["mean", "max", "min", "std"]));
            let prefix = if is_aggregate_case { aggregate.to_string() } else {
                let other_prefix = tc.draw(gen_text());
                let is_aggregate = matches!(other_prefix.as_str(), "mean" | "max" | "min" | "std");
                tc.assume(!is_aggregate);
                other_prefix
            };

            let invalid_case = tc.draw(sampled_from(vec![InvalidCase::IncorrectWrapper, InvalidCase::LimitZero, InvalidCase::LimitTooLarge, InvalidCase::OffsetTooLarge]));
            let is_invalid = case == WrappedSelectionCase::Invalid;

            let limit = if is_invalid && invalid_case == InvalidCase::LimitZero { 0 } 
                else if is_invalid && invalid_case == InvalidCase::LimitTooLarge {
                    tc.draw(gen_usize_between(26, 100))
                } else {
                    tc.draw(gen_usize_between(1, 25))
                };
            let offset = if is_invalid && invalid_case == InvalidCase::OffsetTooLarge { 
                tc.draw(gen_usize_between(10001, 20000)) 
            } else {
                tc.draw(gen_usize_between(0, 10000))
            };

            let expected_prefix = prefix.clone();
            let mut mock_deps = MockParseQueryDeps::new();
            mock_deps.expect_parse_window()
                .times(usize::from(!is_aggregate_case))
                .withf(move |actual_prefix| *actual_prefix == expected_prefix)
                .return_const(if is_invalid && invalid_case == InvalidCase::IncorrectWrapper { None } else { Some((limit, offset)) });

            let result = _parse_wrapped_selection(&mock_deps, &line, &prefix, &path);
            TestContext { line, path, prefix, limit, offset, result }
        }

        #[hegel::test]
        fn test_parse_wrapped_selection_aggregate(tc: TestCase) {
            let ctx = tc.draw(gen_context(WrappedSelectionCase::Aggregate));

            let expected_selection = Selection { text: ctx.line, path: ctx.path, aggregate: Some(ctx.prefix), limit: None, offset: 0 };
            assert_eq!(ctx.result, Ok(expected_selection));
        }

        #[hegel::test]
        fn test_parse_wrapped_selection_window(tc: TestCase) {
            let ctx = tc.draw(gen_context(WrappedSelectionCase::Window));

            let expected_selection = Selection { text: ctx.line, path: ctx.path, aggregate: None, limit: Some(ctx.limit), offset: ctx.offset };
            assert_eq!(ctx.result, Ok(expected_selection));
        }

        #[hegel::test]
        fn test_parse_wrapped_selection_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(WrappedSelectionCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_selection_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            line: String,
            wrapped_selection: Selection,
            result: Result<Selection, String>
        }

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum SelectionCase { Count, Wrapped, Plain, Invalid }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: SelectionCase) -> TestContext {
            let is_count = case == SelectionCase::Count;
            let is_plain = case == SelectionCase::Plain;
            let is_invalid = case == SelectionCase::Invalid;
            let split_wrapper_err = is_invalid && tc.draw(booleans());
            let wrapped_err = is_invalid && !split_wrapper_err;
            let split_wrapper_some = !is_count && !is_plain && !split_wrapper_err;

            let prefix = tc.draw(gen_text());
            let path = tc.draw(gen_text());
            let line = if is_count { "count".to_string() } else if is_plain {
                let word = tc.draw(gen_text());
                tc.assume(word != "count");
                word
            } else { format!("{prefix}({path})") };

            let wrapped_selection = tc.draw(gen_selection());
            
            let expected_line = line.clone();
            let mut mock_deps = MockParseQueryDeps::new();
            mock_deps.expect_split_wrapper()
                .times(usize::from(!is_count))
                .withf(move |actual_line| *actual_line == expected_line)
                .return_const(if split_wrapper_err { 
                    Err(String::new()) 
                } else if split_wrapper_some { Ok(Some((prefix.clone(), path.clone()))) } else { Ok(None) });

            
            let expected_wrapped_line = line.clone();
            mock_deps.expect_parse_wrapped_selection()
                .times(usize::from(split_wrapper_some))
                .withf(move |actual_line, actual_prefix, actual_path| {
                    if *actual_line != expected_wrapped_line { return false }
                    if *actual_prefix != prefix { return false }
                    *actual_path == path
                })
                .return_const(if wrapped_err { Err(String::new()) } else { Ok(wrapped_selection.clone()) });

            let result = _parse_selection(&mock_deps, &line);
            TestContext { line, wrapped_selection, result }
        }

        #[hegel::test]
        fn test_parse_selection_count(tc: TestCase) {
            let ctx = tc.draw(gen_context(SelectionCase::Count));

            let aggregate = "count".to_string();
            let expected_selection = Selection { text: ctx.line, path: String::new(), aggregate: Some(aggregate), limit: None, offset: 0 };
            assert_eq!(ctx.result, Ok(expected_selection));
        }

        #[hegel::test]
        fn test_parse_selection_wrapped(tc: TestCase) {
            let ctx = tc.draw(gen_context(SelectionCase::Wrapped));
            assert_eq!(ctx.result, Ok(ctx.wrapped_selection));
        }

        #[hegel::test]
        fn test_parse_selection_plain(tc: TestCase) {
            let ctx = tc.draw(gen_context(SelectionCase::Plain));

            let text = ctx.line.clone();
            let expected_selection = Selection { text, path: ctx.line, aggregate: None, limit: Some(25), offset: 0 };
            assert_eq!(ctx.result, Ok(expected_selection));
        }

        #[hegel::test]
        fn test_parse_selection_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(SelectionCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }
}
