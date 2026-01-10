module FeaturesModule

using TimeSeries
using RollingFunctions

abstract type AbstractFeature end
export AbstractFeature

@kwdef struct Constant <: AbstractFeature
    id::String
    constant::Float64
end
export Constant

@kwdef struct RawReturns <: AbstractFeature
    id::String
    returns_type::Symbol
    ohlc::Symbol
end
export RawReturns

@kwdef struct RollingZScore <: AbstractFeature
    id::String
    window::Int
    ohlc::Symbol
end
export RollingZScore

@kwdef struct NormalizedSMA <: AbstractFeature
    id::String
    window::Int
    ohlc::Symbol
end
export NormalizedSMA

@kwdef struct NormalizedEMA <: AbstractFeature
    id::String
    window::Int
    wilder::Bool
    ohlc::Symbol
end
export NormalizedEMA

@kwdef struct NormalizedKAMA <: AbstractFeature
    id::String
    window::Int
    fast_window::Int
    slow_window::Int
    ohlc::Symbol
end
export NormalizedKAMA

@kwdef struct RSI <: AbstractFeature
    id::String
    window::Int
    wilder::Bool
    ohlc::Symbol
end
export RSI

@kwdef struct ADX <: AbstractFeature
    id::String
    window::Int
    direction::Symbol
end
export ADX

@kwdef struct Aroon <: AbstractFeature
    id::String
    window::Int
    direction::Symbol
end
export Aroon

@kwdef struct NormalizedAO <: AbstractFeature
    id::String
end
export NormalizedAO

@kwdef struct NormalizedDPO <: AbstractFeature
    id::String
    window::Int
    ohlc::Symbol
end
export NormalizedDPO

@kwdef struct MassIndex <: AbstractFeature
    id::String
    window::Int
end
export MassIndex

@kwdef struct TRIX <: AbstractFeature
    id::String
    window::Int
    ohlc::Symbol
end
export TRIX

@kwdef struct Vortex <: AbstractFeature
    id::String
    window::Int
    direction::Symbol
end
export Vortex

@kwdef struct WilliamsR <: AbstractFeature
    id::String
    window::Int
end
export WilliamsR

@kwdef struct Stochastic <: AbstractFeature
    id::String
    window::Int
    fast_window::Int
    slow_window::Int
    output::Symbol
end
export Stochastic

@kwdef struct NormalizedMACD <: AbstractFeature
    id::String
    fast_window::Int
    slow_window::Int
    signal_window::Int
    ohlc::Symbol
    output::Symbol
end
export NormalizedMACD

@kwdef struct NormalizedATR <: AbstractFeature
    id::String
    window::Int
end
export NormalizedATR

@kwdef struct NormalizedBB <: AbstractFeature
    id::String
    window::Int
    std_multiplier::Float64
    band::Symbol
    ohlc::Symbol
end
export NormalizedBB

@kwdef struct NormalizedDC <: AbstractFeature
    id::String
    window::Int
    channel::Symbol
end
export NormalizedDC

@kwdef struct NormalizedKC <: AbstractFeature
    id::String
    window::Int
    multiplier::Float64
    channel::Symbol
end
export NormalizedKC

function pad_vector(vector::Vector{Float64}, data::TimeArray)::Vector{Float64}
    vector_len = length(vector)
    data_len = length(data)

    padded_vector = Vector{Float64}(undef, data_len)

    pad_len = data_len - vector_len

    padded_vector[1:pad_len] .= NaN
    padded_vector[pad_len + 1:end] .= vector
    
    return padded_vector
end
export pad_vector

function pad_array(array::TimeArray, data::TimeArray)::Vector{Float64}
    array_values = values(array)
    vector_values = vec(array_values)

    return pad_vector(vector_values, data)
end
export pad_array

function pad_and_normalize(array::TimeArray, data::TimeArray)::Vector{Float64}
    padded_values = pad_array(array, data)
    close_prices = values(data[:close])
    return padded_values ./ close_prices
end
export pad_and_normalize

function log_returns(values::Vector{Float64})::Vector{Float64}
    log_values = log.(values)
    return diff(log_values)
end
export log_returns

end