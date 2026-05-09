use serde::Deserialize;
use std::collections::HashMap;
use super::features::{Feature, OHLC, safe_divide};

fn rolling_mean(values: &Vec<f64>, window: usize) -> Vec<f64> {
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

fn rolling_std(values: &Vec<f64>, means: &Vec<f64>, window: usize) -> Vec<f64> {
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

fn rolling_min(values: &Vec<f64>, window: usize) -> Vec<f64> {
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

fn rolling_max(values: &Vec<f64>, window: usize) -> Vec<f64> {
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


fn ema(values: &Vec<f64>, window: usize, smooth: usize) -> Vec<f64> {
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

fn normalize(values: &Vec<f64>, original: &Vec<f64>) -> Vec<f64> {
    let norm_func = |idx: usize| safe_divide(values[idx], original[idx]);
    (0..values.len()).map(norm_func).collect()
}

#[derive(Clone, Debug, Deserialize)]
pub struct NormalizedSMA {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl Feature for NormalizedSMA {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = &data[self.ohlc.to_str()];
        let means = rolling_mean(&prices, self.window);

        normalize(&means, prices)
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct NormalizedEMA {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize,
    pub smooth: usize
}

impl Feature for NormalizedEMA {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = &data[self.ohlc.to_str()];
        let ema_values = ema(prices, self.window, self.smooth);

        normalize(&ema_values, prices)
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MACDOutput {
    Line,
    Signal,
    Hist
}

#[derive(Clone, Debug, Deserialize)]
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

impl Feature for NormalizedMACD {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = &data[self.ohlc.to_str()];

        let fast = ema(prices, self.fast_window, self.fast_smooth);
        let slow = ema(prices, self.slow_window, self.slow_smooth);

        let line = (0..prices.len()).map(|idx| fast[idx] - slow[idx]).collect();
        let signal = ema(&line, self.signal_window, self.signal_smooth);
        let hist = (0..prices.len()).map(|idx| line[idx] - signal[idx]).collect();

        match self.output {
            MACDOutput::Line => normalize(&line, prices),
            MACDOutput::Signal => normalize(&signal, prices),
            MACDOutput::Hist => normalize(&hist, prices)
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct RSI {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize,
    pub smooth: usize
}

impl Feature for RSI {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = &data[self.ohlc.to_str()];
        let mut gains = vec![0.0; prices.len()];
        let mut losses = vec![0.0; prices.len()];

        for i in 1..prices.len() {
            let change = prices[i] - prices[i - 1];
            gains[i] = change.max(0.0);
            losses[i] = (-change).max(0.0);
        }

        let ema_gains = ema(&gains, self.window, self.smooth);
        let ema_losses = ema(&losses, self.window, self.smooth);
        let mut result = vec![0.0; prices.len()];

        for i in 0..prices.len() {
            let relative_strength = safe_divide(ema_gains[i], ema_losses[i]);
            result[i] = 100.0 - safe_divide(100.0, 1.0 + relative_strength);
        }

        result
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BBOutput {
    Upper,
    Lower,
    Width
}

#[derive(Clone, Debug, Deserialize)]
pub struct NormalizedBB {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize,
    pub std_multiplier: f64,
    pub output: BBOutput
}

impl Feature for NormalizedBB {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = &data[self.ohlc.to_str()];
        let means = rolling_mean(prices, self.window);
        let deviations = rolling_std(prices, &means, self.window);
        let mut result = vec![0.0; prices.len()];

        for i in 0..prices.len() {
            let mean = means[i];
            let half_width = self.std_multiplier * deviations[i];

            result[i] = match self.output {
                BBOutput::Upper => mean + half_width,
                BBOutput::Lower => mean - half_width,
                BBOutput::Width => 2.0 * half_width
            };
        }

        normalize(&result, prices)
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StochasticOutput {
    PercentK,
    PercentD
}

#[derive(Clone, Debug, Deserialize)]
pub struct Stochastic {
    pub id: String,
    pub window: usize,
    pub smooth_window: usize,
    pub output: StochasticOutput
}

impl Feature for Stochastic {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let close = &data["close"];
        let high_max = rolling_max(&data["high"], self.window);
        let low_min = rolling_min(&data["low"], self.window);
        let mut percent_k = vec![0.0; close.len()];

        for i in 0..close.len() {
            let range = high_max[i] - low_min[i];
            let close_offset = close[i] - low_min[i];
            percent_k[i] = 100.0 * safe_divide(close_offset, range);
        }

        match self.output {
            StochasticOutput::PercentK => percent_k,
            StochasticOutput::PercentD => rolling_mean(&percent_k, self.smooth_window)
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct NormalizedATR {
    pub id: String,
    pub window: usize,
    pub smooth: usize
}

impl Feature for NormalizedATR {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let high = &data["high"];
        let low = &data["low"];
        let close = &data["close"];
        let mut true_ranges = vec![0.0; close.len()];

        for i in 0..close.len() {
            let high_low = high[i] - low[i];

            if i == 0 {
                true_ranges[i] = high_low;
                continue;
            }

            let high_close = (high[i] - close[i - 1]).abs();
            let low_close = (low[i] - close[i - 1]).abs();
            let true_range = high_low.max(high_close);
            true_ranges[i] = true_range.max(low_close);
        }

        let result = ema(&true_ranges, self.window, self.smooth);

        normalize(&result, close)
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct ROC {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl Feature for ROC {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = &data[self.ohlc.to_str()];
        let len = prices.len();
        let mut result = vec![0.0; len];

        for i in self.window..len {
            result[i] = safe_divide(prices[i], prices[i - self.window]);
        }

        result
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DCOutput {
    Upper,
    Lower,
    Middle,
    Width
}

#[derive(Clone, Debug, Deserialize)]
pub struct NormalizedDC {
    pub id: String,
    pub window: usize,
    pub output: DCOutput
}

impl Feature for NormalizedDC {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let close = &data["close"];
        let high_max = rolling_max(&data["high"], self.window);
        let low_min = rolling_min(&data["low"], self.window);
        let mut result = vec![0.0; close.len()];

        for i in 0..close.len() {
            let upper = high_max[i];
            let lower = low_min[i];
            

            result[i] = match self.output {
                DCOutput::Upper => upper,
                DCOutput::Lower => lower,
                DCOutput::Middle => {
                    let sum = lower + upper;
                    sum / 2.0
                }
                DCOutput::Width => upper - lower
            };
        }

        normalize(&result, close)
    }
}
