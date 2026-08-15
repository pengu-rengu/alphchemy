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

    fn parse_returns_type(&self, text: &str) -> Result<ReturnsType, String> {
        match text {
            "log" => Ok(ReturnsType::Log),
            "simple" => Ok(ReturnsType::Simple),
            _ => Err(format!("invalid returns_type: {text}"))
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

fn _parse_constant<T>(deps: &T, id: &str, fields: &Fields) -> Result<Feature, String> where T: ParseFeaturesDeps {
    let constant = deps.f64(fields, &["constant"], 0.0)?;
    let feat = Constant { id: id.to_string(), constant };
    Ok(Feature::Constant(feat))
}

fn parse_constant(id: &str, fields: &Fields) -> Result<Feature, String> {
    _parse_constant(&ParseFeaturesDepsImpl, id, fields)
}

fn _parse_raw_returns<T>(deps: &T, id: &str, fields: &Fields) -> Result<Feature, String> where T: ParseFeaturesDeps {
    let returns_text = deps.string(fields, &["returns_type"], "log")?;
    let returns_type = deps.parse_returns_type(&returns_text)?;
    let ohlc = deps.field_ohlc(fields)?;
    let feat = RawReturns { id: id.to_string(), returns_type, ohlc };
    Ok(Feature::RawReturns(feat))
}

fn parse_raw_returns(id: &str, fields: &Fields) -> Result<Feature, String> {
    _parse_raw_returns(&ParseFeaturesDepsImpl, id, fields)
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

pub(super) fn field_ohlc(fields: &Fields) -> Result<OHLC, String> {
    ParseFeaturesDepsImpl.field_ohlc(fields)
}

pub fn parse_feats(fields: Option<Fields>) -> Result<Vec<Feature>, String> {
    ParseFeaturesDepsImpl.parse_feats(fields)
}

pub(super) fn expect_pos_usize(value: usize, field_name: &str) -> Result<(), String> {
    if value == 0 {
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
    use crate::parse::parse::tests::{gen_fields, gen_entry};
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize_with_max, gen_usize_with_min, gen_usize_between};
    use hegel::{TestCase, 
        generators::{sampled_from, booleans}
    };
    use std::cell::Cell;

    mod parse_returns_type_tests {
        use super::*;

        #[test]
        fn test_parse_returns_type_log() {
            let result = ParseFeaturesDepsImpl.parse_returns_type("log");
            assert_eq!(result, Ok(ReturnsType::Log));
        }

        #[test]
        fn test_parse_returns_type_simple() {
            let result = ParseFeaturesDepsImpl.parse_returns_type("simple");
            assert_eq!(result, Ok(ReturnsType::Simple));
        }

        #[hegel::test]
        fn test_parse_returns_type_invalid(tc: TestCase) {
            let text = tc.draw(gen_text());
            let is_valid = matches!(text.as_str(), "log" | "simple");
            tc.assume(!is_valid);
            let result = ParseFeaturesDepsImpl.parse_returns_type(&text);
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

    mod parse_raw_returns_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { String, ParseReturnsType, FieldOhlc }

        #[derive(Debug)]
        struct TestContext {
            expected_feature: Feature,
            result: Result<Feature, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[
                InvalidCase::String, InvalidCase::ParseReturnsType, InvalidCase::FieldOhlc
            ]));

            let fields = tc.draw(gen_fields());
            let id = tc.draw(gen_text());
            let returns_text = tc.draw(gen_text());
            let returns_type = tc.draw(sampled_from(vec![ReturnsType::Log, ReturnsType::Simple]));
            let ohlc = tc.draw(sampled_from(vec![OHLC::Open, OHLC::High, OHLC::Low, OHLC::Close]));
            let raw_returns = RawReturns { id: id.clone(), returns_type, ohlc };
            let expected_feature = Feature::RawReturns(raw_returns);

            let mut mock_deps = MockParseFeaturesDeps::new();

            mock_deps.expect_string()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["returns_type"] && default == "log"
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::String { Err(String::new()) } else { Ok(returns_text.clone()) });

            mock_deps.expect_parse_returns_type()
                .times(usize::from(!draw_invalid || invalid_case != InvalidCase::String))
                .withf({
                    let expected_text = returns_text.clone();
                    move |text| *text == expected_text
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::ParseReturnsType { Err(String::new()) } else { Ok(returns_type) });

            mock_deps.expect_field_ohlc()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::FieldOhlc))
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields| *actual_fields == expected_fields
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::FieldOhlc { Err(String::new()) } else { Ok(ohlc) });

            let result = _parse_raw_returns(&mock_deps, &id, &fields);
            TestContext { expected_feature, result }
        }

        #[hegel::test]
        fn test_parse_raw_returns(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_feature));
        }

        #[hegel::test]
        fn test_parse_raw_returns_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod field_ohlc_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_ohlc: OHLC,
            result: Result<OHLC, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_text = draw_invalid && tc.draw(booleans());

            let fields = tc.draw(gen_fields());
            let text = tc.draw(gen_text());
            let expected_ohlc = tc.draw(sampled_from(vec![OHLC::Open, OHLC::High, OHLC::Low, OHLC::Close]));


            let mut mock_deps = MockParseFeaturesDeps::new();
            mock_deps.expect_string()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["ohlc"] && default == "close"
                    }
                })
                .return_const(if invalid_text { Err(String::new()) } else { Ok(text.clone()) });

            mock_deps.expect_parse_ohlc()
                .times(usize::from(!invalid_text))
                .withf(move |actual_text| *actual_text == text)
                .return_const(if draw_invalid && !invalid_text { Err(String::new()) } else { Ok(expected_ohlc) });

            let result = _field_ohlc(&mock_deps, &fields);
            TestContext { expected_ohlc, result }
        }

        #[hegel::test]
        fn test_field_ohlc(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_ohlc));
        }

        #[hegel::test]
        fn test_field_ohlc_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod validate_feats_tests {

        use super::*;

        #[derive(Debug)]
        struct TestContext {
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_id = draw_invalid && tc.draw(booleans());
            let invalid_dup = draw_invalid && !invalid_id;

            let n_feats = if invalid_id {
                tc.draw(gen_usize_between(1, 10))
            } else if invalid_dup {
                tc.draw(gen_usize_between(2, 10))
            } else {
                tc.draw(gen_usize_with_max(10))
            };

            let mut feats = Vec::new();
            for i in 0..n_feats {
                let constant = Constant { id: i.to_string(), constant: tc.draw(gen_f64()) };
                let feat = Feature::Constant(constant);
                feats.push(feat);
            }

            let invalid_idx = if draw_invalid { tc.draw(gen_usize_with_max(n_feats - 1)) } else { 0 };
            if invalid_dup {
                let src_idx = tc.draw(gen_usize_with_max(invalid_idx));
                feats[invalid_idx] = feats[src_idx].clone();
            }

            let idx = Cell::new(0);
            
            let mut mock_deps = MockParseFeaturesDeps::new();
            mock_deps.expect_validate_identifier()
                .times(if draw_invalid { invalid_idx + 1 } else { n_feats })
                .withf(move |_, field| field == "feature id")
                .returning(move |_, _| {
                    let i = idx.get();
                    if draw_invalid && i == invalid_idx { return Err(String::new()) }
                    idx.set(i + 1);
                    Ok(())
                });

            let result = _validate_feats(&mock_deps, &feats);
            TestContext { result }
        }

        #[hegel::test]
        fn test_validate_feats(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(()));
        }

        #[hegel::test]
        fn test_validate_feats_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_feats_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { FeatFields, ParseFeat, TooMany, Validate }

        #[derive(Debug)]
        struct TestContext {
            expected_feats: Vec<Feature>,
            result: Result<Vec<Feature>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[InvalidCase::FeatFields, InvalidCase::ParseFeat, InvalidCase::TooMany, InvalidCase::Validate]));
            let invalid_feat_fields = draw_invalid && invalid_case == InvalidCase::FeatFields;
            let invalid_parse_feat = draw_invalid && invalid_case == InvalidCase::ParseFeat;
            let invalid_in_loop = invalid_feat_fields || invalid_parse_feat;

            let n_feats = tc.draw(if invalid_in_loop {
                gen_usize_between(1, MAX_FEATS)
            } else if draw_invalid && invalid_case == InvalidCase::TooMany {
                gen_usize_with_min(MAX_FEATS + 1)
            } else {
                gen_usize_with_max(MAX_FEATS)
            });
            let invalid_idx = if invalid_in_loop { tc.draw(gen_usize_with_max(n_feats - 1)) } else { 0 };

            let mut expected_feats = Vec::with_capacity(n_feats);
            let mut expected_fields = Vec::with_capacity(n_feats);
            let mut entries = Vec::with_capacity(n_feats);

            for _ in 0..n_feats {
                let entry = tc.draw(gen_entry(None, None));
                let constant = Constant { id: entry.key.clone(), constant: tc.draw(gen_f64()) };
                let feat = Feature::Constant(constant);

                expected_feats.push(feat);
                entries.push(entry);
                expected_fields.push(tc.draw(gen_fields()));
            }

            let fields = if n_feats == 0 {
                if tc.draw(booleans()) { Some(Fields { entries }) } else { None }
            } else {
                Some(Fields { entries })
            };

            let mut mock_deps = MockParseFeaturesDeps::new();

            let idx_for_fields = Cell::new(0);
            let fields_for_from_lines = expected_fields.clone();
            mock_deps.expect_fields_from_lines()
                .times(if invalid_in_loop { invalid_idx + 1 } else { n_feats })
                .returning(move |_| {
                    let i = idx_for_fields.get();
                    if invalid_feat_fields && i == invalid_idx { return Err(String::new()) }
                    idx_for_fields.set(i + 1);
                    Ok(fields_for_from_lines[i].clone())
                });
            
            let idx_for_feat = Cell::new(0);
            mock_deps.expect_parse_feat()
                .times(if invalid_in_loop { invalid_idx + usize::from(invalid_parse_feat) } else { n_feats })
                .returning({
                    let feats_for_parse = expected_feats.clone();
                    move |_, _| {
                        let i = idx_for_feat.get();
                        if invalid_parse_feat && i == invalid_idx { return Err(String::new()) }
                        idx_for_feat.set(i + 1);
                        Ok(feats_for_parse[i].clone())
                    }
                });

            mock_deps.expect_validate_feats()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::Validate))
                .withf({
                    let feats_for_validate = expected_feats.clone();
                    move |feats| *feats == feats_for_validate
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Validate { Err(String::new()) } else { Ok(()) });

            let result = _parse_feats(&mock_deps, fields);
            TestContext { expected_feats, result }
        }

        #[hegel::test]
        fn test_parse_feats(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_feats));
        }

        #[hegel::test]
        fn test_parse_feats_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}