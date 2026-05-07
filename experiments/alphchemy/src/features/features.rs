use std::collections::{HashMap, HashSet};
use serde::Deserialize;
use serde_json::Value;
use crate::utils::parse_json;
pub use super::indicators::{
    Atr,
    BollingerBands,
    BollingerOutput,
    Cci,
    DonchianChannel,
    DonchianOutput,
    Ema,
    Macd,
    MacdOutput,
    Momentum,
    Roc,
    Rsi,
    Sma,
    Stochastic,
    StochasticOutput
};

pub type FeatTable = HashMap<String, Vec<f64>>;

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

pub fn n_rows(data: &HashMap<String, Vec<f64>>) -> usize {
    data.values().next().map_or(0, |value| value.len())
}

pub trait Feature {
    fn id(&self) -> String;
    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64>;
}

pub(super) fn nan_array(len: usize) -> Vec<f64> {
    vec![f64::NAN; len]
}

pub(super) fn ohlc_values<'a>(data: &'a HashMap<String, Vec<f64>>, ohlc: &OHLC) -> &'a Vec<f64> {
    &data[ohlc.to_str()]
}

pub(super) fn safe_ratio(numerator: f64, denominator: f64) -> f64 {
    if denominator == 0.0 {
        return f64::NAN;
    }

    numerator / denominator
}

fn validate_window(window: usize, field_name: &str) -> Result<(), String> {
    if window == 0 {
        return Err(format!("{field_name} must be > 0"));
    }

    Ok(())
}

fn validate_ordered_windows(fast_window: usize, slow_window: usize) -> Result<(), String> {
    if fast_window > slow_window {
        return Err("fast_window must be <= slow_window".to_string());
    }

    Ok(())
}

fn validate_positive(value: f64, field_name: &str) -> Result<(), String> {
    if value <= 0.0 {
        return Err(format!("{field_name} must be > 0.0"));
    }

    Ok(())
}

fn boxed_feature<T: Feature + 'static>(feature: T) -> Box<dyn Feature> {
    Box::new(feature)
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

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let mut returns = nan_array(prices.len());

        for i in 1..prices.len() {
            let price_ratio = safe_ratio(prices[i], prices[i - 1]);
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
    #[serde(rename = "sma")]
    Sma(Sma),
    #[serde(rename = "ema")]
    Ema(Ema),
    #[serde(rename = "macd")]
    Macd(Macd),
    #[serde(rename = "rsi")]
    Rsi(Rsi),
    #[serde(rename = "bollinger_bands")]
    BollingerBands(BollingerBands),
    #[serde(rename = "stochastic")]
    Stochastic(Stochastic),
    #[serde(rename = "atr")]
    Atr(Atr),
    #[serde(rename = "roc")]
    Roc(Roc),
    #[serde(rename = "momentum")]
    Momentum(Momentum),
    #[serde(rename = "donchian_channel")]
    DonchianChannel(DonchianChannel),
    #[serde(rename = "cci")]
    Cci(Cci)
}

pub fn parse_feat(json: &Value) -> Result<Box<dyn Feature>, String> {
    let feat_json = parse_json::<FeatureJson>(json)?;

    match feat_json {
        FeatureJson::Constant(constant) => Ok(boxed_feature(constant)),
        FeatureJson::RawReturns(raw_returns) => Ok(boxed_feature(raw_returns)),
        FeatureJson::Sma(sma) => {
            validate_window(sma.window, "window")?;
            Ok(boxed_feature(sma))
        }
        FeatureJson::Ema(ema_feature) => {
            validate_window(ema_feature.window, "window")?;
            Ok(boxed_feature(ema_feature))
        }
        FeatureJson::Macd(macd) => {
            validate_window(macd.fast_window, "fast_window")?;
            validate_window(macd.slow_window, "slow_window")?;
            validate_window(macd.signal_window, "signal_window")?;
            validate_ordered_windows(macd.fast_window, macd.slow_window)?;
            Ok(boxed_feature(macd))
        }
        FeatureJson::Rsi(rsi) => {
            validate_window(rsi.window, "window")?;
            Ok(boxed_feature(rsi))
        }
        FeatureJson::BollingerBands(bollinger) => {
            validate_window(bollinger.window, "window")?;
            validate_positive(bollinger.std_mult, "std_mult")?;
            Ok(boxed_feature(bollinger))
        }
        FeatureJson::Stochastic(stochastic) => {
            validate_window(stochastic.window, "window")?;
            validate_window(stochastic.smooth_window, "smooth_window")?;
            Ok(boxed_feature(stochastic))
        }
        FeatureJson::Atr(atr) => {
            validate_window(atr.window, "window")?;
            Ok(boxed_feature(atr))
        }
        FeatureJson::Roc(roc) => {
            validate_window(roc.window, "window")?;
            Ok(boxed_feature(roc))
        }
        FeatureJson::Momentum(momentum) => {
            validate_window(momentum.window, "window")?;
            Ok(boxed_feature(momentum))
        }
        FeatureJson::DonchianChannel(donchian) => {
            validate_window(donchian.window, "window")?;
            Ok(boxed_feature(donchian))
        }
        FeatureJson::Cci(cci) => {
            validate_window(cci.window, "window")?;
            Ok(boxed_feature(cci))
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

pub fn parse_feats(json_values: &[Value]) -> Result<Vec<Box<dyn Feature>>, String> {
    let feats = json_values.iter().map(parse_feat).collect::<Result<Vec<Box<dyn Feature>>, String>>()?;
    validate_feat_ids(&feats)?;

    Ok(feats)
}
