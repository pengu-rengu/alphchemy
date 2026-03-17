use ndarray::{Array1, Array2};
use std::collections::HashMap;

#[derive(Clone, Copy, Debug)]
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

fn n_rows(data: &HashMap<String, Array1<f64>>) -> usize {
    data.values().next().unwrap().len()
}

pub trait Feature {
    fn id(&self) -> String;
    fn calculate_values(&self, data: &HashMap<String, Array1<f64>>) -> Array1<f64>;
}

#[derive(Clone, Debug)]
pub struct Constant {
    pub id: String,
    pub constant: f64
}

impl Feature for Constant {
    
    fn id(&self) -> String { self.id.clone() }

    fn calculate_values(&self, data: &HashMap<String, Array1<f64>>) -> Array1<f64> {
        let len = n_rows(data);

        Array1::from_elem(len, self.constant)
    }
}

#[derive(Clone, Debug)]
pub struct RawReturns {
    pub id: String,
    pub log_returns: bool,
    pub ohlc: OHLC
}

impl Feature for RawReturns {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn calculate_values(&self, data: &HashMap<String, Array1<f64>>) -> Array1<f64> {

        let prices = &data[self.ohlc.to_str()];

        let mut returns = Array1::from_elem(prices.len(), f64::NAN);
        
        for i in 1..prices.len() {
            if self.log_returns {
                returns[i] = (prices[i] / prices[i - 1]).ln();
            } else {
                returns[i] = (prices[i] / prices[i - 1]) - 1.0;
            }
        }

        returns
    }
}

pub fn feat_matrix(feats: &[Box<dyn Feature>], data: &HashMap<String, Array1<f64>>) -> Array2<f64> {
    
    let rows = n_rows(data);
    let mut matrix = Array2::zeros((rows, feats.len()));

    for (col_idx, feat) in feats.iter().enumerate() {
        let values = feat.calculate_values(data);
        let mut column = matrix.column_mut(col_idx);

        column.assign(&values);
    }

    matrix
}
