use std::collections::HashMap;
use ndarray::Array1;

use alphchemy::features::features::{
    Atr,
    BollingerBands,
    BollingerOutput,
    Cci,
    Constant,
    DonchianChannel,
    DonchianOutput,
    Ema,
    Feature,
    Macd,
    MacdOutput,
    Momentum,
    OHLC,
    RawReturns,
    ReturnsType,
    Roc,
    Rsi,
    Sma,
    Stochastic,
    StochasticOutput,
    feat_table,
    parse_feats
};

fn sample_ohlc_data() -> HashMap<String, Array1<f64>> {
    let mut data = HashMap::new();
    let open_array = Array1::from_vec(vec![100.0, 102.0, 104.0, 103.0, 105.0]);
    data.insert("open".to_string(), open_array);
    let high_array = Array1::from_vec(vec![103.0, 105.0, 106.0, 105.0, 107.0]);
    data.insert("high".to_string(), high_array);
    let low_array = Array1::from_vec(vec![99.0, 101.0, 102.0, 101.0, 104.0]);
    data.insert("low".to_string(), low_array);
    let close_array = Array1::from_vec(vec![101.0, 103.0, 105.0, 102.0, 106.0]);
    data.insert("close".to_string(), close_array);
    data
}

fn sample_indicator_data() -> HashMap<String, Array1<f64>> {
    let mut data = HashMap::new();
    let open_array = Array1::from_vec(vec![9.5, 10.5, 11.5, 12.5, 13.5, 14.5]);
    data.insert("open".to_string(), open_array);
    let high_array = Array1::from_vec(vec![11.0, 12.0, 13.0, 14.0, 15.0, 16.0]);
    data.insert("high".to_string(), high_array);
    let low_array = Array1::from_vec(vec![9.0, 10.0, 11.0, 12.0, 13.0, 14.0]);
    data.insert("low".to_string(), low_array);
    let close_array = Array1::from_vec(vec![10.0, 11.0, 12.0, 13.0, 14.0, 15.0]);
    data.insert("close".to_string(), close_array);
    data
}

fn assert_close(actual: f64, expected: f64) {
    let diff = (actual - expected).abs();
    assert!(diff < 1e-10);
}

#[test]
fn test_constant_feature() {
    let feat = Constant {
        id: "const_5".to_string(),
        constant: 5.0
    };

    let data = sample_ohlc_data();
    let values = feat.calculate_values(&data);

    assert_eq!(values.len(), 5);
    for &val in values.iter() {
        assert!((val - 5.0).abs() < 1e-10);
    }
}

#[test]
fn test_constant_feature_id() {
    let feat = Constant {
        id: "my_const".to_string(),
        constant: 1.0
    };
    assert_eq!(feat.id(), "my_const");
}

#[test]
fn test_raw_returns_log() {
    let feat = RawReturns {
        id: "log_close".to_string(),
        returns_type: ReturnsType::Log,
        ohlc: OHLC::Close
    };

    let data = sample_ohlc_data();
    let values = feat.calculate_values(&data);

    assert_eq!(values.len(), 5);
    assert!(values[0].is_nan());

    let expected = (103.0_f64 / 101.0).ln();
    assert!((values[1] - expected).abs() < 1e-10);
}

#[test]
fn test_raw_returns_simple() {
    let feat = RawReturns {
        id: "simple_close".to_string(),
        returns_type: ReturnsType::Simple,
        ohlc: OHLC::Close
    };

    let data = sample_ohlc_data();
    let values = feat.calculate_values(&data);

    assert!(values[0].is_nan());

    let expected = (103.0 / 101.0) - 1.0;
    assert!((values[1] - expected).abs() < 1e-10);
}

#[test]
fn test_feat_table_shape() {
    let data = sample_ohlc_data();

    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(Constant { id: "c1".to_string(), constant: 1.0 }),
        Box::new(Constant { id: "c2".to_string(), constant: 2.0 }),
        Box::new(RawReturns {
            id: "lr".to_string(),
            returns_type: ReturnsType::Log,
            ohlc: OHLC::Close
        })
    ];

    let table = feat_table(&feats, &data);
    assert_eq!(table.len(), 3);
    assert_eq!(table["c1"].len(), 5);
    assert_eq!(table["c2"].len(), 5);
    assert_eq!(table["lr"].len(), 5);
}

#[test]
fn test_feat_table_values() {
    let data = sample_ohlc_data();

    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(Constant { id: "c1".to_string(), constant: 42.0 })
    ];

    let table = feat_table(&feats, &data);
    let values = &table["c1"];

    for i in 0..5 {
        assert!((values[i] - 42.0).abs() < 1e-10);
    }
}

#[test]
fn test_sma_feature() {
    let feat = Sma {
        id: "sma_close".to_string(),
        ohlc: OHLC::Close,
        window: 3
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 1.0 / 12.0);
}

#[test]
fn test_ema_feature() {
    let feat = Ema {
        id: "ema_close".to_string(),
        ohlc: OHLC::Close,
        window: 3
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 1.0 / 12.0);
}

#[test]
fn test_macd_line_feature() {
    let feat = Macd {
        id: "macd_close".to_string(),
        ohlc: OHLC::Close,
        fast_window: 2,
        slow_window: 3,
        signal_window: 2,
        output: MacdOutput::Line
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 0.5 / 12.0);
}

#[test]
fn test_rsi_feature() {
    let feat = Rsi {
        id: "rsi_close".to_string(),
        ohlc: OHLC::Close,
        window: 3
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[2].is_nan());
    assert_close(values[3], 100.0);
}

#[test]
fn test_bollinger_bands_z_score_feature() {
    let feat = BollingerBands {
        id: "bb_close".to_string(),
        ohlc: OHLC::Close,
        window: 3,
        std_mult: 2.0,
        output: BollingerOutput::ZScore
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);
    let expected_std = (2.0_f64 / 3.0).sqrt();
    let expected = 1.0 / (2.0 * expected_std);

    assert!(values[1].is_nan());
    assert_close(values[2], expected);
}

#[test]
fn test_stochastic_percent_k_feature() {
    let feat = Stochastic {
        id: "stoch".to_string(),
        window: 3,
        smooth_window: 2,
        output: StochasticOutput::PercentK
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 75.0);
}

#[test]
fn test_atr_feature() {
    let feat = Atr {
        id: "atr".to_string(),
        window: 3
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 2.0 / 12.0);
}

#[test]
fn test_roc_feature() {
    let feat = Roc {
        id: "roc_close".to_string(),
        ohlc: OHLC::Close,
        window: 2
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 0.2);
}

#[test]
fn test_momentum_feature() {
    let feat = Momentum {
        id: "momentum_close".to_string(),
        ohlc: OHLC::Close,
        window: 2
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 2.0 / 12.0);
}

#[test]
fn test_donchian_position_feature() {
    let feat = DonchianChannel {
        id: "donchian".to_string(),
        window: 3,
        output: DonchianOutput::Position
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 0.75);
}

#[test]
fn test_cci_feature() {
    let feat = Cci {
        id: "cci".to_string(),
        window: 3
    };

    let data = sample_indicator_data();
    let values = feat.calculate_values(&data);

    assert!(values[1].is_nan());
    assert_close(values[2], 100.0);
}

#[test]
fn test_parse_all_indicator_features() {
    let json_values = vec![
        serde_json::json!({"feature": "sma", "id": "sma", "ohlc": "close", "window": 3}),
        serde_json::json!({"feature": "ema", "id": "ema", "ohlc": "close", "window": 3}),
        serde_json::json!({"feature": "macd", "id": "macd", "ohlc": "close", "fast_window": 2, "slow_window": 3, "signal_window": 2, "output": "histogram"}),
        serde_json::json!({"feature": "rsi", "id": "rsi", "ohlc": "close", "window": 3}),
        serde_json::json!({"feature": "bollinger_bands", "id": "bb", "ohlc": "close", "window": 3, "std_mult": 2.0, "output": "band_width"}),
        serde_json::json!({"feature": "stochastic", "id": "stoch", "window": 3, "smooth_window": 2, "output": "percent_d"}),
        serde_json::json!({"feature": "atr", "id": "atr", "window": 3}),
        serde_json::json!({"feature": "roc", "id": "roc", "ohlc": "close", "window": 2}),
        serde_json::json!({"feature": "momentum", "id": "momentum", "ohlc": "close", "window": 2}),
        serde_json::json!({"feature": "donchian_channel", "id": "donchian", "window": 3, "output": "width"}),
        serde_json::json!({"feature": "cci", "id": "cci", "window": 3})
    ];

    let feats = parse_feats(&json_values).unwrap();

    assert_eq!(feats.len(), 11);
}

#[test]
fn test_parse_rejects_invalid_windows() {
    let json_values = vec![
        serde_json::json!({"feature": "sma", "id": "bad_sma", "ohlc": "close", "window": 0})
    ];

    let result = parse_feats(&json_values);

    assert!(result.is_err());
}
