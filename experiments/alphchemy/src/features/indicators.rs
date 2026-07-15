use std::collections::HashMap;
use serde::Serialize;
use super::features::{OHLC, FeatureDeps, FeatureDepsImpl};
#[cfg(test)]
use mockall::automock;


#[derive(Clone, Debug, Serialize)]
pub struct NormalizedSMA {
    pub id: String,
    pub window: usize,
    pub ohlc: OHLC
}

impl NormalizedSMA {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: FeatureDeps {
        let prices = &data[self.ohlc.to_str()];
        let means = deps.rolling_mean(prices, self.window);

        deps.normalize(&means, prices)
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&FeatureDepsImpl, data)
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct NormalizedEMA {
    pub id: String,
    pub window: usize,
    pub smooth: usize,
    pub ohlc: OHLC
}

impl NormalizedEMA {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: FeatureDeps {
        let prices = &data[self.ohlc.to_str()];
        let ema_values = deps.ema(prices, self.window, self.smooth);

        deps.normalize(&ema_values, prices)
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&FeatureDepsImpl, data)
    }
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum MACDOutput {
    Line,
    Signal,
    Hist
}

#[derive(Clone, Debug, Serialize)]
pub struct NormalizedMACD {
    pub id: String,
    pub fast_window: usize,
    pub fast_smooth: usize,
    pub slow_window: usize,
    pub slow_smooth: usize,
    pub signal_window: usize,
    pub signal_smooth: usize,
    pub output: MACDOutput,
    pub ohlc: OHLC
}

#[cfg_attr(test, automock)]
trait MACDDeps {
    fn ema(&self, values: &[f64], window: usize, smooth: usize) -> Vec<f64> {
        FeatureDepsImpl.ema(values, window, smooth)
    }

    fn normalize(&self, values: &[f64], original: &[f64]) -> Vec<f64> {
        FeatureDepsImpl.normalize(values, original)
    }

    fn line(&self, fast: &[f64], slow: &[f64]) -> Vec<f64> {
        (0..fast.len()).map(|idx| fast[idx] - slow[idx]).collect()
    }

    fn hist(&self, line: &[f64], signal: &[f64]) -> Vec<f64> {
        (0..line.len()).map(|idx| line[idx] - signal[idx]).collect()
    }
}

struct MACDDepsImpl;
impl MACDDeps for MACDDepsImpl {}

impl NormalizedMACD {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: MACDDeps {
        let prices = &data[self.ohlc.to_str()];

        let fast = deps.ema(prices, self.fast_window, self.fast_smooth);
        let slow = deps.ema(prices, self.slow_window, self.slow_smooth);

        let line = deps.line(&fast, &slow);
        let signal = deps.ema(&line, self.signal_window, self.signal_smooth);
        let hist = deps.hist(&line, &signal);

        match self.output {
            MACDOutput::Line => deps.normalize(&line, prices),
            MACDOutput::Signal => deps.normalize(&signal, prices),
            MACDOutput::Hist => deps.normalize(&hist, prices)
        }
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&MACDDepsImpl, data)
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct RSI {
    pub id: String,
    pub window: usize,
    pub smooth: usize,
    pub ohlc: OHLC
}

#[cfg_attr(test, automock)]
trait RSIDeps {
    fn safe_divide(&self, a: f64, b: f64) -> f64 {
        FeatureDepsImpl.safe_divide(a, b)
    }

    fn ema(&self, values: &[f64], window: usize, smooth: usize) -> Vec<f64> {
        FeatureDepsImpl.ema(values, window, smooth)
    }

    fn gains(&self, prices: &[f64]) -> Vec<f64>{
        let mut gains = vec![0.0; prices.len()];
        for i in 1..prices.len() {
            gains[i] = (prices[i] - prices[i - 1]).max(0.0);
        }
        gains
    }

    fn losses(&self, prices: &[f64]) -> Vec<f64> {
        let mut losses = vec![0.0; prices.len()];
        for i in 1..prices.len() {
            losses[i] = (-(prices[i] - prices[i - 1])).max(0.0);
        }
        losses
    }

    fn rsi(&self, gain: f64, loss: f64) -> f64 {
        let relative_strength = self.safe_divide(gain, loss);
        let reciprocal = self.safe_divide(100.0, 1.0 + relative_strength);
        100.0 - reciprocal
    }
}

struct RSIDepsImpl;
impl RSIDeps for RSIDepsImpl {}

impl RSI {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: RSIDeps {
        let prices = &data[self.ohlc.to_str()];
        let gains = deps.gains(prices);
        let losses = deps.losses(prices);

        let ema_gains = deps.ema(&gains, self.window, self.smooth);
        let ema_losses = deps.ema(&losses, self.window, self.smooth);
        let mut result = vec![0.0; prices.len()];

        for i in 0..prices.len() {
            result[i] = deps.rsi(ema_gains[i], ema_losses[i]);
        }

        result
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&RSIDepsImpl, data)
    }
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum BBOutput {
    Upper,
    Lower,
    Width
}

#[derive(Clone, Debug, Serialize)]
pub struct NormalizedBB {
    pub id: String,
    pub window: usize,
    pub std_multiplier: f64,
    pub output: BBOutput,
    pub ohlc: OHLC
}

#[cfg_attr(test, automock)]
trait BBDeps {
    fn rolling_mean(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl.rolling_mean(values, window)
    }

    fn rolling_std(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl.rolling_std(values, window)
    }

    fn normalize(&self, values: &[f64], original: &[f64]) -> Vec<f64> {
        FeatureDepsImpl.normalize(values, original)
    }

    fn output(&self, feature: &NormalizedBB, mean: f64, dev: f64) -> f64 {
        let half_width = feature.std_multiplier * dev;

        match feature.output {
            BBOutput::Upper => mean + half_width,
            BBOutput::Lower => mean - half_width,
            BBOutput::Width => 2.0 * half_width
        }
    }
}

struct BBDepsImpl;
impl BBDeps for BBDepsImpl {}

impl NormalizedBB {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: BBDeps {
        let prices = &data[self.ohlc.to_str()];
        let means = deps.rolling_mean(prices, self.window);
        let devs = deps.rolling_std(prices, self.window);
        let mut result = vec![0.0; prices.len()];

        for i in 0..prices.len() {
            result[i] = deps.output(self, means[i], devs[i]);
        }

        deps.normalize(&result, prices)
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&BBDepsImpl, data)
    }
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum StochasticOutput {
    PercentK,
    PercentD
}

#[derive(Clone, Debug, Serialize)]
pub struct Stochastic {
    pub id: String,
    pub window: usize,
    pub smooth_window: usize,
    pub output: StochasticOutput
}

#[cfg_attr(test, automock)]
trait StochasticDeps {
    fn safe_divide(&self, a: f64, b: f64) -> f64 {
        FeatureDepsImpl.safe_divide(a, b)
    }

    fn rolling_max(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl.rolling_max(values, window)
    }

    fn rolling_min(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl.rolling_min(values, window)
    }

    fn rolling_mean(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl.rolling_mean(values, window)
    }

    fn percent_k(&self, feat: &Stochastic, high_max: f64, low_min: f64, close: f64) -> f64 {
        feat._percent_k(&StochasticDepsImpl, high_max, low_min, close)
    }
}

struct StochasticDepsImpl;
impl StochasticDeps for StochasticDepsImpl {}

impl Stochastic {
    fn _percent_k<T>(&self, deps: &T, high_max: f64, low_min: f64, close: f64) -> f64 where T: StochasticDeps {
        100.0 * deps.safe_divide(close - low_min, high_max - low_min)
    }

    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: StochasticDeps {
        let close = &data["close"];
        let high_max = deps.rolling_max(&data["high"], self.window);
        let low_min = deps.rolling_min(&data["low"], self.window);
        let mut percent_k = vec![0.0; close.len()];

        for i in 0..close.len() {
            percent_k[i] = deps.percent_k(self, high_max[i], low_min[i], close[i])
        }

        match self.output {
            StochasticOutput::PercentK => percent_k,
            StochasticOutput::PercentD => deps.rolling_mean(&percent_k, self.smooth_window)
        }
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&StochasticDepsImpl, data)
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct NormalizedATR {
    pub id: String,
    pub window: usize,
    pub smooth: usize
}

#[cfg_attr(test, automock)]
trait ATRDeps {
    fn ema(&self, values: &[f64], window: usize, smooth: usize) -> Vec<f64> {
        FeatureDepsImpl.ema(values, window, smooth)
    }

    fn normalize(&self, values: &[f64], original: &[f64]) -> Vec<f64> {
        FeatureDepsImpl.normalize(values, original)
    }

    fn true_range(&self, high: f64, low: f64, maybe_prev_close: Option<f64>) -> f64 {
        let high_low_range = high - low;

        if let Some(prev_close) = maybe_prev_close {
            [high_low_range, (high - prev_close).abs(), (low - prev_close).abs()].iter().copied().fold(f64::NEG_INFINITY, f64::max)
        } else {
            high_low_range
        }
    }
}

struct ATRDepsImpl;
impl ATRDeps for ATRDepsImpl {}

impl NormalizedATR {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: ATRDeps {
        let high = &data["high"];
        let low = &data["low"];
        let close = &data["close"];
        let mut true_ranges = vec![0.0; close.len()];

        for i in 0..close.len() {
            true_ranges[i] = deps.true_range(high[i], low[i], if i == 0 { None } else { Some(close[i - 1]) } );
        }

        let result = deps.ema(&true_ranges, self.window, self.smooth);

        deps.normalize(&result, close)
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&ATRDepsImpl, data)
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct ROC {
    pub id: String,
    pub window: usize,
    pub ohlc: OHLC
}

impl ROC {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: FeatureDeps {
        let prices = &data[self.ohlc.to_str()];
        let len = prices.len();
        let mut result = vec![0.0; len];

        for i in self.window..len {
            result[i] = deps.safe_divide(prices[i], prices[i - self.window]);
        }

        result
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&FeatureDepsImpl, data)
    }
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum DCOutput {
    Upper,
    Lower,
    Middle,
    Width
}

#[derive(Clone, Debug, Serialize)]
pub struct NormalizedDC {
    pub id: String,
    pub window: usize,
    pub output: DCOutput
}

#[cfg_attr(test, automock)]
trait DCDeps {
    fn rolling_max(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl.rolling_max(values, window)
    }

    fn rolling_min(&self, values: &[f64], window: usize) -> Vec<f64> {
        FeatureDepsImpl.rolling_min(values, window)
    }

    fn normalize(&self, values: &[f64], original: &[f64]) -> Vec<f64> {
        FeatureDepsImpl.normalize(values, original)
    }

    fn output(&self, feature: &NormalizedDC, high_max: f64, low_min: f64) -> f64 {
        match feature.output {
            DCOutput::Upper => high_max,
            DCOutput::Lower => low_min,
            DCOutput::Middle => (low_min + high_max) / 2.0,
            DCOutput::Width => high_max - low_min
        }
    }
}

struct DCDepsImpl;
impl DCDeps for DCDepsImpl {}

impl NormalizedDC {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: DCDeps {
        let close = &data["close"];
        let high_max = deps.rolling_max(&data["high"], self.window);
        let low_min = deps.rolling_min(&data["low"], self.window);
        let mut result = vec![0.0; close.len()];

        for i in 0..close.len() {
            result[i] = deps.output(self, high_max[i], low_min[i]);
        }

        deps.normalize(&result, close)
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&DCDepsImpl, data)
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use hegel::{
        TestCase,
        generators::sampled_from
    };
    use mockall::predicate::{always, eq};
    use crate::{
        features::features::MockFeatureDeps,
        features::features::tests::{gen_id, gen_ohlc, gen_ohlc_data},
        test_utils::{INT_MAX, gen_f64, gen_usize_with_max, gen_usize_with_min, gen_vec}
    };

    #[hegel::composite]
    pub fn gen_sma(tc: TestCase, id: Option<String>, len: Option<usize>) -> NormalizedSMA {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        NormalizedSMA { id, window, ohlc: tc.draw(gen_ohlc()) }
    }

    #[hegel::composite]
    pub fn gen_ema(tc: TestCase, id: Option<String>, len: Option<usize>) -> NormalizedEMA {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        NormalizedEMA {
            id,
            window,
            smooth: tc.draw(gen_usize_with_min(1)),
            ohlc: tc.draw(gen_ohlc())
        }
    }

    #[hegel::composite]
    pub fn gen_macd(tc: TestCase, id: Option<String>, len: Option<usize>) -> NormalizedMACD {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let slow_window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;
        let fast_window = tc.draw(gen_usize_with_max(slow_window - 1)) + 1;
        let signal_window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        NormalizedMACD {
            id,
            fast_window,
            fast_smooth: tc.draw(gen_usize_with_min(1)),
            slow_window,
            slow_smooth: tc.draw(gen_usize_with_min(1)),
            signal_window,
            signal_smooth: tc.draw(gen_usize_with_min(1)),
            output: tc.draw(sampled_from(vec![MACDOutput::Line, MACDOutput::Signal, MACDOutput::Hist])),
            ohlc: tc.draw(gen_ohlc())
        }
    }

    #[hegel::composite]
    pub fn gen_rsi(tc: TestCase, id: Option<String>, len: Option<usize>) -> RSI {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        RSI {
            id,
            window,
            smooth: tc.draw(gen_usize_with_min(1)),
            ohlc: tc.draw(gen_ohlc())
        }
    }

    #[hegel::composite]
    pub fn gen_bb(tc: TestCase, id: Option<String>, len: Option<usize>) -> NormalizedBB {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        NormalizedBB {
            id,
            window,
            std_multiplier: tc.draw(gen_f64()),
            output: tc.draw(sampled_from(vec![BBOutput::Upper, BBOutput::Lower, BBOutput::Width])),
            ohlc: tc.draw(gen_ohlc())
        }
    }

    #[hegel::composite]
    pub fn gen_stochastic(tc: TestCase, id: Option<String>, len: Option<usize>) -> Stochastic {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        Stochastic {
            id,
            window,
            smooth_window: tc.draw(gen_usize_with_min(1)),
            output: tc.draw(sampled_from(vec![StochasticOutput::PercentK, StochasticOutput::PercentD]))
        }
    }

    #[hegel::composite]
    pub fn gen_atr(tc: TestCase, id: Option<String>, len: Option<usize>) -> NormalizedATR {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        NormalizedATR { id, window, smooth: tc.draw(gen_usize_with_min(1)) }
    }

    #[hegel::composite]
    pub fn gen_roc(tc: TestCase, id: Option<String>, len: Option<usize>) -> ROC {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        ROC { id, window, ohlc: tc.draw(gen_ohlc()) }
    }

    #[hegel::composite]
    pub fn gen_dc(tc: TestCase, id: Option<String>, len: Option<usize>) -> NormalizedDC {
        let id = tc.draw(gen_id(id.clone()));
        let max_window = len.unwrap_or(INT_MAX);
        let window = tc.draw(gen_usize_with_max(max_window - 1)) + 1;

        NormalizedDC {
            id,
            window,
            output: tc.draw(sampled_from(vec![DCOutput::Upper, DCOutput::Lower, DCOutput::Middle, DCOutput::Width]))
        }
    }

    #[hegel::test]
    fn test_sma_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_sma(None, None));
        let data = tc.draw(gen_ohlc_data(0));
        let len = data["close"].len();
        let expected_means = tc.draw(gen_vec(gen_f64(), len));
        let expected_values = tc.draw(gen_vec(gen_f64(), len));

        let mut mock_deps = MockFeatureDeps::new();

        let eq_prices = eq(data[feature.ohlc.to_str()].clone());
        let eq_window = eq(feature.window);

        let rolling_mean_dep = mock_deps.expect_rolling_mean().times(1);
        let rolling_mean_dep = rolling_mean_dep.with(eq_prices.clone(), eq_window);
        rolling_mean_dep.return_const(expected_means.clone());

        let eq_expected_means = eq(expected_means);

        let normalize_dep = mock_deps.expect_normalize().times(1);
        let normalize_dep = normalize_dep.with(eq_expected_means, eq_prices);
        normalize_dep.return_const(expected_values.clone());

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_ema_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_ema(None, None));
        let data = tc.draw(gen_ohlc_data(0));
        let len = data["close"].len();
        let expected_ema = tc.draw(gen_vec(gen_f64(), len));
        let expected_values = tc.draw(gen_vec(gen_f64(), len));

        let mut mock_deps = MockFeatureDeps::new();

        let eq_prices = eq(data[feature.ohlc.to_str()].clone());
        let eq_window = eq(feature.window);
        let eq_smooth = eq(feature.smooth);

        let ema_dep = mock_deps.expect_ema().times(1);
        let ema_dep = ema_dep.with(eq_prices.clone(), eq_window, eq_smooth);
        ema_dep.return_const(expected_ema.clone());

        let eq_expected_ema = eq(expected_ema);

        let normalize_dep = mock_deps.expect_normalize().times(1);
        let normalize_dep = normalize_dep.with(eq_expected_ema, eq_prices);
        normalize_dep.return_const(expected_values.clone());

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_macd_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_macd(None, None));
        let data = tc.draw(gen_ohlc_data(0));
        let len = data["close"].len();
        let fast = tc.draw(gen_vec(gen_f64(), len));
        let slow = tc.draw(gen_vec(gen_f64(), len));
        let line = tc.draw(gen_vec(gen_f64(), len));
        let signal = tc.draw(gen_vec(gen_f64(), len));
        let hist = tc.draw(gen_vec(gen_f64(), len));
        let expected_values = tc.draw(gen_vec(gen_f64(), len));

        let mut mock_deps = MockMACDDeps::new();

        let eq_prices = eq(data[feature.ohlc.to_str()].clone());
        let eq_fast_window = eq(feature.fast_window);
        let eq_fast_smooth = eq(feature.fast_smooth);

        let fast_ema_dep = mock_deps.expect_ema().times(1);
        let fast_ema_dep = fast_ema_dep.with(eq_prices.clone(), eq_fast_window, eq_fast_smooth);
        fast_ema_dep.return_const(fast.clone());

        let eq_slow_window = eq(feature.slow_window);
        let eq_slow_smooth = eq(feature.slow_smooth);

        let slow_ema_dep = mock_deps.expect_ema().times(1);
        let slow_ema_dep = slow_ema_dep.with(eq_prices.clone(), eq_slow_window, eq_slow_smooth);
        slow_ema_dep.return_const(slow.clone());

        let eq_fast = eq(fast);
        let eq_slow = eq(slow);

        let line_dep = mock_deps.expect_line().times(1);
        let line_dep = line_dep.with(eq_fast, eq_slow);
        line_dep.return_const(line.clone());

        let eq_line = eq(line.clone());
        let eq_signal_window = eq(feature.signal_window);
        let eq_signal_smooth = eq(feature.signal_smooth);

        let signal_ema_dep = mock_deps.expect_ema().times(1);
        let signal_ema_dep = signal_ema_dep.with(eq_line.clone(), eq_signal_window, eq_signal_smooth);
        signal_ema_dep.return_const(signal.clone());

        let eq_signal = eq(signal.clone());

        let hist_dep = mock_deps.expect_hist().times(1);
        let hist_dep = hist_dep.with(eq_line, eq_signal);
        hist_dep.return_const(hist.clone());

        let normalized_values = match feature.output {
            MACDOutput::Line => line,
            MACDOutput::Signal => signal,
            MACDOutput::Hist => hist
        };

        let eq_normalized_values = eq(normalized_values);

        let normalize_dep = mock_deps.expect_normalize().times(1);
        let normalize_dep = normalize_dep.with(eq_normalized_values, eq_prices);
        normalize_dep.return_const(expected_values.clone());

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_rsi_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_rsi(None, None));
        let data = tc.draw(gen_ohlc_data(0));
        let len = data["close"].len();
        let gains = tc.draw(gen_vec(gen_f64(), len));
        let losses = tc.draw(gen_vec(gen_f64(), len));
        let ema_gains = tc.draw(gen_vec(gen_f64(), len));
        let ema_losses = tc.draw(gen_vec(gen_f64(), len));
        let expected_value = tc.draw(gen_f64());
        let expected_values = vec![expected_value; len];

        let mut mock_deps = MockRSIDeps::new();

        let eq_prices = eq(data[feature.ohlc.to_str()].clone());

        let gains_dep = mock_deps.expect_gains().times(1);
        let gains_dep = gains_dep.with(eq_prices.clone());
        gains_dep.return_const(gains.clone());

        let losses_dep = mock_deps.expect_losses().times(1);
        let losses_dep = losses_dep.with(eq_prices);
        losses_dep.return_const(losses.clone());

        let eq_gains = eq(gains);
        let eq_window = eq(feature.window);
        let eq_smooth = eq(feature.smooth);

        let ema_gains_dep = mock_deps.expect_ema().times(1);
        let ema_gains_dep = ema_gains_dep.with(eq_gains, eq_window, eq_smooth);
        ema_gains_dep.return_const(ema_gains.clone());

        let eq_losses = eq(losses);

        let ema_losses_dep = mock_deps.expect_ema().times(1);
        let ema_losses_dep = ema_losses_dep.with(eq_losses, eq_window, eq_smooth);
        ema_losses_dep.return_const(ema_losses);

        let rsi_dep = mock_deps.expect_rsi().times(len);
        let rsi_dep = rsi_dep.with(always(), always());
        rsi_dep.return_const(expected_value);

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_bb_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_bb(None, None));
        let data = tc.draw(gen_ohlc_data(0));

        let len = data["close"].len();
        let means = tc.draw(gen_vec(gen_f64(), len));
        let devs = tc.draw(gen_vec(gen_f64(), len));
        let expected_output = tc.draw(gen_f64());
        let outputs = vec![expected_output; len];
        let expected_values = tc.draw(gen_vec(gen_f64(), len));

        let mut mock_deps = MockBBDeps::new();

        let eq_prices = eq(data[feature.ohlc.to_str()].clone());
        let eq_window = eq(feature.window);

        let rolling_mean_dep = mock_deps.expect_rolling_mean().times(1);
        let rolling_mean_dep = rolling_mean_dep.with(eq_prices.clone(), eq_window);
        rolling_mean_dep.return_const(means.clone());

        let rolling_std_dep = mock_deps.expect_rolling_std().times(1);
        let rolling_std_dep = rolling_std_dep.with(eq_prices.clone(), eq_window);
        rolling_std_dep.return_const(devs);

        let output_dep = mock_deps.expect_output().times(len);
        let output_dep = output_dep.with(always(), always(), always());
        output_dep.return_const(expected_output);

        let eq_outputs = eq(outputs);

        let normalize_dep = mock_deps.expect_normalize().times(1);
        let normalize_dep = normalize_dep.with(eq_outputs, eq_prices);
        normalize_dep.return_const(expected_values.clone());

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_stochastic_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_stochastic(None, None));
        let data = tc.draw(gen_ohlc_data(0));
        
        let len = data["close"].len();
        let high_max = tc.draw(gen_vec(gen_f64(), len));
        let low_min = tc.draw(gen_vec(gen_f64(), len));
        let expected_percent_k = tc.draw(gen_f64());
        let percent_k = vec![expected_percent_k; len];
        let percent_d = tc.draw(gen_vec(gen_f64(), len));

        let mut mock_deps = MockStochasticDeps::new();

        let eq_high = eq(data["high"].clone());
        let eq_low = eq(data["low"].clone());
        let eq_window = eq(feature.window);

        let rolling_max_dep = mock_deps.expect_rolling_max().times(1);
        let rolling_max_dep = rolling_max_dep.with(eq_high, eq_window);
        rolling_max_dep.return_const(high_max);

        let rolling_min_dep = mock_deps.expect_rolling_min().times(1);
        let rolling_min_dep = rolling_min_dep.with(eq_low, eq_window);
        rolling_min_dep.return_const(low_min);

        let percent_k_dep = mock_deps.expect_percent_k().times(len);
        let percent_k_dep = percent_k_dep.with(always(), always(), always(), always());
        percent_k_dep.return_const(expected_percent_k);

        let expected_values = match feature.output {
            StochasticOutput::PercentK => percent_k,
            StochasticOutput::PercentD => {
                let eq_percent_k = eq(percent_k);
                let eq_smooth_window = eq(feature.smooth_window);

                let rolling_mean_dep = mock_deps.expect_rolling_mean().times(1);
                let rolling_mean_dep = rolling_mean_dep.with(eq_percent_k, eq_smooth_window);
                rolling_mean_dep.return_const(percent_d.clone());
                percent_d
            }
        };

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_atr_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_atr(None, None));
        let data = tc.draw(gen_ohlc_data(0));

        let len = data["close"].len();
        let expected_true_range = tc.draw(gen_f64());
        let true_ranges = vec![expected_true_range; len];
        let ema = tc.draw(gen_vec(gen_f64(), len));
        let expected_values = tc.draw(gen_vec(gen_f64(), len));

        let mut mock_deps = MockATRDeps::new();

        let true_range_dep = mock_deps.expect_true_range().times(len);
        let true_range_dep = true_range_dep.with(always(), always(), always());
        true_range_dep.return_const(expected_true_range);

        let eq_true_ranges = eq(true_ranges);
        let eq_window = eq(feature.window);
        let eq_smooth = eq(feature.smooth);

        let ema_dep = mock_deps.expect_ema().times(1);
        let ema_dep = ema_dep.with(eq_true_ranges, eq_window, eq_smooth);
        ema_dep.return_const(ema.clone());

        let eq_ema = eq(ema);
        let eq_close = eq(data["close"].clone());

        let normalize_dep = mock_deps.expect_normalize().times(1);
        let normalize_dep = normalize_dep.with(eq_ema, eq_close);
        normalize_dep.return_const(expected_values.clone());

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_roc_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_roc(None, None));
        let data = tc.draw(gen_ohlc_data(0));

        let len =  data[feature.ohlc.to_str()].len();
        let call_count = len.saturating_sub(feature.window);

        let expected_division = tc.draw(gen_f64());
        let mut expected_values = vec![0.0; len];
        for expected_value in expected_values.iter_mut().skip(feature.window) {
            *expected_value = expected_division;
        }

        let mut mock_deps = MockFeatureDeps::new();
        let safe_divide_dep = mock_deps.expect_safe_divide().times(call_count);
        let safe_divide_dep = safe_divide_dep.with(always(), always());
        safe_divide_dep.return_const(expected_division);

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }

    #[hegel::test]
    fn test_dc_calculate_values(tc: TestCase) {
        let feature = tc.draw(gen_dc(None, None));
        let data = tc.draw(gen_ohlc_data(0));
        
        let len = data["close"].len();
        let high_max = tc.draw(gen_vec(gen_f64(), len));
        let low_min = tc.draw(gen_vec(gen_f64(), len));
        let expected_output = tc.draw(gen_f64());
        let outputs = vec![expected_output; len];
        let expected_values = tc.draw(gen_vec(gen_f64(), len));

        let mut mock_deps = MockDCDeps::new();

        let eq_high = eq(data["high"].clone());
        let eq_low = eq(data["low"].clone());
        let eq_window = eq(feature.window);

        let rolling_max_dep = mock_deps.expect_rolling_max().times(1);
        let rolling_max_dep = rolling_max_dep.with(eq_high, eq_window);
        rolling_max_dep.return_const(high_max);

        let rolling_min_dep = mock_deps.expect_rolling_min().times(1);
        let rolling_min_dep = rolling_min_dep.with(eq_low, eq_window);
        rolling_min_dep.return_const(low_min);

        let output_dep = mock_deps.expect_output().times(len);
        let output_dep = output_dep.with(always(), always(), always());
        output_dep.return_const(expected_output);

        let eq_outputs = eq(outputs);
        let eq_close = eq(data["close"].clone());

        let normalize_dep = mock_deps.expect_normalize().times(1);
        let normalize_dep = normalize_dep.with(eq_outputs, eq_close);
        normalize_dep.return_const(expected_values.clone());

        let values = feature._calculate_values(&mock_deps, &data);

        assert_eq!(values, expected_values);
    }
}
