use std::collections::HashMap;
use ndarray::Array1;

use alphchemy::features::features::{Feature, Constant, RawReturns, ReturnsType, OHLC, feat_matrix};

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
fn test_feat_matrix_shape() {
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

    let matrix = feat_matrix(&feats, &data);
    assert_eq!(matrix.nrows(), 5);
    assert_eq!(matrix.ncols(), 3);
}

#[test]
fn test_feat_matrix_values() {
    let data = sample_ohlc_data();

    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(Constant { id: "c1".to_string(), constant: 42.0 })
    ];

    let matrix = feat_matrix(&feats, &data);

    for i in 0..5 {
        assert!((matrix[[i, 0]] - 42.0).abs() < 1e-10);
    }
}
