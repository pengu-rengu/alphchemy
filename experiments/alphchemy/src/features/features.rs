use std::collections::{HashMap, HashSet};
use std::any::Any;
use std::panic::RefUnwindSafe;
use serde::Deserialize;
use serde_json::Value;
use crate::fetch_data::fetch_btc_ohlc;
use crate::utils::{parse_json, validate_identifier, get_field, field_usize, field_array};
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

pub type FeatTable = HashMap<String, Vec<f64>>;

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OHLC { Open, High, Low, Close }

impl OHLC {
    pub(super) fn to_str(&self) -> &'static str {
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
}

pub fn safe_divide(a: f64, b: f64) -> f64 {
    if b == 0.0 {
        return 0.0;
    }

    a / b
}

fn validate_window(window: usize, field_name: &str) -> Result<(), String> {
    if window == 0 {
        return Err(format!("{field_name} must be > 0"));
    }

    Ok(())
}

fn validate_positive(value: f64, field_name: &str) -> Result<(), String> {
    if value <= 0.0 {
        return Err(format!("{field_name} must be > 0.0"));
    }

    Ok(())
}

#[derive(Clone, Debug, Deserialize)]
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

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let len = n_rows(data);
        vec![self.constant; len]
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

    fn as_any(&self) -> &dyn Any {
        self
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

pub fn feat_table(feats: &[Box<dyn Feature>], data: &HashMap<String, Vec<f64>>) -> FeatTable {
    let mut table = HashMap::new();

    for feat in feats {
        let feat_id = feat.id();
        let values = feat.calculate_values(data);
        table.insert(feat_id, values);
    }

    table
}

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "feature")]
enum FeatureJson {
    #[serde(rename = "constant")]
    Constant(Constant),
    #[serde(rename = "raw_returns")]
    RawReturns(RawReturns),
    #[serde(rename = "normalized_sma")]
    NormalizedSMA(NormalizedSMA),
    #[serde(rename = "normalized_ema")]
    NormalizedEMA(NormalizedEMA),
    #[serde(rename = "normalized_macd")]
    NormalizedMACD(NormalizedMACD),
    #[serde(rename = "rsi")]
    RSI(RSI),
    #[serde(rename = "normalized_bb")]
    NormalizedBB(NormalizedBB),
    #[serde(rename = "stochastic")]
    Stochastic(Stochastic),
    #[serde(rename = "normalized_atr")]
    NormalizedATR(NormalizedATR),
    #[serde(rename = "roc")]
    ROC(ROC),
    #[serde(rename = "normalized_dc")]
    NormalizedDC(NormalizedDC),
}

pub fn parse_feat(json: &Value) -> Result<Box<dyn Feature>, String> {
    let feat_json = parse_json::<FeatureJson>(json)?;

    let feat: Box<dyn Feature> = match feat_json {
        FeatureJson::Constant(constant) => Box::new(constant),
        FeatureJson::RawReturns(raw_returns) => Box::new(raw_returns),
        FeatureJson::NormalizedSMA(sma) => {
            validate_window(sma.window, "window")?;
            Box::new(sma)
        }
        FeatureJson::NormalizedEMA(ema) => {
            validate_window(ema.window, "window")?;
            validate_window(ema.smooth, "smooth")?;
            Box::new(ema)
        }
        FeatureJson::NormalizedMACD(macd) => {
            validate_window(macd.fast_window, "fast_window")?;
            validate_window(macd.slow_window, "slow_window")?;
            validate_window(macd.signal_window, "signal_window")?;
            validate_window(macd.fast_smooth, "fast_smooth")?;
            validate_window(macd.slow_smooth, "slow_smooth")?;
            validate_window(macd.signal_smooth, "signal_smooth")?;

            if macd.fast_window > macd.slow_window {
                return Err("fast_window must be <= slow_window".to_string());
            }

            Box::new(macd)
        }
        FeatureJson::RSI(rsi) => {
            validate_window(rsi.window, "window")?;
            validate_window(rsi.smooth, "smooth")?;
            Box::new(rsi)
        }
        FeatureJson::NormalizedBB(bb) => {
            validate_window(bb.window, "window")?;
            validate_positive(bb.std_multiplier, "std_mult")?;
            Box::new(bb)
        }
        FeatureJson::Stochastic(stochastic) => {
            validate_window(stochastic.window, "window")?;
            validate_window(stochastic.smooth_window, "smooth_window")?;
            Box::new(stochastic)
        }
        FeatureJson::NormalizedATR(atr) => {
            validate_window(atr.window, "window")?;
            validate_window(atr.smooth, "smooth")?;
            Box::new(atr)
        }
        FeatureJson::ROC(roc) => {
            validate_window(roc.window, "window")?;
            Box::new(roc)
        }
        FeatureJson::NormalizedDC(dc) => {
            validate_window(dc.window, "window")?;
            Box::new(dc)
        }
    };

    Ok(feat)
}

pub fn validate_feat_ids(feats: &[Box<dyn Feature>]) -> Result<(), String> {
    let mut ids = HashSet::new();

    for feat in feats {
        let feat_id = feat.id();
        validate_identifier(&feat_id, "feature id")?;
        if !ids.insert(feat_id) {
            let error_msg = format!("duplicate feature id: {}", feat.id());
            return Err(error_msg);
        }
    }

    Ok(())
}

pub fn parse_feats(json_values: &[Value]) -> Result<Vec<Box<dyn Feature>>, String> {
    let feats = json_values.iter().map(parse_feat).collect::<Result<Vec<Box<dyn Feature>>, String>>()?;
    validate_feat_ids(&feats)?;

    Ok(feats)
}

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
