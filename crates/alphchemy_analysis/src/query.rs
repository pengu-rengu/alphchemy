use std::cmp::Ordering;

use chrono::NaiveDateTime;
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::filters::{Filter, FilterOperator, FilterValue, matches_filters, parse_timestamp};
use crate::path::{apply_aggregate, numeric_values, resolve_path};

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct QueryResults {
    pub path: String,
    pub values: Vec<Value>,
    pub ids: Vec<i64>,
    pub skipped: usize
}

#[derive(Clone, Debug, PartialEq)]
pub struct Selection {
    pub text: String,
    pub path: String,
    pub aggregate: Option<String>,
    pub limit: Option<usize>,
    pub offset: usize
}

#[derive(Clone, Debug, PartialEq)]
pub struct SortSpec {
    pub path: String,
    pub descending: bool
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub enum Visibility {
    #[default]
    All,
    Public,
    Private
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Query {
    pub query: String,
    #[serde(default)]
    pub results: Option<Vec<QueryResults>>,
    #[serde(skip)]
    pub select: Vec<Selection>,
    #[serde(skip)]
    filters: Vec<Filter>,
    #[serde(skip)]
    pub visibility: Visibility,
    #[serde(skip)]
    pub sort: Option<SortSpec>
}

impl Query {
    pub fn new(query: impl Into<String>) -> Self {
        Self {
            query: query.into(),
            results: None,
            select: Vec::new(),
            filters: Vec::new(),
            visibility: Visibility::All,
            sort: None
        }
    }

    fn parse_operator(operator: &str) -> Result<FilterOperator, String> {
        match operator {
            "==" => Ok(FilterOperator::Equal),
            ">=" => Ok(FilterOperator::GreaterEqual),
            ">" => Ok(FilterOperator::Greater),
            "<=" => Ok(FilterOperator::LessEqual),
            "<" => Ok(FilterOperator::Less),
            _ => Err(format!("Unknown operator: {operator}"))
        }
    }

    fn build_filter(path: String, operator_text: &str, value_text: &str) -> Result<Filter, String> {
        let operator = Self::parse_operator(operator_text)?;
        let quoted = value_text.starts_with('"');
        let text = if quoted {
            value_text.trim_matches('"')
        } else {
            value_text
        };

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

        let number = text.parse::<f64>();
        let number = number.map_err(|error| error.to_string())?;
        Ok(Filter {
            path,
            operator,
            value: FilterValue::Number(number)
        })
    }

    fn parse_filter(line: &str) -> Result<Filter, String> {
        let tokens = line.split_whitespace().collect::<Vec<_>>();
        if tokens.len() < 3 {
            return Err(format!("Invalid filter: {line}"));
        }
        let path = tokens[0].to_string();
        let operator = tokens[1];
        let value_text = tokens[2..].join(" ");
        Self::build_filter(path, operator, &value_text)
    }

    fn parse_selection(line: &str) -> Result<Selection, String> {
        let aggregate_regex = Regex::new(r"^(mean|max|min|std)\((.+)\)$").unwrap();
        if let Some(captures) = aggregate_regex.captures(line) {
            let aggregate = captures[1].to_string();
            let path = captures[2].to_string();
            if path.contains('(') || path.contains(')') {
                return Err("Selection wrappers cannot be nested".to_string());
            }
            return Ok(Selection {
                text: line.to_string(),
                path,
                aggregate: Some(aggregate),
                limit: None,
                offset: 0
            });
        }

        let window_regex = Regex::new(r"^(\d+)(?:\+(\d+))?\((.+)\)$").unwrap();
        if let Some(captures) = window_regex.captures(line) {
            let limit = captures[1].parse::<usize>().unwrap();
            if !(1..=25).contains(&limit) {
                let message = format!("limit must be between 1 and 25, got {limit}");
                return Err(message);
            }
            let offset = captures.get(2).map_or(0, |capture| capture.as_str().parse::<usize>().unwrap());
            let path = captures[3].to_string();
            if path.contains('(') || path.contains(')') {
                return Err("Selection wrappers cannot be nested".to_string());
            }
            return Ok(Selection {
                text: line.to_string(),
                path,
                aggregate: None,
                limit: Some(limit),
                offset
            });
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

    fn parse_visibility(line: &str) -> Result<Visibility, String> {
        let value = line.split_once(':').map(|parts| parts.1.trim()).unwrap_or_default();
        match value {
            "all" => Ok(Visibility::All),
            "public" => Ok(Visibility::Public),
            "private" => Ok(Visibility::Private),
            _ => Err(format!("visibility must be all, public, or private, got {value}"))
        }
    }

    fn parse_sort(line: &str, has_sort: bool) -> Result<SortSpec, String> {
        let sort_regex = Regex::new(r"^sort_(asc|desc):\s*(.*)$").unwrap();
        let Some(captures) = sort_regex.captures(line) else {
            return Err(format!("Invalid sort: {line}"));
        };
        if has_sort {
            return Err("Only one of sort_asc or sort_desc may be set".to_string());
        }
        let path = captures[2].to_string();
        if path.is_empty() {
            return Err("Sort path cannot be empty".to_string());
        }
        if path == "id" {
            return Err("`id` cannot be sorted".to_string());
        }
        if path == "user_id" {
            return Err("`user_id` cannot be sorted".to_string());
        }
        Ok(SortSpec {
            path,
            descending: &captures[1] == "desc"
        })
    }

    pub fn parse(&mut self) -> Result<(), String> {
        self.select.clear();
        self.filters.clear();
        self.visibility = Visibility::All;
        self.sort = None;
        let mut section = None;

        for line in self.query.lines() {
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
                self.visibility = Self::parse_visibility(stripped)?;
                section = None;
                continue;
            }
            if stripped.starts_with("sort_asc:") || stripped.starts_with("sort_desc:") {
                self.sort = Some(Self::parse_sort(stripped, self.sort.is_some())?);
                section = None;
                continue;
            }

            match section {
                Some("select") => {
                    let selection = Self::parse_selection(stripped)?;
                    if selection.path == "id" {
                        return Err("`id` cannot be selected".to_string());
                    }
                    if selection.path == "user_id" {
                        return Err("`user_id` cannot be selected".to_string());
                    }
                    self.select.push(selection);
                }
                Some("filters") => {
                    let filter = Self::parse_filter(stripped)?;
                    if filter.path == "id" {
                        return Err("`id` cannot be filtered".to_string());
                    }
                    if filter.path == "user_id" {
                        return Err("`user_id` cannot be filtered".to_string());
                    }
                    self.filters.push(filter);
                }
                _ => return Err(format!("Line outside any section: {stripped}"))
            }
        }

        if self.select.is_empty() {
            return Err("Query must select at least one path".to_string());
        }

        Ok(())
    }

    fn is_visible(experiment: &Value, visibility: Visibility, user_id: &str) -> bool {
        let is_public = experiment["is_public"].as_bool().unwrap_or(false);
        let is_owned = experiment["user_id"].as_str() == Some(user_id);
        match visibility {
            Visibility::Public => is_public,
            Visibility::Private => !is_public && is_owned,
            Visibility::All => is_public || is_owned
        }
    }

    fn matched_experiments(experiments: Vec<Value>, filters: &[Filter]) -> Result<(Vec<Value>, usize), String> {
        let mut matched = Vec::new();
        let mut skipped = 0;

        for experiment in experiments {
            match matches_filters(&experiment, filters) {
                Ok(true) => matched.push(experiment),
                Ok(false) => continue,
                Err(error) if error.starts_with("Missing ") => skipped += 1,
                Err(error) => return Err(error)
            }
        }

        Ok((matched, skipped))
    }

    fn sortable_value(value: Value, path: &str) -> Result<Option<SortableValue>, String> {
        if let Some(number) = value.as_f64() {
            return Ok(number.is_finite().then_some(SortableValue::Number(number)));
        }
        if let Some(text) = value.as_str() {
            let timestamp = parse_timestamp(text);
            let timestamp = timestamp.map_err(|_| format!("Sort path `{path}` must resolve to numbers or timestamps"))?;
            return Ok(Some(SortableValue::Timestamp(timestamp)));
        }
        Err(format!("Sort path `{path}` must resolve to numbers or timestamps"))
    }

    fn sort_experiments(experiments: Vec<Value>, sort: &SortSpec) -> Result<(Vec<Value>, usize), String> {
        let mut sortable = Vec::new();
        let mut value_kind = None;
        let mut skipped = 0;

        for experiment in experiments {
            let resolved = match resolve_path(&experiment, &sort.path) {
                Ok(value) => value,
                Err(error) if error.starts_with("Missing ") => {
                    skipped += 1;
                    continue;
                }
                Err(error) => return Err(error)
            };
            let Some(sort_value) = Self::sortable_value(resolved, &sort.path)? else {
                skipped += 1;
                continue;
            };
            let current_kind = sort_value.kind();
            if value_kind.is_some_and(|kind| kind != current_kind) {
                let message = format!("Sort path `{}` cannot mix numbers and timestamps", sort.path);
                return Err(message);
            }
            value_kind = Some(current_kind);
            sortable.push((sort_value, experiment));
        }

        sortable.sort_by(|left, right| {
            let ordering = left.0.compare(&right.0);
            if sort.descending { ordering.reverse() } else { ordering }
        });
        let sorted = sortable.into_iter().map(|item| item.1).collect();
        Ok((sorted, skipped))
    }

    fn aggregate_id(values: &[Value], ids: &[i64], aggregate: f64) -> i64 {
        for (i, value) in values.iter().enumerate() {
            let numeric = if let Some(flag) = value.as_bool() {
                if flag { 1.0 } else { 0.0 }
            } else {
                value.as_f64().unwrap_or(f64::NAN)
            };
            if numeric == aggregate {
                return ids[i];
            }
        }
        ids[0]
    }

    fn set_results(&mut self, experiments: &[Value], base_skipped: usize) -> Result<(), String> {
        let mut results = Vec::new();

        for selection in &self.select {
            let start = selection.offset.min(experiments.len());
            let end = selection.limit.map_or(experiments.len(), |limit| start.saturating_add(limit).min(experiments.len()));
            let selected = &experiments[start..end];
            let mut values = Vec::new();
            let mut ids = Vec::new();
            let mut skipped = base_skipped;

            for experiment in selected {
                let value = match resolve_path(experiment, &selection.path) {
                    Ok(value) => value,
                    Err(error) if error.starts_with("Missing ") => {
                        skipped += 1;
                        continue;
                    }
                    Err(error) => return Err(error)
                };
                if value.as_f64().is_some_and(|number| !number.is_finite()) {
                    skipped += 1;
                    continue;
                }
                let Some(id) = experiment["id"].as_i64() else {
                    return Err("Experiment id must be an integer".to_string());
                };
                values.push(value);
                ids.push(id);
            }

            if let Some(aggregate_func) = &selection.aggregate
                && !values.is_empty()
            {
                let numbers = numeric_values(&values);
                if numbers.is_empty() {
                    let message = format!("Aggregate {aggregate_func} found no numeric values for {}", selection.path);
                    return Err(message);
                }
                let aggregate = apply_aggregate(aggregate_func, &numbers)?;
                if matches!(aggregate_func.as_str(), "min" | "max") {
                    ids = vec![Self::aggregate_id(&values, &ids, aggregate)];
                } else {
                    ids.clear();
                }
                values = vec![Value::from(aggregate)];
            }

            results.push(QueryResults {
                path: selection.text.clone(),
                values,
                ids,
                skipped
            });
        }

        self.results = Some(results);
        Ok(())
    }

    pub fn run_with_experiments(&mut self, experiments: Vec<Value>, user_id: &str) -> Result<(), String> {
        self.parse()?;
        let visible = experiments.into_iter().filter(|experiment| Self::is_visible(experiment, self.visibility, user_id)).collect();
        let (mut matched, mut base_skipped) = Self::matched_experiments(visible, &self.filters)?;
        if let Some(sort) = &self.sort {
            let (sorted, sort_skipped) = Self::sort_experiments(matched, sort)?;
            matched = sorted;
            base_skipped += sort_skipped;
        }
        self.set_results(&matched, base_skipped)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
enum SortKind {
    Number,
    Timestamp
}

enum SortableValue {
    Number(f64),
    Timestamp(NaiveDateTime)
}

impl SortableValue {
    fn kind(&self) -> SortKind {
        match self {
            Self::Number(_) => SortKind::Number,
            Self::Timestamp(_) => SortKind::Timestamp
        }
    }

    fn compare(&self, other: &Self) -> Ordering {
        match (self, other) {
            (Self::Number(left), Self::Number(right)) => left.total_cmp(right),
            (Self::Timestamp(left), Self::Timestamp(right)) => left.cmp(right),
            _ => Ordering::Equal
        }
    }
}
