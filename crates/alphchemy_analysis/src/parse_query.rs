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

    fn split_wrapper(&self, line: &str) -> Option<(String, String)> {
        let (prefix, path) = line.split_once('(')?;

        let path = path.strip_suffix(')')?;
        if path.is_empty() {
            return None;
        }
        let owned_prefix = prefix.to_string();
        Some((owned_prefix, path.to_string()))
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

    fn parse_wrapped_selection(&self, line: &str, prefix: &str, path: &str) -> Result<Option<Selection>, String> {
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
        if operator != FilterOperator::Equal {
            let message = format!("String filter only supports ==, got {operator_text}");
            return Err(message);
        }
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
    let path = tokens[0].to_string();
    let operator = tokens[1];
    let value_text = tokens[2..].join(" ");
    deps.build_filter(path, operator, &value_text)
}

fn _parse_wrapped_selection<T>(deps: &T, line: &str, prefix: &str, path: &str) -> Result<Option<Selection>, String> where T: ParseQueryDeps {
    if matches!(prefix, "mean" | "max" | "min" | "std") {
        return Ok(Some(Selection {
            text: line.to_string(),
            path: path.to_string(),
            aggregate: Some(prefix.to_string()),
            limit: None,
            offset: 0
        }));
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
        return Ok(Some(Selection {
            text: line.to_string(),
            path: path.to_string(),
            aggregate: None,
            limit: Some(limit),
            offset
        }));
    }

    Ok(None)
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

    if let Some((prefix, path)) = deps.split_wrapper(line)
    && let Some(selection) = deps.parse_wrapped_selection(line, &prefix, &path)? {
        return Ok(selection);
    }

    if line.contains('(') || line.contains(')') {
        return Err(format!("Invalid selection wrapper: {line}"));
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
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize_between};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

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

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: BuildFilterCase) -> TestContext {
            let path = tc.draw(gen_text());
            let operator_text = tc.draw(gen_text());

            let equal_only = matches!(case, BuildFilterCase::Text | BuildFilterCase::Bool);
            let operators = vec![ FilterOperator::Equal, FilterOperator::GreaterEqual, FilterOperator::Greater, FilterOperator::LessEqual, FilterOperator::Less ];
            let operator = if equal_only { FilterOperator::Equal } else { tc.draw(sampled_from(operators)) };

            let parse_operator_result = if case == BuildFilterCase::Invalid { Err(String::new()) } else { Ok(operator) };
            let expected_operator_text = operator_text.clone();
            let mut mock_deps = MockParseQueryDeps::new();
            mock_deps.expect_parse_operator()
                .times(1)
                .withf(move |actual_operator_text| *actual_operator_text == expected_operator_text)
                .return_const(parse_operator_result);

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
                BuildFilterCase::Number | BuildFilterCase::Invalid => number.to_string()
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
}
