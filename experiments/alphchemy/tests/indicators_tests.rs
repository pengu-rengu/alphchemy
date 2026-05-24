use std::collections::HashMap;

use alphchemy::features::features::{Feature, OHLC};
use alphchemy::features::indicators::{NormalizedEMA, NormalizedSMA};

fn close_data(values: Vec<f64>) -> HashMap<String, Vec<f64>> {
    let mut data: HashMap<String, Vec<f64>> = HashMap::new();
    data.insert("close".to_string(), values);
    data
}

#[test]
fn test_normalized_sma_returns_zero_before_window() {
    let data = close_data(vec![2.0, 4.0, 6.0, 8.0]);
    let sma = NormalizedSMA {
        id: "sma".to_string(),
        ohlc: OHLC::Close,
        window: 3
    };

    let values = sma.calculate_values(&data);

    assert_eq!(values[0], 0.0);
    assert_eq!(values[1], 0.0);
    assert_eq!(values[2], 4.0 / 6.0);
    assert_eq!(values[3], 6.0 / 8.0);
}

#[test]
fn test_normalized_ema_returns_zero_before_window() {
    let data = close_data(vec![2.0, 4.0, 6.0, 8.0, 10.0]);
    let ema = NormalizedEMA {
        id: "ema".to_string(),
        ohlc: OHLC::Close,
        window: 3,
        smooth: 2
    };

    let values = ema.calculate_values(&data);

    assert_eq!(values[0], 0.0);
    assert_eq!(values[1], 0.0);
    assert_eq!(values[2], 0.0);
    assert_eq!(values[3], 6.0 / 8.0);
    assert_eq!(values[4], 8.0 / 10.0);
}
