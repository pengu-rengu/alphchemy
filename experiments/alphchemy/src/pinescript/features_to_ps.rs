use crate::features::features::{
    Feature,
    OHLC,
    ReturnsType,
    Constant,
    RawReturns,
    NormalizedSMA,
    NormalizedEMA,
    NormalizedMACD,
    MACDOutput,
    RSI,
    NormalizedBB,
    BBOutput,
    Stochastic,
    StochasticOutput,
    NormalizedATR,
    ROC,
    NormalizedDC,
    DCOutput
};

pub fn feat_var(feat_id: &str) -> Result<String, String> {
    Ok(format!("feat_{feat_id}"))
}

fn ohlc_str(ohlc: OHLC) -> &'static str {
    match ohlc {
        OHLC::Open => "open",
        OHLC::High => "high",
        OHLC::Low => "low",
        OHLC::Close => "close"
    }
}

fn emit_constant(feat: &Constant) -> Result<String, String> {
    let var_name = feat_var(&feat.id)?;
    Ok(format!("{var_name} = {0}", feat.constant))
}

fn emit_raw_returns(feat: &RawReturns) -> Result<String, String> {
    let var_name = feat_var(&feat.id)?;
    let ohlc = ohlc_str(feat.ohlc);
    let body = match feat.returns_type {
        ReturnsType::Log => format!("math.log(nz({ohlc} / {ohlc}[1], 1.0))"),
        ReturnsType::Simple => format!("nz({ohlc} / {ohlc}[1], 1.0) - 1.0")
    };
    Ok(format!("{var_name} = {body}"))
}

fn emit_normalized_sma(feat: &NormalizedSMA) -> Result<String, String> {
    let var_name = feat_var(&feat.id)?;
    let ohlc = ohlc_str(feat.ohlc);
    let window = feat.window;
    Ok(format!("{var_name} = nz(custom_sma({ohlc}, {window}) / {ohlc})"))
}

fn emit_normalized_ema(feat: &NormalizedEMA) -> Result<String, String> {
    let var_name = feat_var(&feat.id)?;
    let ohlc = ohlc_str(feat.ohlc);
    Ok(format!("{var_name} = nz(custom_ema({ohlc}, {0}, {1}) / {ohlc})", feat.window, feat.smooth))
}

fn emit_normalized_macd(macd: &NormalizedMACD) -> Result<String, String> {
    let var_name = feat_var(&macd.id)?;
    let ohlc = ohlc_str(macd.ohlc);
    let fast = format!("custom_ema({ohlc}, {0}, {1})", macd.fast_window, macd.fast_smooth);
    let slow = format!("custom_ema({ohlc}, {0}, {1})", macd.slow_window, macd.slow_smooth);
    let line = format!("({fast} - {slow})");
    let signal = format!("custom_ema({line}, {0}, {1})", macd.signal_window, macd.signal_smooth);
    let body = match macd.output {
        MACDOutput::Line => line,
        MACDOutput::Signal => signal,
        MACDOutput::Hist => format!("{line} - {signal}")
    };
    Ok(format!("{var_name} = nz(({body}) / {ohlc})"))
}

fn emit_rsi(rsi: &RSI) -> Result<String, String> {
    let var_name = feat_var(&rsi.id)?;
    let ohlc = ohlc_str(rsi.ohlc);
    let window = rsi.window;
    let smooth = rsi.smooth;
    let change = format!("(bar_index == 0 ? 0.0 : {ohlc} - {ohlc}[1])");
    let gain = format!("math.max({change}, 0.0)");
    let loss = format!("math.max(-{change}, 0.0)");
    let avg_gain = format!("custom_ema({gain}, {window}, {smooth})");
    let avg_loss = format!("custom_ema({loss}, {window}, {smooth})");
    let relative_strength = format!("nz({avg_gain} / {avg_loss})");
    Ok(format!("{var_name} = 100.0 - nz(100.0 / (1.0 + {relative_strength}))"))
}

fn emit_normalized_bb(bb: &NormalizedBB) -> Result<String, String> {
    let var_name = feat_var(&bb.id)?;
    let ohlc = ohlc_str(bb.ohlc);
    let window = bb.window;
    let std_mult = bb.std_multiplier;
    let mean = format!("custom_sma({ohlc}, {window})");
    let deviation = format!("custom_stdev({ohlc}, {window})");
    let half_width = format!("{std_mult} * {deviation}");
    let body = match bb.output {
        BBOutput::Upper => format!("{mean} + {half_width}"),
        BBOutput::Lower => format!("{mean} - {half_width}"),
        BBOutput::Width => format!("2.0 * {half_width}")
    };
    Ok(format!("{var_name} = nz(({body}) / {ohlc})"))
}

fn emit_stochastic(stochastic: &Stochastic) -> Result<String, String> {
    let var_name = feat_var(&stochastic.id)?;
    let window = stochastic.window;
    let smooth_window = stochastic.smooth_window;
    let high = format!("custom_highest(high, {window})");
    let low = format!("custom_lowest(low, {window})");
    let range = format!("({high} - {low})");
    let percent_k = format!("(100.0 * nz((close - {low}) / {range}))");
    let body = match stochastic.output {
        StochasticOutput::PercentK => percent_k,
        StochasticOutput::PercentD => format!("custom_sma({percent_k}, {smooth_window})")
    };
    Ok(format!("{var_name} = {body}"))
}

fn emit_normalized_atr(atr: &NormalizedATR) -> Result<String, String> {
    let var_name = feat_var(&atr.id)?;
    let window = atr.window;
    let smooth = atr.smooth;
    let true_range = "bar_index == 0 ? high - low : math.max(math.max(high - low, math.abs(high - close[1])), math.abs(low - close[1]))";
    Ok(format!("{var_name} = nz(custom_ema({true_range}, {window}, {smooth}) / close)"))
}

fn emit_roc(roc: &ROC) -> Result<String, String> {
    let var_name = feat_var(&roc.id)?;
    let ohlc = ohlc_str(roc.ohlc);
    let window = roc.window;
    Ok(format!("{var_name} = nz({ohlc} / {ohlc}[{window}])"))
}

fn emit_normalized_dc(dc: &NormalizedDC) -> Result<String, String> {
    let var_name = feat_var(&dc.id)?;
    let window = dc.window;
    let upper = format!("custom_highest(high, {window})");
    let lower = format!("custom_lowest(low, {window})");
    let body = match dc.output {
        DCOutput::Upper => upper,
        DCOutput::Lower => lower,
        DCOutput::Middle => format!("({upper} + {lower}) / 2.0"),
        DCOutput::Width => format!("{upper} - {lower}")
    };
    Ok(format!("{var_name} = nz(({body}) / close)"))
}

fn emit_feat(feat: &Feature) -> Result<String, String> {
    match feat {
        Feature::Constant(constant) => emit_constant(constant),
        Feature::RawReturns(raw) => emit_raw_returns(raw),
        Feature::NormalizedSMA(sma) => emit_normalized_sma(sma),
        Feature::NormalizedEMA(ema) => emit_normalized_ema(ema),
        Feature::NormalizedMACD(macd) => emit_normalized_macd(macd),
        Feature::RSI(rsi) => emit_rsi(rsi),
        Feature::NormalizedBB(bb) => emit_normalized_bb(bb),
        Feature::Stochastic(stochastic) => emit_stochastic(stochastic),
        Feature::NormalizedATR(atr) => emit_normalized_atr(atr),
        Feature::ROC(roc) => emit_roc(roc),
        Feature::NormalizedDC(dc) => emit_normalized_dc(dc)
    }
}

pub fn emit_feats(feats: &[Feature]) -> Result<Vec<String>, String> {
    feats.iter().map(|feat| emit_feat(feat)).collect()
}
