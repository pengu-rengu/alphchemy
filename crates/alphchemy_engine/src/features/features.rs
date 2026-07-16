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

    fn sum_diff_squared(&self, values: &[f64], mean: f64) -> f64 {
        values.iter().map(|value| {
            (value - mean).powi(2)
        }).sum::<f64>()
    }

    fn std_dev(&self, values: &[f64]) -> f64 {
        FeatureDepsImpl._std_dev(&FeatureDepsImpl, values)
    }

    fn rolling_std(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl._rolling_std(&FeatureDepsImpl, values, window)
    }

    fn rolling_min(&self, values: &[f64], window: usize) -> Vec<f64> {
        let mut result = vec![0.0; values.len()];

        for i in 0..values.len() {
            if i + 1 < window {
                continue;
            }

            result[i] = *values[i + 1 - window..=i].iter().min_by(|a, b| {
                a.total_cmp(b)
            }).unwrap();
        }

        result
    }

    fn rolling_max(&self, values: &[f64], window: usize) -> Vec<f64> {
        let mut result = vec![0.0; values.len()];

        for i in 0..values.len() {
            if i + 1 < window {
                continue;
            }

            result[i] = *values[i + 1 - window..=i].iter().max_by(|a, b| {
                a.total_cmp(b)
            }).unwrap();
        }

        result
    }

    fn ema_seed(&self, values: &[f64], window: usize) -> f64 {
        values[0..window].iter().sum::<f64>() / window as f64
    }

    fn calculate_ema(&self, prev: f64, value: f64, alpha: f64) -> f64 {
        let weighted_prev = prev * (1.0 - alpha);
        let weighted_curr = value * alpha;
        weighted_curr + weighted_prev
    }

    fn ema(&self, values: &[f64], window: usize, smooth: usize) -> Vec<f64> {
        FeatureDepsImpl._ema(&FeatureDepsImpl, values, window, smooth)
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

     fn _std_dev<T>(&self, deps: &T, values: &[f64]) -> f64 where T: FeatureDeps {
        if values.len() < 2 {
            return 0.0;
        }

        let count = values.len() as f64;
        let mean = values.iter().sum::<f64>() / count;

        let sum_diff_squared = deps.sum_diff_squared(values, mean);
        (sum_diff_squared / count).sqrt()
    }

    fn _rolling_std<T>(&self, deps: &T, values: &[f64], window: usize) -> Vec<f64> where T: FeatureDeps {
        let mut result = vec![0.0; values.len()];

        for i in 0..values.len() {
            if i + 1 < window {
                continue;
            }

            result[i] = deps.std_dev(&values[i + 1 - window..=i]);

        }

        result
    }

    fn _ema<T>(&self, deps: &T, values: &[f64], window: usize, smooth: usize) -> Vec<f64> where T: FeatureDeps {
        let mut result = vec![0.0; values.len()];
        let mut prev = deps.ema_seed(values, window);

        let window_factor = window as f64 + 1.0;
        let alpha = smooth as f64 / window_factor;

        for i in window..values.len() {
            prev = deps.calculate_ema(prev, values[i], alpha);
            result[i] = prev;
        }

        result
    }

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
        let len = data.values().next().map_or(0, |value| value.len());
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

#[cfg_attr(test, automock)]
trait RawReturnsDeps {
    fn safe_divide(&self, a: f64, b: f64) -> f64 {
        FeatureDepsImpl.safe_divide(a, b)
    }

    fn calculate_return(&self, feature: &RawReturns, price_ratio: f64) -> f64 {
        match feature.returns_type {
            ReturnsType::Log => price_ratio.ln(),
            ReturnsType::Simple => price_ratio - 1.0
        }
    }
}
struct RawReturnsDepsImpl;
impl RawReturnsDeps for RawReturnsDepsImpl {}

impl RawReturns {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: RawReturnsDeps {
        let prices = &data[self.ohlc.to_str()];
        let mut returns = vec![0.0; prices.len()];

        for i in 1..prices.len() {
            let price_ratio = deps.safe_divide(prices[i], prices[i - 1]);
            returns[i] = deps.calculate_return(self, price_ratio);
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
    use super::*;
    use approx::assert_relative_eq;
    use hegel::TestCase;
    use hegel::generators::sampled_from;
    use mockall::predicate::{always, eq};
    use crate::{
        features::indicators::tests::{gen_atr, gen_bb, gen_dc, gen_ema, gen_macd, gen_roc, gen_rsi, gen_sma, gen_stochastic},
        test_utils::{gen_f64, gen_usize_with_max, gen_usize_with_min, gen_vec, gen_text}
    };
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

    #[hegel::composite]
    pub fn gen_ohlc_data(tc: TestCase, min_len: usize) -> HashMap<String, Vec<f64>> {
        let len = tc.draw(gen_usize_with_min(min_len));

        let open = tc.draw(gen_vec(gen_f64(), len));
        let high = tc.draw(gen_vec(gen_f64(), len));
        let low = tc.draw(gen_vec(gen_f64(), len));
        let close = tc.draw(gen_vec(gen_f64(), len));

        HashMap::from([
            ("open".to_string(), open),
            ("close".to_string(), close),
            ("high".to_string(), high),
            ("low".to_string(), low)
        ])
    }

    #[hegel::composite]
    pub fn gen_ohlc(tc: TestCase) -> OHLC {
        tc.draw(sampled_from(vec![OHLC::Open, OHLC::High, OHLC::Low, OHLC::Close]))
    }

    #[hegel::composite]
    pub fn gen_id(tc: TestCase, id: Option<String>) -> String {
        let id = id.clone();

        match id {
            Some(id) => id,
            None => tc.draw(gen_text())
        }
    }

    #[hegel::composite]
    fn gen_constant(tc: TestCase, id: Option<String>) -> Constant {
        let id = tc.draw(gen_id(id.clone()));
        Constant { id, constant: tc.draw(gen_f64()) }
    }

    #[hegel::composite]
    fn gen_raw_returns(tc: TestCase, id: Option<String>) -> RawReturns {
        let id = tc.draw(gen_id(id.clone()));
        let returns_type = tc.draw(sampled_from(vec![ReturnsType::Log, ReturnsType::Simple]));
        RawReturns { id, returns_type, ohlc: tc.draw(gen_ohlc()) }
    }

    #[hegel::composite]
    fn gen_feat(tc: TestCase, id: Option<String>, len: Option<usize>) -> Feature {
        let id = id.clone();
        let variant = tc.draw(gen_usize_with_max(10));

        match variant {
            0 => {
                let feat = tc.draw(gen_constant(id));
                Feature::Constant(feat)
            }
            1 => {
                let feat = tc.draw(gen_raw_returns(id));
                Feature::RawReturns(feat)
            }
            2 => {
                let feat = tc.draw(gen_sma(id, len));
                Feature::NormalizedSMA(feat)
            }
            3 => {
                let feat = tc.draw(gen_ema(id, len));
                Feature::NormalizedEMA(feat)
            }
            4 => {
                let feat = tc.draw(gen_macd(id, len));
                Feature::NormalizedMACD(feat)
            }
            5 => {
                let feat = tc.draw(gen_rsi(id, len));
                Feature::RSI(feat)
            }
            6 => {
                let feat = tc.draw(gen_bb(id, len));
                Feature::NormalizedBB(feat)
            }
            7 => {
                let feat = tc.draw(gen_stochastic(id, len));
                Feature::Stochastic(feat)
            }
            8 => {
                let feat = tc.draw(gen_atr(id, len));
                Feature::NormalizedATR(feat)
            }
            9 => {
                let feat = tc.draw(gen_roc(id, len));
                Feature::ROC(feat)
            }
            10 => {
                let feat = tc.draw(gen_dc(id, len));
                Feature::NormalizedDC(feat)
            }
            _ => panic!("invalid feature variant: {variant}")
        }
    }

    #[hegel::composite]
    pub fn gen_feats(tc: TestCase, n_feats: usize, len: Option<usize>) -> Vec<Feature> {
        let mut feats = Vec::new();

        for i in 0..n_feats {
            let indexed_id = format!("{}{}", tc.draw(gen_text()), i);
            let feat = tc.draw(gen_feat(Some(indexed_id), len));
            feats.push(feat);
        }

        feats
    }

    #[hegel::test]
    fn test_ohlc_to_str(tc: TestCase) {
        let ohlc = tc.draw(gen_ohlc());

        let expected = match ohlc {
            OHLC::Open => "open",
            OHLC::High => "high",
            OHLC::Low => "low",
            OHLC::Close => "close"
        };

        assert_eq!(ohlc.to_str(), expected);
    }

    #[hegel::test]
    fn test_constant_calculate_values(tc: TestCase) {
        let feat_table = tc.draw(gen_feat_table());
        let constant = tc.draw(gen_f64());
        let feature = Constant { id: tc.draw(gen_text()), constant };

        let values = feature.calculate_values(&feat_table.table);

        assert_eq!(values, vec![constant; feat_table.timestamps.len()]);
    }

    #[hegel::test]
    fn test_calculate_return(tc: TestCase) {
        let feature = tc.draw(gen_raw_returns(None));
        let price_ratio = tc.draw(gen_f64()) + 1.0;

        let value = RawReturnsDepsImpl.calculate_return(&feature, price_ratio);

        let expected = match feature.returns_type {
            ReturnsType::Log => price_ratio.ln(),
            ReturnsType::Simple => price_ratio - 1.0
        };

        assert_relative_eq!(value, expected, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_raw_returns_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_raw_returns(None));
        let data = tc.draw(gen_ohlc_data(1));
        let len = data["close"].len();

        let price_ratio = tc.draw(gen_f64());
        let return_value = tc.draw(gen_f64());

        let mut mock_deps = MockRawReturnsDeps::new();

        let safe_divide_dep = mock_deps.expect_safe_divide().times(len - 1);
        let safe_divide_dep = safe_divide_dep.with(always(), always());
        safe_divide_dep.return_const(price_ratio);

        let eq_price_ratio = eq(price_ratio);

        let calculate_return_dep = mock_deps.expect_calculate_return().times(len - 1);
        let calculate_return_dep = calculate_return_dep.with(always(), eq_price_ratio);
        calculate_return_dep.return_const(return_value);

        let values = feature._calculate_values(&mock_deps, &data);

        let mut expected_values = vec![return_value; len];
        expected_values[0] = 0.0;

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_rolling_mean(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let window = tc.draw(gen_usize_with_max(len - 1)) + 1;

        let result = FeatureDepsImpl.rolling_mean(&values, window);

        let window_size = window as f64;
        for i in 0..len {
            if i + 1 < window {
                assert_eq!(result[i], 0.0);
            } else {
                assert_relative_eq!(result[i], values[i + 1 - window..=i].iter().sum::<f64>() / window_size, epsilon = 1e-5);
            }
        }
    }

    #[hegel::test]
    fn test_sum_diff_squared(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let mean = tc.draw(gen_f64());

        let sum_diff_squared = FeatureDepsImpl.sum_diff_squared(&values, mean);

        let expected = values.iter().map(|value| {
            (value - mean).powi(2)
        }).sum::<f64>();

        assert_relative_eq!(sum_diff_squared, expected, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_std_dev(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(2));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let sum_diff_squared = tc.draw(gen_f64());
        let count = len as f64;

        let mut mock_deps = MockFeatureDeps::new();

        let eq_values = eq(values.clone());
        let eq_mean = eq(values.iter().sum::<f64>() / count);

        let sum_diff_squared_dep = mock_deps.expect_sum_diff_squared().times(1);
        let sum_diff_squared_dep = sum_diff_squared_dep.with(eq_values, eq_mean);
        sum_diff_squared_dep.return_const(sum_diff_squared);

        let value = FeatureDepsImpl._std_dev(&mock_deps, &values);
        let short_value = FeatureDepsImpl._std_dev(&mock_deps, &values[0..1]);

        assert_relative_eq!(value, (sum_diff_squared / count).sqrt(), epsilon = 1e-5);
        assert_eq!(short_value, 0.0);
    }

    #[hegel::test]
    fn test_rolling_std(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let window = tc.draw(gen_usize_with_max(len - 1)) + 1;
        let std_value = tc.draw(gen_f64());

        let mut mock_deps = MockFeatureDeps::new();

        let std_dev_dep = mock_deps.expect_std_dev().times(len + 1 - window);
        let std_dev_dep = std_dev_dep.with(always());
        std_dev_dep.return_const(std_value);

        let result = FeatureDepsImpl._rolling_std(&mock_deps, &values, window);

        for (i, value) in result.iter().enumerate() {
            if i + 1 < window {
                assert_eq!(*value, 0.0);
            } else {
                assert_eq!(*value, std_value);
            }
        }
    }

    #[hegel::test]
    fn test_rolling_min(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let window = tc.draw(gen_usize_with_max(len - 1)) + 1;

        let result = FeatureDepsImpl.rolling_min(&values, window);

        for i in 0..len {
            if i + 1 < window {
                assert_eq!(result[i], 0.0);
            } else {
                let window_min = values[i + 1 - window..=i].iter().copied().fold(f64::INFINITY, f64::min);
                assert_eq!(result[i], window_min);
            }
        }
    }

    #[hegel::test]
    fn test_rolling_max(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let window = tc.draw(gen_usize_with_max(len - 1)) + 1;

        let result = FeatureDepsImpl.rolling_max(&values, window);

        for i in 0..len {
            if i + 1 < window {
                assert_eq!(result[i], 0.0);
            } else {
                let window_max = values[i + 1 - window..=i].iter().copied().fold(f64::NEG_INFINITY, f64::max);
                assert_eq!(result[i], window_max);
            }
        }
    }

    #[hegel::test]
    fn test_ema_seed(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let window = tc.draw(gen_usize_with_max(len - 1)) + 1;

        let seed = FeatureDepsImpl.ema_seed(&values, window);
        
        assert_relative_eq!(seed, values[0..window].iter().sum::<f64>() / window as f64, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_calculate_ema(tc: TestCase) {
        let prev = tc.draw(gen_f64());
        let value = tc.draw(gen_f64());
        let alpha = tc.draw(gen_f64());

        let ema_value = FeatureDepsImpl.calculate_ema(prev, value, alpha);

        let weighted_prev = prev * (1.0 - alpha);
        let weighted_curr = value * alpha;
        assert_relative_eq!(ema_value, weighted_curr + weighted_prev, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_ema(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let window = tc.draw(gen_usize_with_max(len - 1)) + 1;
        let smooth = tc.draw(gen_usize_with_min(1));
        let seed = tc.draw(gen_f64());
        let ema_value = tc.draw(gen_f64());

        let window_factor = window as f64 + 1.0;
        let smooth_factor = smooth as f64;

        let mut mock_deps = MockFeatureDeps::new();

        let eq_values = eq(values.clone());
        let eq_window = eq(window);

        let ema_seed_dep = mock_deps.expect_ema_seed().times(1);
        let ema_seed_dep = ema_seed_dep.with(eq_values, eq_window);
        ema_seed_dep.return_const(seed);

        let eq_alpha = eq(smooth_factor / window_factor);

        let calculate_ema_dep = mock_deps.expect_calculate_ema().times(len - window);
        let calculate_ema_dep = calculate_ema_dep.with(always(), always(), eq_alpha);
        calculate_ema_dep.return_const(ema_value);

        let result = FeatureDepsImpl._ema(&mock_deps, &values, window, smooth);

        for (i, value) in result.iter().enumerate() {
            if i < window {
                assert_eq!(*value, 0.0);
            } else {
                assert_eq!(*value, ema_value);
            }
        }
    }

    #[hegel::test]
    fn test_safe_divide(tc: TestCase) {
        let numerator = tc.draw(gen_f64());
        let denominator = tc.draw(gen_f64()) + 1e-5;

        let quotient = FeatureDepsImpl.safe_divide(numerator, denominator);

        assert_relative_eq!(quotient, numerator / denominator, epsilon = 1e-5);
        assert_eq!(FeatureDepsImpl.safe_divide(numerator, 0.0), 0.0);
    }

    #[hegel::test]
    fn test_normalize(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let values = tc.draw(gen_vec(gen_f64(), len));
        let original = tc.draw(gen_vec(gen_f64(), len));
        let quotient = tc.draw(gen_f64());

        let mut mock_deps = MockFeatureDeps::new();

        let safe_divide_dep = mock_deps.expect_safe_divide().times(len);
        let safe_divide_dep = safe_divide_dep.with(always(), always());
        safe_divide_dep.return_const(quotient);

        let result = FeatureDepsImpl._normalize(&mock_deps, &values, &original);

        assert_eq!(result, vec![quotient; len]);
    }

    #[hegel::test]
    fn test_feature_calculate_values(tc: TestCase) {
        let data = tc.draw(gen_ohlc_data(1));
        let len = data["close"].len();
        let feature = tc.draw(gen_feat(None, Some(len)));

        let values = feature.calculate_values(&data);

        let expected = match &feature {
            Feature::Constant(feat) => feat.calculate_values(&data),
            Feature::RawReturns(feat) => feat.calculate_values(&data),
            Feature::NormalizedSMA(feat) => feat.calculate_values(&data),
            Feature::NormalizedEMA(feat) => feat.calculate_values(&data),
            Feature::NormalizedMACD(feat) => feat.calculate_values(&data),
            Feature::RSI(feat) => feat.calculate_values(&data),
            Feature::NormalizedBB(feat) => feat.calculate_values(&data),
            Feature::Stochastic(feat) => feat.calculate_values(&data),
            Feature::NormalizedATR(feat) => feat.calculate_values(&data),
            Feature::ROC(feat) => feat.calculate_values(&data),
            Feature::NormalizedDC(feat) => feat.calculate_values(&data)
        };

        assert_eq!(values, expected);
    }

    #[hegel::test]
    fn test_feat_table(tc: TestCase) {
        let table = tc.draw(gen_ohlc_data(1));
        let len = table["close"].len();
        let timestamps = tc.draw(gen_vec(gen_text(), len));
        let data = TimestampedTable { timestamps, table };

        let n_feats = tc.draw(gen_usize_with_max(9)) + 1;
        let feats = tc.draw(gen_feats(n_feats, Some(len)));

        let result = feat_table(&feats, &data);

        assert_eq!(result.timestamps, data.timestamps);
        assert_eq!(result.table.len(), feats.len());
        for feat in &feats {
            assert_eq!(result.table[&feat.id()], feat.calculate_values(&data.table));
        }
    }
}
