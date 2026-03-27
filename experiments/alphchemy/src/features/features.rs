use ndarray::{Array1, Array2};
use std::collections::{HashMap, HashSet};
use serde::Deserialize;
use serde_json::Value;
use crate::utils::parse_json;

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OHLC { Open, High, Low, Close }

impl OHLC {
    fn to_str(&self) -> &'static str {
        match self {
            OHLC::Open => "open",
            OHLC::High => "high",
            OHLC::Low => "low",
            OHLC::Close => "close"
        }
    }
}

pub fn n_rows(data: &HashMap<String, Array1<f64>>) -> usize {
    data.values().next().map_or(0, |value| value.len())
}

pub trait Feature {
    fn id(&self) -> String;
    fn calculate_values(&self, data: &HashMap<String, Array1<f64>>) -> Array1<f64>;
}

#[derive(Clone, Debug, Deserialize)]
pub struct Constant {
    pub id: String,
    pub constant: f64
}

impl Feature for Constant {

    fn id(&self) -> String { self.id.clone() }

    fn calculate_values(&self, data: &HashMap<String, Array1<f64>>) -> Array1<f64> {
        let len = n_rows(data);

        Array1::from_elem(len, self.constant)
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ReturnsType {
    Log,
    Simple
}

#[derive(Clone, Debug, Deserialize)]
pub struct RawReturns {
    pub id: String,
    pub returns_type: ReturnsType,
    pub ohlc: OHLC
}

impl Feature for RawReturns {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Array1<f64>>) -> Array1<f64> {

        let prices = &data[self.ohlc.to_str()];

        let mut returns = Array1::from_elem(prices.len(), f64::NAN);

        for i in 1..prices.len() {
            match self.returns_type {
                ReturnsType::Log => returns[i] = (prices[i] / prices[i - 1]).ln(),
                ReturnsType::Simple => returns[i] = (prices[i] / prices[i - 1]) - 1.0
            }
        }

        returns
    }
}

pub fn feat_matrix(feats: &[Box<dyn Feature>], data: &HashMap<String, Array1<f64>>) -> Array2<f64> {

    let rows = n_rows(data);
    let mut matrix = Array2::zeros((rows, feats.len()));

    for (col_idx, feat) in feats.iter().enumerate() {
        let values = feat.calculate_values(data);
        let mut column = matrix.column_mut(col_idx);

        column.assign(&values);
    }

    matrix
}

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "feature")]
enum FeatureJson {
    #[serde(rename = "constant")]
    Constant(Constant),
    #[serde(rename = "raw_returns")]
    RawReturns(RawReturns)
}

pub fn parse_feat(json: &Value) -> Result<Box<dyn Feature>, String> {
    let feat_json = parse_json::<FeatureJson>(json)?;

    match feat_json {
        FeatureJson::Constant(constant) => {
            let box_constant = Box::new(constant); 
            Ok(box_constant)
        }
        FeatureJson::RawReturns(raw_returns) => {
            let box_raw_returns = Box::new(raw_returns);
            Ok(box_raw_returns)
        }
    }
}

pub fn validate_feat_ids(feats: &[Box<dyn Feature>]) -> Result<(), String> {
    let mut ids = HashSet::new();

    for feat in feats {
        if !ids.insert(feat.id()) {
            let error_msg = format!("duplicate feature id: {}", feat.id());
            return Err(error_msg);
        }
    }
    Ok(())
}

pub fn parse_feats(json_values: &Vec<Value>) -> Result<Vec<Box<dyn Feature>>, String> {
    let feats = json_values.iter().map(parse_feat).collect::<Result<Vec<Box<dyn Feature>>, String>>()?;
    validate_feat_ids(&feats)?;

    Ok(feats)
}


