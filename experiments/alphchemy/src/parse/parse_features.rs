use std::collections::HashSet;

use crate::features::features::{
    Feature, OHLC, Constant, RawReturns, ReturnsType,
    NormalizedSMA, NormalizedEMA, NormalizedMACD, MACDOutput, RSI, NormalizedBB, BBOutput,
    Stochastic, StochasticOutput, NormalizedATR, ROC, NormalizedDC, DCOutput
};
use crate::utils::validate_identifier;
use super::parse::Fields;

const MAX_FEATS: usize = 25;

// === Enum parsing ===

fn parse_ohlc(text: &str) -> Result<OHLC, String> {
    match text {
        "open" => Ok(OHLC::Open),
        "high" => Ok(OHLC::High),
        "low" => Ok(OHLC::Low),
        "close" => Ok(OHLC::Close),
        _ => Err(format!("invalid ohlc: {text}"))
    }
}

fn parse_returns_type(text: &str) -> Result<ReturnsType, String> {
    match text {
        "log" => Ok(ReturnsType::Log),
        "simple" => Ok(ReturnsType::Simple),
        _ => Err(format!("invalid returns_type: {text}"))
    }
}

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

fn field_ohlc(fields: &Fields) -> Result<OHLC, String> {
    let text = fields.string(&["ohlc"], "close");
    parse_ohlc(&text)
}

// === Feature parsing (id comes from the map key) ===

fn parse_constant(id: &str, fields: &Fields) -> Result<Feature, String> {
    let constant = fields.f64(&["constant"], 0.0)?;
    let feat = Constant { id: id.to_string(), constant };
    Ok(Feature::Constant(feat))
}

fn parse_raw_returns(id: &str, fields: &Fields) -> Result<Feature, String> {
    let returns_text = fields.string(&["returns_type"], "log");
    let returns_type = parse_returns_type(&returns_text)?;
    let ohlc = field_ohlc(fields)?;
    let feat = RawReturns { id: id.to_string(), returns_type, ohlc };
    Ok(Feature::RawReturns(feat))
}

fn parse_normalized_sma(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let window = fields.usize(&["window"], 14)?;
    validate_window(window, "window")?;
    let feat = NormalizedSMA { id: id.to_string(), ohlc, window };
    Ok(Feature::NormalizedSMA(feat))
}

fn parse_normalized_ema(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth = fields.usize(&["smooth"], 2)?;
    let ohlc = field_ohlc(fields)?;

    validate_window(window, "window")?;
    validate_window(smooth, "smooth")?;

    let feat = NormalizedEMA { id: id.to_string(), window, smooth, ohlc };
    Ok(Feature::NormalizedEMA(feat))
}

fn parse_normalized_macd(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let fast_window = fields.usize(&["fast_window"], 12)?;
    let fast_smooth = fields.usize(&["fast_smooth"], 2)?;
    let slow_window = fields.usize(&["slow_window"], 26)?;
    let slow_smooth = fields.usize(&["slow_smooth"], 2)?;
    let signal_window = fields.usize(&["signal_window"], 9)?;
    let signal_smooth = fields.usize(&["signal_smooth"], 2)?;
    let output_text = fields.string(&["output"], "hist");
    let output = parse_macd_output(&output_text)?;

    validate_window(fast_window, "fast_window")?;
    validate_window(slow_window, "slow_window")?;
    validate_window(signal_window, "signal_window")?;
    validate_window(fast_smooth, "fast_smooth")?;
    validate_window(slow_smooth, "slow_smooth")?;
    validate_window(signal_smooth, "signal_smooth")?;
    if fast_window > slow_window {
        return Err("fast_window must be <= slow_window".to_string());
    }

    let feat = NormalizedMACD {
        id: id.to_string(), ohlc, fast_window, fast_smooth, slow_window, slow_smooth, signal_window, signal_smooth, output
    };
    Ok(Feature::NormalizedMACD(feat))
}

fn parse_rsi(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth = fields.usize(&["smooth"], 2)?;
    let ohlc = field_ohlc(fields)?;
    validate_window(window, "window")?;
    validate_window(smooth, "smooth")?;
    let feat = RSI { id: id.to_string(), window, smooth, ohlc };
    Ok(Feature::RSI(feat))
}

fn parse_normalized_bb(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let window = fields.usize(&["window"], 14)?;
    let std_multiplier = fields.f64(&["std_multiplier", "std_mult"], 2.0)?;
    let output_text = fields.string(&["output"], "upper");
    let output = parse_bb_output(&output_text)?;
    validate_window(window, "window")?;
    validate_positive(std_multiplier, "std_mult")?;
    let feat = NormalizedBB { id: id.to_string(), ohlc, window, std_multiplier, output };
    Ok(Feature::NormalizedBB(feat))
}

fn parse_stochastic(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth_window = fields.usize(&["smooth_window"], 3)?;
    let output_text = fields.string(&["output"], "percent_k");
    let output = parse_stochastic_output(&output_text)?;
    validate_window(window, "window")?;
    validate_window(smooth_window, "smooth_window")?;
    let feat = Stochastic { id: id.to_string(), window, smooth_window, output };
    Ok(Feature::Stochastic(feat))
}

fn parse_normalized_atr(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 14)?;
    let smooth = fields.usize(&["smooth"], 2)?;
    validate_window(window, "window")?;
    validate_window(smooth, "smooth")?;
    let feat = NormalizedATR { id: id.to_string(), window, smooth };
    Ok(Feature::NormalizedATR(feat))
}

fn parse_roc(id: &str, fields: &Fields) -> Result<Feature, String> {
    let ohlc = field_ohlc(fields)?;
    let window = fields.usize(&["window"], 12)?;
    validate_window(window, "window")?;
    let feat = ROC { id: id.to_string(), ohlc, window };
    Ok(Feature::ROC(feat))
}

fn parse_normalized_dc(id: &str, fields: &Fields) -> Result<Feature, String> {
    let window = fields.usize(&["window"], 20)?;
    let output_text = fields.string(&["output"], "middle");
    let output = parse_dc_output(&output_text)?;
    validate_window(window, "window")?;
    let feat = NormalizedDC { id: id.to_string(), window, output };
    Ok(Feature::NormalizedDC(feat))
}

fn parse_feat(id: &str, fields: &Fields) -> Result<Feature, String> {
    let feature = fields.string(&["feature"], "");

    match feature.as_str() {
        "constant" => parse_constant(id, fields),
        "raw_returns" => parse_raw_returns(id, fields),
        "normalized_sma" => parse_normalized_sma(id, fields),
        "normalized_ema" => parse_normalized_ema(id, fields),
        "normalized_macd" => parse_normalized_macd(id, fields),
        "rsi" => parse_rsi(id, fields),
        "normalized_bb" => parse_normalized_bb(id, fields),
        "stochastic" => parse_stochastic(id, fields),
        "normalized_atr" => parse_normalized_atr(id, fields),
        "roc" => parse_roc(id, fields),
        "normalized_dc" => parse_normalized_dc(id, fields),
        _ => Err(format!("invalid feature: {feature}"))
    }
}

pub fn parse_feats(fields: &Fields<'_>) -> Result<Vec<Feature>, String> {
    let mut feats = Vec::with_capacity(fields.entries.len());

    for entry in &fields.entries {
        let feat_fields = Fields::from_lines(&entry.child_lines);
        let feat = parse_feat(entry.key, &feat_fields)?;
        feats.push(feat);
    }

    if feats.len() > MAX_FEATS { return Err(format!("Cannot have more than {MAX_FEATS} features")) }

    validate_feats(&feats)?;
    Ok(feats)
}

// === Validation ===

fn validate_window(window: usize, field_name: &str) -> Result<(), String> {
    if window == 0 {
        return Err(format!("{field_name} must be > 0"));
    }
    Ok(())
}

fn validate_positive(value: f64, field_name: &str) -> Result<(), String> {
    if value <= 0.0 {
        return Err(format!("{field_name} must be > 0.0"));
    }
    Ok(())
}

fn validate_feats(feats: &[Feature]) -> Result<(), String> {
    let mut ids = HashSet::new();

    for feat in feats {
        let feat_id = feat.id();
        validate_identifier(&feat_id, "feature id")?;
        if !ids.insert(feat_id) { return Err(format!("duplicate feature id: {}", feat.id())) }
    }

    Ok(())
}
