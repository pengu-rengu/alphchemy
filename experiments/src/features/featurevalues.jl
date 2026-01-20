module FeatureValuesModule

using ..FeaturesModule
using MarketTechnicals
using RollingFunctions

function get_values(feature::Constant, data::TimeArray)::Vector{Float64}
    
    data_len = length(data)
    return fill(feature.constant, data_len)
end

function get_values(feature::RawReturns, data::TimeArray)::Vector{Float64}
    price_values = values(data[feature.ohlc])

    if feature.returns_type == :simple
        ratios = (@view price_values[2:end]) ./ (@view price_values[1:end-1])
        returns = ratios .- 1.0
    elseif feature.returns_type == :log
        returns = log_returns(price_values)
    end

    return vcat(NaN, returns)
end

function get_values(feature::RollingZScore, data::TimeArray)
    price_values = values(data[feature.ohlc])
    window = feature.window

    μ = rollmean(price_values, window)
    σ = rollstd(price_values, window)

    diffs = (@view price_values[window:end]) .- μ

    z_scores = diffs ./ σ

    return pad_vector(z_scores, data)
end

function get_values(feature::NormalizedSMA, data::TimeArray)::Vector{Float64}
    sma_array = sma(data[feature.ohlc], feature.window)
    return pad_and_normalize(sma_array, data)
end

function get_values(feature::NormalizedEMA, data::TimeArray)::Vector{Float64}
    ema_array = ema(data[feature.ohlc], feature.window, wilder = feature.wilder)
    return pad_and_normalize(ema_array, data)
end

function get_values(feature::NormalizedKAMA, data::TimeArray)::Vector{Float64}
    kama_array = kama(data[feature.ohlc], feature.window, feature.fast_window, feature.slow_window)
    return pad_and_normalize(kama_array, data)
end

function get_values(feature::RSI, data::TimeArray)::Vector{Float64}
    rsi_array = rsi(data[feature.ohlc], feature.window, wilder = feature.wilder)
    return pad_array(rsi_array, data)
end

function get_values(feature::ADX, data::TimeArray)::Vector{Float64}
    adx_array = adx(data, feature.window, h = :high, l = :low, c = :close)
    column = Dict(:positive => :di_plus, :negative => :di_minus)[feature.direction]
    return pad_array(adx_array[column], data)
end

function get_values(feature::Aroon, data::TimeArray)::Vector{Float64}
    aroon_array = aroon(data, feature.window, h = :high, l = :low)
    return pad_array(aroon_array[feature.direction], data)
end

function get_values(feature::NormalizedAO, data::TimeArray)::Vector{Float64}
    ao_array = awesomeoscillator(data, h = :high, l = :low)
    return pad_and_normalize(ao_array, data)
end

function get_values(feature::NormalizedDPO, data::TimeArray)::Vector{Float64}
    dpo_array = dpo(data[feature.ohlc], feature.window)
    return pad_and_normalize(dpo_array, data)
end

function get_values(feature::MassIndex, data::TimeArray)::Vector{Float64}
    window = feature.window

    mi_array = massindex(data, window, window, h = :high, l = :low)
    return pad_array(mi_array, data)
end

function get_values(feature::TRIX, data::TimeArray)::Vector{Float64}
    trix_array = trix(data[feature.ohlc], feature.window)
    return pad_array(trix_array, data)
end

function get_values(feature::Vortex, data::TimeArray)::Vector{Float64}
    vortex_array = vortex(data, feature.window, h = :high, l = :low, c = :close)
    column = Dict(:positive => :v_plus, :negative => :v_minus)[feature.direction]
    return pad_array(vortex_array[column], data)
end

function get_values(feature::WilliamsR, data::TimeArray)::Vector{Float64}
    williamsr_array = williamsr(data, feature.window, c = :close, h = :high, l = :low)
    return pad_array(williamsr_array, data)
end

function get_values(feature::Stochastic, data::TimeArray)::Vector{Float64}
    stoch_array = stochasticoscillator(data, feature.window, feature.fast_window, feature.slow_window, h = :high, l = :low, c = :close)
    return pad_array(stoch_array[feature.output], data)
end

function get_values(feature::NormalizedMACD, data::TimeArray)::Vector{Float64}
    macd_array = macd(data[feature.ohlc], feature.fast_window, feature.slow_window, feature.signal_window)
    output = feature.output
    column = output == :diff ? :dif : output
    return pad_and_normalize(macd_array[column], data)
end

function get_values(feature::NormalizedATR, data::TimeArray)::Vector{Float64}
    atr_array = atr(data, feature.window, h = :high, l = :low, c = :close)
    return pad_and_normalize(atr_array, data)
end

function get_values(feature::NormalizedBB, data::TimeArray)::Vector{Float64}
    bb_array = bollingerbands(data[feature.ohlc], feature.window, feature.std_multiplier)
    column = Dict(:upper => :up, :lower => :down, :middle => :mean)[feature.band]
    return pad_and_normalize(bb_array[column], data)
end

function get_values(feature::NormalizedDC, data::TimeArray)::Vector{Float64}
    dc_array = donchianchannels(data, feature.window, h = :high, l = :low)
    column = Dict(:upper => :up, :lower => :down, :middle => :mid)[feature.channel]
    return pad_and_normalize(dc_array[column], data)
end

function get_values(feature::NormalizedKC, data::TimeArray)::Vector{Float64}
    kc_array = keltnerbands(data, feature.window, feature.multiplier, h = :high, l = :low, c = :close)
    column = Dict(:upper => :kup, :lower => :kdn, :middle => :kma)[feature.channel]
    return pad_and_normalize(kc_array[column], data)
end

export get_values

function get_feat_matrix(features::Vector{AbstractFeature}, data::TimeArray)::Matrix{Float64}
    data_len = length(data)
    n_features = length(features)
    
    matrix = Matrix{Float64}(undef, data_len, n_features)
    
    for i ∈ 1:n_features
        matrix[:, i] = get_values(features[i], data)
    end

    return matrix
end
export get_feat_matrix

end