use std::collections::HashSet;

use alphchemy_engine::features::features::{
    Feature, OHLC, Constant, RawReturns, ReturnsType
};
use crate::utils::validate_identifier;
use super::super::parse::Fields;
use super::parse_indicators::{
    parse_normalized_sma, parse_normalized_ema, parse_normalized_macd, parse_rsi,
    parse_normalized_bb, parse_stochastic, parse_normalized_atr, parse_roc, parse_normalized_dc
};

const MAX_FEATS: usize = 25;

// === Enum parsing ===

pub(super) fn parse_ohlc(text: &str) -> Result<OHLC, String> {
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

pub(super) fn field_ohlc(fields: &Fields) -> Result<OHLC, String> {
    let text = fields.string(&["ohlc"], "close")?;
    parse_ohlc(&text)
}

// === Feature parsing (id comes from the map key) ===

fn parse_constant(id: &str, fields: &Fields) -> Result<Feature, String> {
    let constant = fields.f64(&["constant"], 0.0)?;
    let feat = Constant { id: id.to_string(), constant };
    Ok(Feature::Constant(feat))
}

fn parse_raw_returns(id: &str, fields: &Fields) -> Result<Feature, String> {
    let returns_text = fields.string(&["returns_type"], "log")?;
    let returns_type = parse_returns_type(&returns_text)?;
    let ohlc = field_ohlc(fields)?;
    let feat = RawReturns { id: id.to_string(), returns_type, ohlc };
    Ok(Feature::RawReturns(feat))
}

fn parse_feat(id: &str, fields: &Fields) -> Result<Feature, String> {
    let feature = fields.string(&["feature"], "")?;

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

pub fn parse_feats(fields: Option<Fields<'_>>) -> Result<Vec<Feature>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut feats = Vec::with_capacity(fields.entries.len());

    for entry in &fields.entries {
        let feat_fields = Fields::from_lines(&entry.child_lines)?;
        let feat = parse_feat(entry.key, &feat_fields)?;
        feats.push(feat);
    }

    if feats.len() > MAX_FEATS { return Err(format!("Cannot have more than {MAX_FEATS} features")) }

    validate_feats(&feats)?;
    Ok(feats)
}

pub(super) fn expect_pos_usize(window: usize, field_name: &str) -> Result<(), String> {
    if window == 0 {
        return Err(format!("{field_name} must be > 0"));
    }
    Ok(())
}

pub(super) fn expect_pos_f64(value: f64, field_name: &str) -> Result<(), String> {
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
