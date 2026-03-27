use std::collections::HashMap;
use ndarray::Array1;
use rand::Rng;

pub fn generate_ohlc_data(n_bars: usize) -> (Vec<f64>, HashMap<String, Array1<f64>>) {
    let mut rng = rand::rng();
    let mut close = Vec::with_capacity(n_bars);
    let mut price = 100.0;

    for _ in 0..n_bars {
        let change = rng.random_range(-0.02..0.02);
        price *= 1.0 + change;
        close.push(price);
    }

    let mut open = Vec::with_capacity(n_bars);
    let mut high = Vec::with_capacity(n_bars);
    let mut low = Vec::with_capacity(n_bars);

    for i in 0..n_bars {
        let close_price = close[i];
        let spread = close_price * 0.01;
        let spread_2x = spread * 2.0;

        let open_offset = rng.random_range(-spread..spread);
        open.push(close_price + open_offset);

        let high_offset = rng.random_range(0.0..spread_2x);
        high.push(close_price + high_offset);

        let low_offset = rng.random_range(0.0..spread_2x);
        low.push(close_price - low_offset);
    }

    let mut ohlc_data = HashMap::new();
    let open_array = Array1::from_vec(open);
    ohlc_data.insert("open".to_string(), open_array);
    let high_array = Array1::from_vec(high);
    ohlc_data.insert("high".to_string(), high_array);
    let low_array = Array1::from_vec(low);
    ohlc_data.insert("low".to_string(), low_array);
    let close_array = Array1::from_vec(close.clone());
    ohlc_data.insert("close".to_string(), close_array);

    (close, ohlc_data)
}
