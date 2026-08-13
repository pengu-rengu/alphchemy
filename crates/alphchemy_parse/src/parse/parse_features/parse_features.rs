use std::collections::HashSet;

use alphchemy_engine::features::features::{
    Feature, OHLC, Constant, RawReturns, ReturnsType
};
use crate::utils::validate_identifier;
use super::super::parse::{Fields, Line};
use super::parse_indicators::{
    parse_normalized_sma, parse_normalized_ema, parse_normalized_macd, parse_rsi,
    parse_normalized_bb, parse_stochastic, parse_normalized_atr, parse_roc, parse_normalized_dc
};

#[cfg(test)]
use mockall::automock;

const MAX_FEATS: usize = 25;

#[cfg_attr(test, automock)]
trait ParseFeaturesDeps {
    fn string<'a>(&self, fields: &Fields, keys: &[&'a str], default: &str) -> Result<String, String> {
        fields.string(keys, default)
    }

    fn f64<'a>(&self, fields: &Fields, keys: &[&'a str], default: f64) -> Result<f64, String> {
        fields.f64(keys, default)
    }

    fn fields_from_lines(&self, lines: &[Line]) -> Result<Fields, String> {
        Fields::from_lines(lines)
    }

    fn parse_ohlc(&self, text: &str) -> Result<OHLC, String> {
        match text {
            "open" => Ok(OHLC::Open),
            "high" => Ok(OHLC::High),
            "low" => Ok(OHLC::Low),
            "close" => Ok(OHLC::Close),
            _ => Err(format!("invalid ohlc: {text}"))
        }
    }

    fn field_ohlc(&self, fields: &Fields) -> Result<OHLC, String> {
        _field_ohlc(&ParseFeaturesDepsImpl, fields)
    }

    fn parse_feat(&self, id: &str, fields: &Fields) -> Result<Feature, String> {
        _parse_feat(&ParseFeaturesDepsImpl, id, fields)
    }

    fn validate_identifier(&self, id: &str, field: &str) -> Result<(), String> {
        validate_identifier(id, field)
    }

    fn validate_feats(&self, feats: &[Feature]) -> Result<(), String> {
        _validate_feats(&ParseFeaturesDepsImpl, feats)
    }

    fn parse_feats(&self, fields: Option<Fields>) -> Result<Vec<Feature>, String> {
        _parse_feats(&ParseFeaturesDepsImpl, fields)
    }
}

struct ParseFeaturesDepsImpl;
impl ParseFeaturesDeps for ParseFeaturesDepsImpl {}

fn parse_returns_type(text: &str) -> Result<ReturnsType, String> {
    match text {
        "log" => Ok(ReturnsType::Log),
        "simple" => Ok(ReturnsType::Simple),
        _ => Err(format!("invalid returns_type: {text}"))
    }
}

fn _parse_constant<T>(deps: &T, id: &str, fields: &Fields) -> Result<Feature, String> where T: ParseFeaturesDeps {
    let constant = deps.f64(fields, &["constant"], 0.0)?;
    let feat = Constant { id: id.to_string(), constant };
    Ok(Feature::Constant(feat))
}

fn parse_constant(id: &str, fields: &Fields) -> Result<Feature, String> {
    _parse_constant(&ParseFeaturesDepsImpl, id, fields)
}

fn parse_raw_returns(id: &str, fields: &Fields) -> Result<Feature, String> {
    let returns_text = fields.string(&["returns_type"], "log")?;
    let returns_type = parse_returns_type(&returns_text)?;
    let ohlc = field_ohlc(fields)?;
    let feat = RawReturns { id: id.to_string(), returns_type, ohlc };
    Ok(Feature::RawReturns(feat))
}

fn _field_ohlc<T>(deps: &T, fields: &Fields) -> Result<OHLC, String> where T: ParseFeaturesDeps {
    let text = deps.string(fields, &["ohlc"], "close")?;
    deps.parse_ohlc(&text)
}

fn _parse_feat<T>(deps: &T, id: &str, fields: &Fields) -> Result<Feature, String> where T: ParseFeaturesDeps {
    let feature = deps.string(fields, &["feature"], "")?;

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

fn _validate_feats<T>(deps: &T, feats: &[Feature]) -> Result<(), String> where T: ParseFeaturesDeps {
    let mut ids = HashSet::new();

    for feat in feats {
        let feat_id = feat.id();
        deps.validate_identifier(&feat_id, "feature id")?;
        if !ids.insert(feat_id) { return Err(format!("duplicate feature id: {}", feat.id())) }
    }

    Ok(())
}

fn _parse_feats<T>(deps: &T, fields: Option<Fields>) -> Result<Vec<Feature>, String> where T: ParseFeaturesDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut feats = Vec::with_capacity(fields.entries.len());

    for entry in &fields.entries {
        let feat_fields = deps.fields_from_lines(&entry.child_lines)?;
        let feat = deps.parse_feat(&entry.key, &feat_fields)?;
        feats.push(feat);
    }

    if feats.len() > MAX_FEATS { return Err(format!("Cannot have more than {MAX_FEATS} features")) }

    deps.validate_feats(&feats)?;
    Ok(feats)
}

pub(super) fn parse_ohlc(text: &str) -> Result<OHLC, String> {
    ParseFeaturesDepsImpl.parse_ohlc(text)
}

pub(super) fn field_ohlc(fields: &Fields) -> Result<OHLC, String> {
    ParseFeaturesDepsImpl.field_ohlc(fields)
}

pub fn parse_feats(fields: Option<Fields>) -> Result<Vec<Feature>, String> {
    ParseFeaturesDepsImpl.parse_feats(fields)
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::parse::tests::gen_fields;
    use alphchemy_test_utils::{gen_f64, gen_text};
    use hegel::TestCase;

    mod parse_returns_type_tests {
        use super::*;

        #[test]
        fn test_parse_returns_type_log() {
            let result = parse_returns_type("log");
            assert_eq!(result, Ok(ReturnsType::Log));
        }

        #[test]
        fn test_parse_returns_type_simple() {
            let result = parse_returns_type("simple");
            assert_eq!(result, Ok(ReturnsType::Simple));
        }

        #[hegel::test]
        fn test_parse_returns_type_invalid(tc: TestCase) {
            let text = tc.draw(gen_text());
            let is_valid = matches!(text.as_str(), "log" | "simple");
            tc.assume(!is_valid);
            let result = parse_returns_type(&text);
            assert!(result.is_err());
        }
    }

    mod parse_constant_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_feature: Feature,
            result: Result<Feature, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let fields = tc.draw(gen_fields());
            let id = tc.draw(gen_text());
            let constant = tc.draw(gen_f64());
            let constant_feat = Constant { id: id.clone(), constant };
            let expected_feature = Feature::Constant(constant_feat);

            let mut mock_deps = MockParseFeaturesDeps::new();
            mock_deps.expect_f64()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["constant"] && *default == 0.0
                    }
                })
                .return_const(if draw_invalid { Err(String::new()) } else { Ok(constant) });

            let result = _parse_constant(&mock_deps, &id, &fields);
            TestContext { expected_feature, result }
        }

        #[hegel::test]
        fn test_parse_constant(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_feature));
        }

        #[hegel::test]
        fn test_parse_constant_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}