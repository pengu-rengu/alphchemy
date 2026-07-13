use hegel::{Generator, generators::{FloatGenerator, IntegerGenerator, TextGenerator, VecGenerator, floats, integers, text, vecs}};

pub const INT_MAX: usize = 100;
const FLOAT_MAX: f64 = 100.0;
const TEXT_LENGTH_MAX: usize = 25;

pub fn gen_usize_with_min(min: usize) -> IntegerGenerator<usize> {
    let generator = integers::<usize>().max_value(INT_MAX);
    generator.min_value(min)
}

pub fn gen_usize_with_max(max: usize) -> IntegerGenerator<usize> {
    integers::<usize>().max_value(max)
}

pub fn gen_usize() -> IntegerGenerator<usize> {
    gen_usize_with_max(INT_MAX)
}

pub fn gen_f64() -> FloatGenerator<f64> {
    let generator = floats::<f64>().min_value(0.0);
    generator.max_value(FLOAT_MAX)
}

pub fn gen_vec<T, G>(element_gen: G, size: usize) -> VecGenerator<G, T> where G: Generator<T> {
    let mut generator = vecs(element_gen);
    generator = generator.min_size(size);
    generator.max_size(size)
}

pub fn gen_text() -> TextGenerator {
    text().max_size(TEXT_LENGTH_MAX)
}
/*
use std::collections::HashMap;
use rand::Rng;

pub fn generate_ohlc_data(n_bars: usize) -> (Vec<f64>, HashMap<String, Vec<f64>>) {
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
    ohlc_data.insert("open".to_string(), open);
    ohlc_data.insert("high".to_string(), high);
    ohlc_data.insert("low".to_string(), low);
    ohlc_data.insert("close".to_string(), close.clone());

    (close, ohlc_data)
}
*/
