use std::cmp::Ordering;
use std::collections::HashMap;

use alphchemy_utils::parse_timestamp;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::filters::{Filter, matches_filters};
use crate::parse_query::parse_query;
use crate::path::resolve_path;

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct QueryResults {
    pub path: String,
    pub values: Vec<Value>,
    pub ids: Vec<u64>,
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

#[derive(Clone, Copy, Debug, PartialEq)]
enum SortKind {
    Number,
    Timestamp
}

#[derive(Clone, Debug, PartialEq)]
enum SortableValue {
    Number(f64),
    Timestamp(String)
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

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub enum Visibility {
    #[default]
    All,
    Public,
    Private
}

#[derive(Clone, Debug, PartialEq)]
struct QueryExecution {
    aggregates: HashMap<usize, AggregateState>,
    candidates: Vec<RankedCandidate>,
    max_window_end: usize,
    matched_count: usize,
    base_skipped: usize,
    sort_kind: Option<SortKind>,
    cutoff_rank: Option<QueryRank>
}

#[derive(Clone, Debug, Default, PartialEq)]
struct AggregateState {
    resolved_count: usize,
    numeric_count: usize,
    skipped: usize,
    total: f64,
    total_squared: f64,
    extremum: Option<AggregatePoint>
}

#[derive(Clone, Debug, PartialEq)]
struct AggregatePoint {
    value: f64,
    id: u64,
    rank: QueryRank
}

#[derive(Clone, Debug, PartialEq)]
struct RankedCandidate {
    rank: QueryRank,
    values: HashMap<usize, WindowValue>
}

#[derive(Clone, Debug, PartialEq)]
enum WindowValue {
    Resolved { value: Value, id: u64 },
    Skipped,
    Error(String)
}

#[derive(Clone, Debug, PartialEq)]
struct QueryRank {
    sort_value: Option<SortableValue>,
    ordinal: usize
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub struct Query {
    pub query: String,
    #[serde(default)]
    pub results: Option<Vec<QueryResults>>,
    #[serde(skip)]
    pub select: Vec<Selection>,
    #[serde(skip)]
    pub(crate) filters: Vec<Filter>,
    #[serde(skip)]
    pub visibility: Visibility,
    #[serde(skip)]
    pub sort: Option<SortSpec>,
    #[serde(skip)]
    execution: Option<QueryExecution>
}

impl Query {
    pub fn new(query: impl Into<String>) -> Self {
        Self {
            query: query.into(),
            results: None,
            select: Vec::new(),
            filters: Vec::new(),
            visibility: Visibility::All,
            sort: None,
            execution: None
        }
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

    fn resolve_window_value(experiment: &Value, path: &str) -> WindowValue {
        let value = match resolve_path(experiment, path) {
            Ok(value) => value,
            Err(error) if error.starts_with("Missing") => return WindowValue::Skipped,
            Err(error) => return WindowValue::Error(error)
        };
        if value.as_f64().is_some_and(|number| !number.is_finite()) {
            return WindowValue::Skipped;
        }
        let Some(id) = experiment["id"].as_u64() else {
            return WindowValue::Error("Experiment id must be an integer".to_string());
        };
        WindowValue::Resolved { value, id }
    }

    fn compare_ranks(left: &QueryRank, right: &QueryRank, sort: Option<&SortSpec>) -> Ordering {
        let Some(sort) = sort else {
            return left.ordinal.cmp(&right.ordinal);
        };
        let left_value = left.sort_value.as_ref().unwrap();
        let right_value = right.sort_value.as_ref().unwrap();

        let ordering = left_value.compare(right_value);
        let ordering = if sort.descending { ordering.reverse() } else { ordering };

        if ordering == Ordering::Equal {
            left.ordinal.cmp(&right.ordinal)
        } else {
            ordering
        }
    }

    fn update_extremum(state: &mut AggregateState, selection: &Selection, value: f64, id: u64, rank: &QueryRank, sort: Option<&SortSpec>) {
        let Some(current) = &state.extremum else {
            state.extremum = Some(AggregatePoint {
                value,
                id,
                rank: rank.clone()
            });
            return;
        };
        let value_ordering = value.total_cmp(&current.value);
        let is_better = match selection.aggregate.as_deref() {
            Some("min") => value_ordering == Ordering::Less,
            Some("max") => value_ordering == Ordering::Greater,
            _ => false
        };
        let rank_ordering = Self::compare_ranks(rank, &current.rank, sort);
        let is_earlier_tie = value_ordering == Ordering::Equal && rank_ordering == Ordering::Less;
        if is_better || is_earlier_tie {
            state.extremum = Some(AggregatePoint {
                value,
                id,
                rank: rank.clone()
            });
        }
    }

    fn update_aggregate(state: &mut AggregateState, selection: &Selection, experiment: &Value, rank: &QueryRank, sort: Option<&SortSpec>) -> Result<(), String> {
        let value = match resolve_path(experiment, &selection.path) {
            Ok(value) => value,
            Err(error) if error.starts_with("Missing") => {
                state.skipped += 1;
                return Ok(());
            }
            Err(error) => return Err(error)
        };
        if value.as_f64().is_some_and(|number| !number.is_finite()) {
            state.skipped += 1;
            return Ok(());
        }
        let Some(id) = experiment["id"].as_u64() else {
            return Err("Experiment id must be an integer".to_string());
        };
        state.resolved_count += 1;
        let number = if let Some(flag) = value.as_bool() {
            Some(f64::from(flag))
        } else {
            value.as_f64()
        };
        let Some(number) = number else {
            return Ok(());
        };

        state.numeric_count += 1;
        state.total += number;
        state.total_squared += number * number;

        if matches!(selection.aggregate.as_deref(), Some("min" | "max")) {
            Self::update_extremum(state, selection, number, id, rank, sort);
        }
        Ok(())
    }

    fn process_experiment(&self, execution: &mut QueryExecution, experiment: &Value, user_id: &str) -> Result<(), String> {
        if !Self::is_visible(experiment, self.visibility, user_id) {
            return Ok(());
        }
        match matches_filters(experiment, &self.filters) {
            Ok(true) => {}
            Ok(false) => return Ok(()),
            Err(error) if error.starts_with("Missing") => {
                execution.base_skipped += 1;
                return Ok(());
            }
            Err(error) => return Err(error)
        }

        let sort_value = if let Some(sort) = &self.sort {
            let resolved = match resolve_path(experiment, &sort.path) {
                Ok(value) => value,
                Err(error) if error.starts_with("Missing") => {
                    execution.base_skipped += 1;
                    return Ok(());
                }
                Err(error) => return Err(error)
            };
            let Some(value) = Self::sortable_value(resolved, &sort.path)? else {
                execution.base_skipped += 1;
                return Ok(());
            };
            let current_kind = value.kind();
            if execution.sort_kind.is_some_and(|kind| kind != current_kind) {
                return Err(format!("Sort path `{}` cannot mix numbers and timestamps", sort.path));
            }
            execution.sort_kind = Some(current_kind);
            Some(value)
        } else { None };

        let rank = QueryRank { sort_value, ordinal: execution.matched_count };
        execution.matched_count += 1;

        for (i, selection) in self.select.iter().enumerate() {
            let Some(aggregate_state) = execution.aggregates.get_mut(&i) else {
                continue;
            };
            Self::update_aggregate(aggregate_state, selection, experiment, &rank, self.sort.as_ref())?;
        }

        if let Some(cutoff) = &execution.cutoff_rank {
            let ordering = Self::compare_ranks(&rank, cutoff, self.sort.as_ref());
            if ordering != Ordering::Less {
                return Ok(());
            }
        }

        let values = self.select.iter().enumerate().filter_map(|(idx, selection)| {
            selection.limit?;
            let window_value = Self::resolve_window_value(experiment, &selection.path);
            Some((idx, window_value))
        }).collect::<HashMap<_, _>>();

        if !values.is_empty() {
            execution.candidates.push(RankedCandidate { rank, values });
        }
        Ok(())
    }

    fn trim_candidates(&self, execution: &mut QueryExecution) {
        if self.sort.is_some() {
            execution.candidates.sort_by(|left, right| {
                Self::compare_ranks(&left.rank, &right.rank, self.sort.as_ref())
            });
        }
        execution.candidates.truncate(execution.max_window_end);

        if execution.candidates.len() == execution.max_window_end {
            let last = execution.candidates.last();
            execution.cutoff_rank = last.map(|candidate| candidate.rank.clone());
        }
    }

    fn aggregate_result(selection: &Selection, state: &AggregateState, base_skipped: usize) -> Result<QueryResults, String> {
        let skipped = base_skipped + state.skipped;
        if state.resolved_count == 0 {
            return Ok(QueryResults {
                path: selection.text.clone(),
                values: Vec::new(),
                ids: Vec::new(),
                skipped
            });
        }
        if state.numeric_count == 0 {
            let aggregate = selection.aggregate.as_deref().unwrap();
            let message = format!("Aggregate {aggregate} found no numeric values for {}", selection.path);
            return Err(message);
        }

        let aggregate = selection.aggregate.as_deref().unwrap();
        let value = match aggregate {
            "mean" => {
                let count = state.numeric_count as f64;
                state.total / count
            }
            "std" => {
                let count = state.numeric_count as f64;
                let mean = state.total / count;
                let squared_mean = mean * mean;
                let mean_of_squares = state.total_squared / count;
                let variance = mean_of_squares - squared_mean;
                let variance = variance.max(0.0);
                variance.sqrt()
            }
            "min" | "max" => state.extremum.as_ref().unwrap().value,
            _ => return Err(format!("Unrecognized aggregate: {aggregate}"))
        };
        let ids = if matches!(aggregate, "min" | "max") {
            vec![state.extremum.as_ref().unwrap().id]
        } else {
            Vec::new()
        };
        Ok(QueryResults {
            path: selection.text.clone(),
            values: vec![Value::from(value)],
            ids,
            skipped
        })
    }

    pub fn begin(&mut self) -> Result<(), String> {
        parse_query(self)?;
        self.results = None;
        let aggregates = self.select.iter().enumerate().filter_map(|(i, selection)| {
            match selection.aggregate.as_deref() {
                Some("mean" | "std" | "min" | "max") => Some((i, AggregateState::default())),
                _ => None
            }
        }).collect();
        let max_window_end = self.select.iter().filter_map(|selection| {
            selection.limit.map(|limit| selection.offset + limit)
        }).max().unwrap_or(0);
        self.execution = Some(QueryExecution {
            aggregates,
            candidates: Vec::new(),
            max_window_end,
            matched_count: 0,
            base_skipped: 0,
            sort_kind: None,
            cutoff_rank: None
        });
        Ok(())
    }

    pub fn push_page(&mut self, experiments: &[Value], user_id: &str) -> Result<(), String> {
        let mut execution = self.execution.take().ok_or("Query must begin before processing experiments".to_string())?;
        let result = experiments.iter().try_for_each(|experiment| {
            self.process_experiment(&mut execution, experiment, user_id)
        });
        self.trim_candidates(&mut execution);
        self.execution = Some(execution);
        result
    }

    pub fn finish(&mut self) -> Result<(), String> {
        let mut execution = self.execution.take().ok_or("Query must begin before finishing".to_string())?;
        let mut results = Vec::new();

        for (index, selection) in self.select.iter().enumerate() {
            if selection.aggregate.as_deref() == Some("count") {
                results.push(QueryResults {
                    path: selection.text.clone(),
                    values: vec![Value::from(execution.matched_count)],
                    ids: Vec::new(),
                    skipped: 0
                });
                continue;
            }
            if let Some(state) = execution.aggregates.get(&index) {
                let result = Self::aggregate_result(selection, state, execution.base_skipped)?;
                results.push(result);
                continue;
            }

            let mut values = Vec::new();
            let mut ids = Vec::new();
            let mut skipped = execution.base_skipped;
            let start = selection.offset.min(execution.candidates.len());
            let limit = selection.limit.unwrap();
            let end = (start + limit).min(execution.candidates.len());
            let candidates = &mut execution.candidates[start..end];
            for candidate in candidates {
                let Some(window_value) = candidate.values.remove(&index) else {
                    continue;
                };
                match window_value {
                    WindowValue::Resolved { value, id } => {
                        values.push(value);
                        ids.push(id);
                    }
                    WindowValue::Skipped => skipped += 1,
                    WindowValue::Error(error) => return Err(error)
                }
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
}
