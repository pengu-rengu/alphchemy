use std::collections::HashMap;
use serde::Serialize;
#[cfg(test)]
use mockall::automock;

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

#[derive(Debug)]
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

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "feature")]
pub enum Feature {
    #[serde(rename = "constant")] Constant(Constant),
    #[serde(rename = "raw_returns")] RawReturns(RawReturns),
    #[serde(rename = "normalized_sma")] NormalizedSMA(NormalizedSMA),
    #[serde(rename = "normalized_ema")] NormalizedEMA(NormalizedEMA),
    #[serde(rename = "normalized_macd")] NormalizedMACD(NormalizedMACD),
    #[serde(rename = "rsi")] RSI(RSI),
    #[serde(rename = "normalized_bb")] NormalizedBB(NormalizedBB),
    #[serde(rename = "stochastic")] Stochastic(Stochastic),
    #[serde(rename = "normalized_atr")] NormalizedATR(NormalizedATR),
    #[serde(rename = "roc")] ROC(ROC),
    #[serde(rename = "normalized_dc")] NormalizedDC(NormalizedDC)
}

impl Feature {
    pub fn id(&self) -> String {
        match self {
            Feature::Constant(feat) => feat.id.clone(),
            Feature::RawReturns(feat) => feat.id.clone(),
            Feature::NormalizedSMA(feat) => feat.id.clone(),
            Feature::NormalizedEMA(feat) => feat.id.clone(),
            Feature::NormalizedMACD(feat) => feat.id.clone(),
            Feature::RSI(feat) => feat.id.clone(),
            Feature::NormalizedBB(feat) => feat.id.clone(),
            Feature::Stochastic(feat) => feat.id.clone(),
            Feature::NormalizedATR(feat) => feat.id.clone(),
            Feature::ROC(feat) => feat.id.clone(),
            Feature::NormalizedDC(feat) => feat.id.clone()
        }
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        match self {
            Feature::Constant(feat) => feat.calculate_values(data),
            Feature::RawReturns(feat) => feat.calculate_values(data),
            Feature::NormalizedSMA(feat) => feat.calculate_values(data),
            Feature::NormalizedEMA(feat) => feat.calculate_values(data),
            Feature::NormalizedMACD(feat) => feat.calculate_values(data),
            Feature::RSI(feat) => feat.calculate_values(data),
            Feature::NormalizedBB(feat) => feat.calculate_values(data),
            Feature::Stochastic(feat) => feat.calculate_values(data),
            Feature::NormalizedATR(feat) => feat.calculate_values(data),
            Feature::ROC(feat) => feat.calculate_values(data),
            Feature::NormalizedDC(feat) => feat.calculate_values(data)
        }
    }
}

#[cfg_attr(test, automock)]
pub trait FeatureDeps {
    fn rolling_mean(&self, values: &[f64], window: usize) -> Vec<f64> {
        let mut result = vec![0.0; values.len()];
        let mut sum = 0.0;

        for i in 0..values.len() {
            sum += values[i];

            if i >= window {
                sum -= values[i - window];
            }

            if i + 1 >= window {
                result[i] = sum / window as f64;
            }
        }

        result
    }

    fn diff_squared(&self, values: &[f64], means: &[f64], value_idx: usize, mean_idx: usize) -> f64 {
        (values[value_idx] - means[mean_idx]).powi(2)
    }

    fn std_dev(values: &[f64]) -> f64 {
        if values.len() < 2 {
            return 0.0;
        }

        let count = values.len() as f64;
        let mean = values.iter().sum::<f64>() / count;

        let squared_diff_sum = values.iter().map(|value| {
            (value - mean).powi(2)
        }).sum::<f64>();

        (squared_diff_sum / count).sqrt()
    }

    fn rolling_std(&self, values: &[f64], means: &[f64], window: usize) -> Vec<f64> {
        let mut result = vec![0.0; values.len()];

        for i in 0..values.len() {
            if i + 1 < window {
                continue;
            }

            let diff_squared = |idx: usize| (values[idx] - means[i]).powi(2);
            let variance = (i + 1 - window..=i).map(diff_squared).sum::<f64>();
            result[i] = (variance / window as f64).sqrt();
            
        }

        result
    }

    fn rolling_min(&self, values: &[f64], window: usize) -> Vec<f64> {
        let mut result = vec![0.0; values.len()];

        for i in 0..values.len() {
            if i + 1 < window {
                continue;
            }

            let start_idx = i + 1 - window;
            let mut min_value = values[start_idx];

            for idx in start_idx..=i {
                let value = values[idx];
                if value < min_value {
                    min_value = value;
                }
            }

            result[i] = min_value;
        }

        result
    }

    fn rolling_max(&self, values: &[f64], window: usize) -> Vec<f64> {
        let mut result = vec![0.0; values.len()];

        for i in 0..values.len() {
            if i + 1 < window {
                continue;
            }

            let start_idx = i + 1 - window;
            let mut max_value = values[start_idx];

            for idx in start_idx..=i {
                let value = values[idx];
                if value > max_value {
                    max_value = value;
                }
            }

            result[i] = max_value;
        }

        result
    }


    fn ema(&self, values: &[f64], window: usize, smooth: usize) -> Vec<f64> {
        let mut result = vec![0.0; values.len()];
        let mut prev = values[0..window].iter().sum::<f64>() / window as f64;

        let window_factor = window as f64 + 1.0;
        let alpha = smooth as f64 / window_factor;

        for i in window..values.len() {

            let weighted_prev = prev * (1.0 - alpha);
            let weighted_curr = values[i] * alpha;

            prev = weighted_curr + weighted_prev;
            result[i] = prev;
        }

        result
    }

    fn safe_divide(&self, a: f64, b: f64) -> f64 {
        if b == 0.0 {
            return 0.0;
        }

        a / b
    }

    fn normalize(&self, values: &[f64], original: &[f64]) -> Vec<f64> {
        FeatureDepsImpl._normalize(&FeatureDepsImpl, values, original)
    }
    
}
pub struct FeatureDepsImpl;
impl FeatureDeps for FeatureDepsImpl {}

impl FeatureDepsImpl {
    fn _normalize<T>(&self, deps: &T, values: &[f64], original: &[f64]) -> Vec<f64> where T: FeatureDeps {
        (0..values.len()).map(|idx: usize| {
            deps.safe_divide(values[idx], original[idx])
        }).collect()
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct Constant {
    pub id: String,
    pub constant: f64
}

impl Constant {
    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
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

trait RawReturnsDeps: FeatureDeps {
    fn calculate_return(&self, feature: &RawReturns, price_ratio: f64) -> f64 {
        match feature.returns_type {
            ReturnsType::Log => price_ratio.ln(),
            ReturnsType::Simple => price_ratio - 1.0
        }
    }
}
struct RawReturnsDepsImpl;
impl RawReturnsDeps for RawReturnsDepsImpl {}
impl FeatureDeps for RawReturnsDepsImpl {}

impl RawReturns {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: RawReturnsDeps {
        let prices = &data[self.ohlc.to_str()];
        let mut returns = vec![0.0; prices.len()];

        for i in 1..prices.len() {
            let price_ratio = deps.safe_divide(prices[i], prices[i - 1]);
            returns[i] = deps.calculate_return(&self, price_ratio);
        }

        returns
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&RawReturnsDepsImpl, data)
    }
}

pub fn feat_ids(feats: &[Feature]) -> Vec<String> {
    feats.iter().map(|feat| feat.id()).collect()
}

pub fn feat_table(feats: &[Feature], data: &TimestampedTable) -> TimestampedTable {
    let mut table = HashMap::new();

    for feat in feats {
        let feat_id = feat.id();
        let values = feat.calculate_values(&data.table);
        table.insert(feat_id, values);
    }

    TimestampedTable { timestamps: data.timestamps.clone(), table }
}


#[cfg(test)]
pub mod tests {
    use hegel::TestCase;
    use crate::features::features::TimestampedTable;
    use crate::test_utils::{gen_f64, gen_usize_with_max, gen_usize_with_min, gen_vec, gen_text};
    use std::collections::HashMap;

    #[hegel::composite]
    pub fn gen_feat_table(tc: TestCase) -> TimestampedTable {
        let length = tc.draw(gen_usize_with_min(1));
        let timestamps = tc.draw(gen_vec(gen_text(), length));
        
        let mut table = HashMap::<String, Vec<f64>>::new();
        for _ in 0..tc.draw(gen_usize_with_max(9)) + 1 {
            let values = tc.draw(gen_vec(gen_f64(), length));
            table.insert(tc.draw(gen_text()), values);
        }

        TimestampedTable { timestamps, table }
    }


}
