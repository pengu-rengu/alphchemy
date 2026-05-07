use serde::Deserialize;
use std::collections::HashMap;
use super::features::{Feature, OHLC, nan_array, ohlc_values, safe_ratio};

fn rolling_mean(values: &Vec<f64>, window: usize) -> Vec<f64> {
    let mut result = nan_array(values.len());
    let mut sum = 0.0;
    let mut valid_count = 0;

    for i in 0..values.len() {
        let value = values[i];
        sum += value;

        if !value.is_nan() {
            valid_count += 1;
        }

        if i >= window {
            let old_value = values[i - window];
            sum -= old_value;

            if !old_value.is_nan() {
                valid_count -= 1;
            }
        }

        let enough_values = i + 1 >= window;
        if enough_values && valid_count == window {
            result[i] = sum / window as f64;
        }
    }

    result
}

fn rolling_std(values: &Vec<f64>, means: &Vec<f64>, window: usize) -> Vec<f64> {
    let mut result = nan_array(values.len());

    for i in 0..values.len() {
        if i + 1 < window {
            continue;
        }

        let mean = means[i];
        if mean.is_nan() {
            continue;
        }

        let start_idx = i + 1 - window;
        let mut variance = 0.0;

        for idx in start_idx..=i {
            let diff = values[idx] - mean;
            variance += diff * diff;
        }

        let avg_variance = variance / window as f64;
        result[i] = avg_variance.sqrt();
    }

    result
}

fn rolling_min(values: &Vec<f64>, window: usize) -> Vec<f64> {
    let mut result = nan_array(values.len());

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
    let mut result = nan_array(values.len());

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

fn ema(values: &Vec<f64>, window: usize) -> Vec<f64> {
    let mut result = nan_array(values.len());
    let mut sum: f64 = 0.0;
    let mut seed_count = 0;
    let mut previous = f64::NAN;
    let window_factor = window as f64 + 1.0;
    let alpha = 2.0 / window_factor;

    for i in 0..values.len() {
        let value = values[i];
        if value.is_nan() {
            continue;
        }

        if seed_count < window {
            sum += value;
            seed_count += 1;

            if seed_count == window {
                previous = sum / window as f64;
                result[i] = previous;
            }
            continue;
        }

        let old_weight = 1.0 - alpha;
        let weighted_previous = previous * old_weight;
        previous = alpha * value + weighted_previous;
        result[i] = previous;
    }

    result
}

fn wilder(values: &Vec<f64>, window: usize) -> Vec<f64> {
    let mut result = nan_array(values.len());
    let mut sum = 0.0;
    let mut seed_count = 0;
    let mut previous = f64::NAN;

    for i in 0..values.len() {
        let value = values[i];
        if value.is_nan() {
            continue;
        }

        if seed_count < window {
            sum += value;
            seed_count += 1;

            if seed_count == window {
                previous = sum / window as f64;
                result[i] = previous;
            }
            continue;
        }

        let scale = window as f64 - 1.0;
        let retained = previous * scale;
        previous = (retained + value) / window as f64;
        result[i] = previous;
    }

    result
}

#[derive(Clone, Debug, Deserialize)]
pub struct Sma {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl Feature for Sma {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let close = &data["close"];
        let averages = rolling_mean(prices, self.window);
        let mut result = nan_array(prices.len());

        for i in 0..prices.len() {
            let average = averages[i];
            if average.is_nan() {
                continue;
            }

            let diff = prices[i] - average;
            result[i] = safe_ratio(diff, close[i]);
        }

        result
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct Ema {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl Feature for Ema {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let close = &data["close"];
        let averages = ema(prices, self.window);
        let mut result = nan_array(prices.len());

        for i in 0..prices.len() {
            let average = averages[i];
            if average.is_nan() {
                continue;
            }

            let diff = prices[i] - average;
            result[i] = safe_ratio(diff, close[i]);
        }

        result
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MacdOutput {
    Line,
    Signal,
    Histogram
}

#[derive(Clone, Debug, Deserialize)]
pub struct Macd {
    pub id: String,
    pub ohlc: OHLC,
    pub fast_window: usize,
    pub slow_window: usize,
    pub signal_window: usize,
    pub output: MacdOutput
}

impl Feature for Macd {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let close = &data["close"];
        let fast = ema(prices, self.fast_window);
        let slow = ema(prices, self.slow_window);
        let mut line = nan_array(prices.len());

        for i in 0..prices.len() {
            if fast[i].is_nan() || slow[i].is_nan() {
                continue;
            }

            line[i] = safe_ratio(fast[i] - slow[i], close[i]);
        }

        let signal = ema(&line, self.signal_window);
        let mut histogram = nan_array(prices.len());

        for i in 0..prices.len() {
            if line[i].is_nan() || signal[i].is_nan() {
                continue;
            }

            histogram[i] = line[i] - signal[i];
        }

        match self.output {
            MacdOutput::Line => line,
            MacdOutput::Signal => signal,
            MacdOutput::Histogram => histogram
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct Rsi {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl Feature for Rsi {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let mut gains = nan_array(prices.len());
        let mut losses = nan_array(prices.len());

        for i in 1..prices.len() {
            let change = prices[i] - prices[i - 1];
            gains[i] = change.max(0.0);
            losses[i] = (-change).max(0.0);
        }

        let avg_gains = wilder(&gains, self.window);
        let avg_losses = wilder(&losses, self.window);
        let mut result = nan_array(prices.len());

        for i in 0..prices.len() {
            let gain = avg_gains[i];
            let loss = avg_losses[i];

            if gain.is_nan() || loss.is_nan() {
                continue;
            }

            if loss == 0.0 {
                result[i] = if gain == 0.0 { 50.0 } else { 100.0 };
                continue;
            }

            let relative_strength = gain / loss;
            let denominator = 1.0 + relative_strength;
            result[i] = 100.0 - 100.0 / denominator;
        }

        result
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BollingerOutput {
    ZScore,
    BandWidth
}

#[derive(Clone, Debug, Deserialize)]
pub struct BollingerBands {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize,
    pub std_mult: f64,
    pub output: BollingerOutput
}

impl Feature for BollingerBands {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let close = &data["close"];
        let averages = rolling_mean(prices, self.window);
        let deviations = rolling_std(prices, &averages, self.window);
        let mut result = nan_array(prices.len());

        for i in 0..prices.len() {
            let average = averages[i];
            let deviation = deviations[i];

            if average.is_nan() || deviation.is_nan() {
                continue;
            }

            if deviation == 0.0 {
                continue;
            }

            result[i] = match self.output {
                BollingerOutput::ZScore => {
                    let diff = prices[i] - average;
                    let scaled_deviation = self.std_mult * deviation;
                    safe_ratio(diff, scaled_deviation)
                }
                BollingerOutput::BandWidth => {
                    let half_width = self.std_mult * deviation;
                    let width = 2.0 * half_width;
                    safe_ratio(width, close[i])
                }
            };
        }

        result
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
        let high = &data["high"];
        let low = &data["low"];
        let close = &data["close"];
        let high_max = rolling_max(high, self.window);
        let low_min = rolling_min(low, self.window);
        let mut percent_k = nan_array(close.len());

        for i in 0..close.len() {
            if high_max[i].is_nan() || low_min[i].is_nan() {
                continue;
            }

            let range = high_max[i] - low_min[i];
            let close_offset = close[i] - low_min[i];
            percent_k[i] = 100.0 * safe_ratio(close_offset, range);
        }

        match self.output {
            StochasticOutput::PercentK => percent_k,
            StochasticOutput::PercentD => rolling_mean(&percent_k, self.smooth_window)
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct Atr {
    pub id: String,
    pub window: usize
}

impl Feature for Atr {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let high = &data["high"];
        let low = &data["low"];
        let close = &data["close"];
        let mut true_ranges = nan_array(close.len());

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

        let atr = wilder(&true_ranges, self.window);
        let mut result = nan_array(close.len());

        for i in 0..close.len() {
            if atr[i].is_nan() {
                continue;
            }

            result[i] = safe_ratio(atr[i], close[i]);
        }

        result
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct Roc {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl Feature for Roc {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let mut result = nan_array(prices.len());

        for i in self.window..prices.len() {
            let ratio = safe_ratio(prices[i], prices[i - self.window]);
            result[i] = ratio - 1.0;
        }

        result
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct Momentum {
    pub id: String,
    pub ohlc: OHLC,
    pub window: usize
}

impl Feature for Momentum {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let prices = ohlc_values(data, &self.ohlc);
        let close = &data["close"];
        let mut result = nan_array(prices.len());

        for i in self.window..prices.len() {
            let diff = prices[i] - prices[i - self.window];
            result[i] = safe_ratio(diff, close[i]);
        }

        result
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DonchianOutput {
    Position,
    Width
}

#[derive(Clone, Debug, Deserialize)]
pub struct DonchianChannel {
    pub id: String,
    pub window: usize,
    pub output: DonchianOutput
}

impl Feature for DonchianChannel {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let high = &data["high"];
        let low = &data["low"];
        let close = &data["close"];
        let high_max = rolling_max(high, self.window);
        let low_min = rolling_min(low, self.window);
        let mut result = nan_array(close.len());

        for i in 0..close.len() {
            if high_max[i].is_nan() || low_min[i].is_nan() {
                continue;
            }

            let range = high_max[i] - low_min[i];
            result[i] = match self.output {
                DonchianOutput::Position => {
                    let close_offset = close[i] - low_min[i];
                    safe_ratio(close_offset, range)
                }
                DonchianOutput::Width => safe_ratio(range, close[i])
            };
        }

        result
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct Cci {
    pub id: String,
    pub window: usize
}

impl Feature for Cci {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Vec<f64>>) -> Vec<f64> {
        let high = &data["high"];
        let low = &data["low"];
        let close = &data["close"];
        let mut typical = nan_array(close.len());

        for i in 0..close.len() {
            let high_low_sum = high[i] + low[i];
            typical[i] = (high_low_sum + close[i]) / 3.0;
        }

        let averages = rolling_mean(&typical, self.window);
        let mut result = nan_array(close.len());

        for i in 0..close.len() {
            if i + 1 < self.window {
                continue;
            }

            let average = averages[i];
            if average.is_nan() {
                continue;
            }

            let start_idx = i + 1 - self.window;
            let mut mean_deviation = 0.0;

            for idx in start_idx..=i {
                mean_deviation += (typical[idx] - average).abs();
            }

            mean_deviation /= self.window as f64;

            if mean_deviation == 0.0 {
                continue;
            }

            let denominator = 0.015 * mean_deviation;
            result[i] = (typical[i] - average) / denominator;
        }

        result
    }
}
