use std::collections::HashMap;
use std::any::Any;
use std::panic::RefUnwindSafe;
use serde::Serialize;
use serde_json::Value;
use crate::utils::insert_tag;
//use crate::fetch_data::fetch_btc_ohlc;
pub use super::indicators::{
    NormalizedATR,
    NormalizedBB,
    BBOutput,
    NormalizedDC,
    DCOutput,
    NormalizedEMA,
    NormalizedMACD,
    MACDOutput,
    ROC,
    RSI,
    NormalizedSMA,
    Stochastic,
    StochasticOutput
};

pub struct TimestampedTable {
    pub timestamps: Vec<String>,
    pub table: HashMap<String, Vec<f64>>
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum OHLC { Open, High, Low, Close }

impl OHLC {
    pub fn to_str(&self) -> &'static str {
        match self {
            OHLC::Open => "open",
            OHLC::High => "high",
            OHLC::Low => "low",
            OHLC::Close => "close"
        }
    }
}

pub fn n_rows(data: &HashMap<String, Vec<f64>>) -> usize {
    data.values().next().map_or(0, |value| value.len())
}

pub trait Feature: RefUnwindSafe + Any {
    fn id(&self) -> String;
    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64>;
    fn as_any(&self) -> &dyn Any;
    fn to_json(&self) -> Value;
}

pub fn feats_to_json(feats: &[Box<dyn Feature>]) -> Value {
    let items = feats.iter().map(|feat| feat.to_json()).collect::<Vec<Value>>();
    Value::Array(items)
}

pub fn safe_divide(a: f64, b: f64) -> f64 {
    if b == 0.0 {
        return 0.0;
    }

    a / b
}

#[derive(Clone, Debug, Serialize)]
pub struct Constant {
    pub id: String,
    pub constant: f64
}

impl Feature for Constant {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn to_json(&self) -> Value {
        insert_tag(self, "feature", "constant")
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let len = n_rows(data);
        vec![self.constant; len]
    }
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum ReturnsType {
    Log,
    Simple
}

#[derive(Clone, Debug, Serialize)]
pub struct RawReturns {
    pub id: String,
    pub returns_type: ReturnsType,
    pub ohlc: OHLC
}

impl Feature for RawReturns {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn to_json(&self) -> Value {
        insert_tag(self, "feature", "raw_returns")
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = &data[self.ohlc.to_str()];
        let mut returns = vec![0.0; prices.len()];

        for i in 1..prices.len() {
            let price_ratio = safe_divide(prices[i], prices[i - 1]);
            returns[i] = match self.returns_type {
                ReturnsType::Log => price_ratio.ln(),
                ReturnsType::Simple => price_ratio - 1.0
            };
        }

        returns
    }
}

pub fn feat_ids(feats: &[Box<dyn Feature>]) -> Vec<String> {
    feats.iter().map(|feat| feat.id()).collect()
}

pub fn feat_table(feats: &[Box<dyn Feature>], data: &TimestampedTable) -> TimestampedTable {
    let mut table = HashMap::new();

    for feat in feats {
        let feat_id = feat.id();
        let values = feat.calculate_values(&data.table);
        table.insert(feat_id, values);
    }

    TimestampedTable { timestamps: data.timestamps.clone(), table }
}

/*
pub struct FeatureSet {
    pub start_timestamp: f64,
    pub end_timestamp: f64,
    pub feats: Vec<Box<dyn Feature>>
}

impl FeatureSet {
    pub async fn generate_feat_table(&self) -> Result<(HashMap<String, Vec<f64>>, FeatTable), String> {
        let data = fetch_btc_ohlc(self.start_timestamp, self.end_timestamp).await?;
        let table = feat_table(&self.feats, &data);
        Ok((data, table))
    }
}

pub fn parse_feature_set(row: &Value) -> Result<FeatureSet, String> {
    let start_timestamp = field_usize(row, "start_timestamp")? as f64;
    let end_timestamp = field_usize(row, "end_timestamp")? as f64;

    if start_timestamp >= end_timestamp {
        return Err("start_timestamp must be < end_timestamp".to_string());
    }

    let features_json = get_field(row, "features")?;
    let feats_array = field_array(features_json, "feats")?;
    let feats = parse_feats(feats_array)?;
    let set = FeatureSet {
        start_timestamp,
        end_timestamp,
        feats
    };

    Ok(set)
}
*/
