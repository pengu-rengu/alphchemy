use std::collections::HashMap;
use serde::Serialize;
use super::features::{OHLC, FeatureDeps, FeatureDepsImpl};


#[derive(Clone, Debug, Serialize)]
pub struct NormalizedSMA {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl NormalizedSMA {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: FeatureDeps {
        let prices = &data[self.ohlc.to_str()];
        let means = deps.rolling_mean(&prices, self.window);

        deps.normalize(&means, prices)
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&FeatureDepsImpl, data)
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct NormalizedEMA {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize,
    pub smooth: usize
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
    pub ohlc: OHLC,
    pub fast_window: usize,
    pub fast_smooth: usize,
    pub slow_window: usize,
    pub slow_smooth: usize,
    pub signal_window: usize,
    pub signal_smooth: usize,
    pub output: MACDOutput
}

trait MACDDeps: FeatureDeps {
    fn line(&self, fast: &[f64], slow: &[f64]) -> Vec<f64> {
        (0..fast.len()).map(|idx| fast[idx] - slow[idx]).collect()
    }

    fn hist(&self, line: &[f64], signal: &[f64]) -> Vec<f64> {
        (0..line.len()).map(|idx| line[idx] - signal[idx]).collect()
    }
}

struct MACDDepsImpl;
impl MACDDeps for MACDDepsImpl {}
impl FeatureDeps for MACDDepsImpl {}

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
    pub ohlc: OHLC,
    pub window: usize,
    pub smooth: usize
}

trait RSIDeps: FeatureDeps {
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
            losses[i] = -(prices[i] - prices[i - 1]).max(0.0);
        }
        losses
    }

    fn _rsi<T>(&self, deps: &T, gain: f64, loss: f64) -> f64 where T: RSIDeps {
        let relative_strength = deps.safe_divide(gain, loss);
        100.0 - deps.safe_divide(100.0, 1.0 + relative_strength)
    }

    fn rsi(&self, gain: f64, loss: f64) -> f64 {
        self._rsi(&RSIDepsImpl, gain, loss)
    }
}

struct RSIDepsImpl;
impl RSIDeps for RSIDepsImpl {}
impl FeatureDeps for RSIDepsImpl {}

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
    pub ohlc: OHLC,
    pub window: usize,
    pub std_multiplier: f64,
    pub output: BBOutput
}

trait BBDeps: FeatureDeps {
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
impl FeatureDeps for BBDepsImpl {}

impl NormalizedBB {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: BBDeps {
        let prices = &data[self.ohlc.to_str()];
        let means = deps.rolling_mean(prices, self.window);
        let devs = deps.rolling_std(prices, &means, self.window);
        let mut result = vec![0.0; prices.len()];

        for i in 0..prices.len() {
            result[i] = deps.output(&self, means[i], devs[i]);
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

trait StochasticDeps: FeatureDeps {
    fn _percent_k<T>(&self, deps: &T, high_max: f64, low_min: f64, close: f64) -> f64 where T: StochasticDeps {
        100.0 * deps.safe_divide(close - low_min, high_max - low_min)
    }

    fn percent_k(&self, high_max: f64, low_min: f64, close: f64) -> f64 {
        self._percent_k(&StochasticDepsImpl, high_max, low_min, close)
    }
}

struct StochasticDepsImpl;
impl StochasticDeps for StochasticDepsImpl {}
impl FeatureDeps for StochasticDepsImpl {}

impl Stochastic {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: StochasticDeps {
        let close = &data["close"];
        let high_max = deps.rolling_max(&data["high"], self.window);
        let low_min = deps.rolling_min(&data["low"], self.window);
        let mut percent_k = vec![0.0; close.len()];

        for i in 0..close.len() {
            percent_k[i] = deps.percent_k(high_max[i], low_min[i], close[i])
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

trait ATRDeps: FeatureDeps {
    fn true_range(&self, high: f64, low: f64, maybe_prev_close: Option<f64>) -> f64 {
        let high_low_range = high - low;

        if let Some(prev_close) = maybe_prev_close {
            vec![high_low_range, (high - prev_close).abs(), (low - prev_close.abs())].iter().copied().fold(f64::NEG_INFINITY, f64::max)
        } else {
            high_low_range
        }
    }
}

struct ATRDepsImpl;
impl ATRDeps for ATRDepsImpl {}
impl FeatureDeps for ATRDepsImpl {}

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
    pub ohlc: OHLC,
    pub window: usize
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

trait DCDeps: FeatureDeps {
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
impl FeatureDeps for DCDepsImpl {}

impl NormalizedDC {
    fn _calculate_values<T>(&self, deps: &T, data: &HashMap<String, Vec<f64>>) -> Vec<f64> where T: DCDeps {
        let close = &data["close"];
        let high_max = deps.rolling_max(&data["high"], self.window);
        let low_min = deps.rolling_min(&data["low"], self.window);
        let mut result = vec![0.0; close.len()];

        for i in 0..close.len() {
            result[i] = deps.output(&self, high_max[i], low_min[i]);
        }

        deps.normalize(&result, close)
    }

    pub fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        self._calculate_values(&DCDepsImpl, data)
    }
}
