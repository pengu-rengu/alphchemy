module FeatureValuesModule

using ..FeaturesModule
using MarketTechnicals
using RollingFunctions

function get_values(feat::Constant, data::TimeArray)::Vector{Float64}
    
    data_len = length(data)
    return fill(feat.constant, data_len)
end

function get_values(feat::RawReturns, data::TimeArray)::Vector{Float64}
    price_values = values(data[feat.ohlc])

    if feat.returns_type == :simple
        ratios = (@view price_values[2:end]) ./ (@view price_values[1:end-1])
        returns = ratios .- 1.0
    elseif feat.returns_type == :log
        returns = log_returns(price_values)
    end
    
    return vcat(NaN, returns)
end

function get_values(feat::RollingZScore, data::TimeArray)
    price_values = values(data[feat.ohlc])
    window = feat.window

    μ = rollmean(price_values, window)
    σ = rollstd(price_values, window)

    diffs = (@view price_values[window:end]) .- μ
    
    z_scores = diffs ./ σ

    return pad_vector(z_scores, data)
end

function get_values(feat::NormalizedSMA, data::TimeArray)::Vector{Float64}
    sma_array = sma(data[feat.ohlc], feat.window)
    return pad_and_normalize(sma_array, data)
end

function get_values(feat::NormalizedEMA, data::TimeArray)::Vector{Float64}
    ema_array = ema(data[feat.ohlc], feat.window, wilder = feat.wilder)
    return pad_and_normalize(ema_array, data)
end

function get_values(feat::NormalizedKAMA, data::TimeArray)::Vector{Float64}
    kama_array = kama(data[feat.ohlc], feat.window, feat.fast_window, feat.slow_window)
    return pad_and_normalize(kama_array, data)
end

function get_values(feat::RSI, data::TimeArray)::Vector{Float64}
    rsi_array = rsi(data[feat.ohlc], feat.window, wilder = feat.wilder)
    return pad_array(rsi_array, data)
end

function get_values(feat::ADX, data::TimeArray)::Vector{Float64}
    adx_array = adx(data, feat.window, h = :high, l = :low, c = :close)
    column = Dict(:pos => :di_plus, :neg => :di_minus)[feat.out]
    return pad_array(adx_array[column], data)
end

function get_values(feat::Aroon, data::TimeArray)::Vector{Float64}
    aroon_array = aroon(data, feat.window, h = :high, l = :low)
    return pad_array(aroon_array[feat.out], data)
end

function get_values(feat::NormalizedAO, data::TimeArray)::Vector{Float64}
    ao_array = awesomeoscillator(data, h = :high, l = :low)
    return pad_and_normalize(ao_array, data)
end

function get_values(feat::NormalizedDPO, data::TimeArray)::Vector{Float64}
    dpo_array = dpo(data[feat.ohlc], feat.window)
    return pad_and_normalize(dpo_array, data)
end

function get_values(feat::MassIndex, data::TimeArray)::Vector{Float64}
    window = feat.window

    mi_array = massindex(data, window, window, h = :high, l = :low)
    return pad_array(mi_array, data)
end

function get_values(feat::TRIX, data::TimeArray)::Vector{Float64}
    trix_array = trix(data[feat.ohlc], feat.window)
    return pad_array(trix_array, data)
end

function get_values(feat::Vortex, data::TimeArray)::Vector{Float64}
    vortex_array = vortex(data, feat.window, h = :high, l = :low, c = :close)
    column = Dict(:pos => :v_plus, :neg => :v_minus)[feat.out]
    return pad_array(vortex_array[column], data)
end

function get_values(feat::WilliamsR, data::TimeArray)::Vector{Float64}
    williamsr_array = williamsr(data, feat.window, c = :close, h = :high, l = :low)
    return pad_array(williamsr_array, data)
end

function get_values(feat::Stochastic, data::TimeArray)::Vector{Float64}
    stoch_array = stochasticoscillator(data, feat.window, feat.fast_window, feat.slow_window, h = :high, l = :low, c = :close)
    return pad_array(stoch_array[feat.out], data)
end

function get_values(feat::NormalizedMACD, data::TimeArray)::Vector{Float64}
    macd_array = macd(data[feat.ohlc], feat.fast_window, feat.slow_window, feat.signal_window)

    out = feat.out
    column = out == :diff ? :dif : out

    return pad_and_normalize(macd_array[column], data)
end

function get_values(feat::NormalizedATR, data::TimeArray)::Vector{Float64}
    atr_array = atr(data, feat.window, h = :high, l = :low, c = :close)
    return pad_and_normalize(atr_array, data)
end

function get_values(feat::NormalizedBB, data::TimeArray)::Vector{Float64}
    bb_array = bollingerbands(data[feat.ohlc], feat.window, feat.multiplier)
    column = Dict(:upper => :up, :lower => :down, :middle => :mean)[feat.out]
    return pad_and_normalize(bb_array[column], data)
end

function get_values(feat::NormalizedDC, data::TimeArray)::Vector{Float64}
    dc_array = donchianchannels(data, feat.window, h = :high, l = :low)
    column = Dict(:upper => :up, :lower => :down, :middle => :mid)[feat.out]
    return pad_and_normalize(dc_array[column], data)
end

function get_values(feat::NormalizedKC, data::TimeArray)::Vector{Float64}
    kc_array = keltnerbands(data, feat.window, feat.multiplier, h = :high, l = :low, c = :close)
    column = Dict(:upper => :kup, :lower => :kdn, :middle => :kma)[feat.out]
    return pad_and_normalize(kc_array[column], data)
end

export get_values

function get_feat_matrix(feats::Vector{AbstractFeature}, data::TimeArray)::Matrix{Float64}
    data_len = length(data)
    n_feats = length(feats)
    
    matrix = Matrix{Float64}(undef, data_len, n_feats)
    
    for i ∈ 1:n_feats
        matrix[:, i] = get_values(feats[i], data)
    end
    
    return matrix
end
export get_feat_matrix

end