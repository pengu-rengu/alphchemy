use alphchemy_engine::features::features::{
    Feature, NormalizedSMA, NormalizedEMA, NormalizedMACD, MACDOutput, RSI, NormalizedBB, BBOutput,
    Stochastic, StochasticOutput, NormalizedATR, ROC, NormalizedDC, DCOutput
};
use super::super::parse::Fields;
use super::parse_features::{field_ohlc, expect_pos_usize, expect_pos_f64};

fn parse_macd_output(text: &str) -> Result<MACDOutput, String> {
    match text {
        "line" => Ok(MACDOutput::Line),
        "signal" => Ok(MACDOutput::Signal),
        "hist" => Ok(MACDOutput::Hist),
        _ => Err(format!("invalid macd output: {text}"))
    }
}

fn parse_bb_output(text: &str) -> Result<BBOutput, String> {
    match text {
        "upper" => Ok(BBOutput::Upper),
        "lower" => Ok(BBOutput::Lower),
        "width" => Ok(BBOutput::Width),
        _ => Err(format!("invalid bb output: {text}"))
    }
}

fn parse_stochastic_output(text: &str) -> Result<StochasticOutput, String> {
    match text {
        "percent_k" => Ok(StochasticOutput::PercentK),
        "percent_d" => Ok(StochasticOutput::PercentD),
        _ => Err(format!("invalid stochastic output: {text}"))
    }
}

fn parse_dc_output(text: &str) -> Result<DCOutput, String> {
    match text {
        "upper" => Ok(DCOutput::Upper),
        "lower" => Ok(DCOutput::Lower),
        "middle" => Ok(DCOutput::Middle),
        "width" => Ok(DCOutput::Width),
        _ => Err(format!("invalid dc output: {text}"))
    }
}

pub(super) fn parse_normalized_sma(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let window = fields.usize(&["window"], 14)?;
    expect_pos_usize(window, "window")?;
    let feat = NormalizedSMA { id: id.to_string(), ohlc, window };
    Ok(Feature::NormalizedSMA(feat))
}

pub(super) fn parse_normalized_ema(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth = fields.usize(&["smooth"], 2)?;
    let ohlc = field_ohlc(fields)?;

    expect_pos_usize(window, "window")?;
    expect_pos_usize(smooth, "smooth")?;

    let feat = NormalizedEMA { id: id.to_string(), window, smooth, ohlc };
    Ok(Feature::NormalizedEMA(feat))
}

pub(super) fn parse_normalized_macd(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let fast_window = fields.usize(&["fast_window"], 12)?;
    let fast_smooth = fields.usize(&["fast_smooth"], 2)?;
    let slow_window = fields.usize(&["slow_window"], 26)?;
    let slow_smooth = fields.usize(&["slow_smooth"], 2)?;
    let signal_window = fields.usize(&["signal_window"], 9)?;
    let signal_smooth = fields.usize(&["signal_smooth"], 2)?;
    let output_text = fields.string(&["output"], "hist")?;
    let output = parse_macd_output(&output_text)?;

    expect_pos_usize(fast_window, "fast_window")?;
    expect_pos_usize(slow_window, "slow_window")?;
    expect_pos_usize(signal_window, "signal_window")?;
    expect_pos_usize(fast_smooth, "fast_smooth")?;
    expect_pos_usize(slow_smooth, "slow_smooth")?;
    expect_pos_usize(signal_smooth, "signal_smooth")?;
    if fast_window > slow_window {
        return Err("fast_window must be <= slow_window".to_string());
    }

    let feat = NormalizedMACD {
        id: id.to_string(), ohlc, fast_window, fast_smooth, slow_window, slow_smooth, signal_window, signal_smooth, output
    };
    Ok(Feature::NormalizedMACD(feat))
}

pub(super) fn parse_rsi(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth = fields.usize(&["smooth"], 2)?;
    let ohlc = field_ohlc(fields)?;
    expect_pos_usize(window, "window")?;
    expect_pos_usize(smooth, "smooth")?;
    let feat = RSI { id: id.to_string(), window, smooth, ohlc };
    Ok(Feature::RSI(feat))
}

pub(super) fn parse_normalized_bb(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let window = fields.usize(&["window"], 14)?;
    let std_multiplier = fields.f64(&["std_multiplier", "std_mult"], 2.0)?;
    let output_text = fields.string(&["output"], "upper")?;
    let output = parse_bb_output(&output_text)?;
    expect_pos_usize(window, "window")?;
    expect_pos_f64(std_multiplier, "std_mult")?;
    let feat = NormalizedBB { id: id.to_string(), ohlc, window, std_multiplier, output };
    Ok(Feature::NormalizedBB(feat))
}

pub(super) fn parse_stochastic(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth_window = fields.usize(&["smooth_window"], 3)?;
    let output_text = fields.string(&["output"], "percent_k")?;
    let output = parse_stochastic_output(&output_text)?;
    expect_pos_usize(window, "window")?;
    expect_pos_usize(smooth_window, "smooth_window")?;
    let feat = Stochastic { id: id.to_string(), window, smooth_window, output };
    Ok(Feature::Stochastic(feat))
}

pub(super) fn parse_normalized_atr(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth = fields.usize(&["smooth"], 2)?;

    expect_pos_usize(window, "window")?;
    expect_pos_usize(smooth, "smooth")?;
    
    let feat = NormalizedATR { id: id.to_string(), window, smooth };
    Ok(Feature::NormalizedATR(feat))
}

pub(super) fn parse_roc(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let window = fields.usize(&["window"], 12)?;
    expect_pos_usize(window, "window")?;

    let feat = ROC { id: id.to_string(), ohlc, window };
    Ok(Feature::ROC(feat))
}

pub(super) fn parse_normalized_dc(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 20)?;
    let output_text = fields.string(&["output"], "middle")?;
    let output = parse_dc_output(&output_text)?;
    expect_pos_usize(window, "window")?;

    let feat = NormalizedDC { id: id.to_string(), window, output };
    Ok(Feature::NormalizedDC(feat))
}
