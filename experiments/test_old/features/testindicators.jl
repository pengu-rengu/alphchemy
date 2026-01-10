module TestIndicatorsModule

include("../testutilities.jl")
include("../../src/utils.jl")
include("../../src/network/network.jl")
include("../../src/network/logicnetwork.jl")
include("../../src/features/features.jl")
include("../../src/features/indicators.jl")
include("../../src/features/mlfeatures.jl")
include("../../src/features/featurevalues.jl")

using .TestUtilitiesModule
using .IndicatorsModule
using .FeatureValuesModule
using TimeSeries
using MarketTechnicals
using Test

prices = mock_prices(100)
padding = fill_missing(prices)

@testset "test sma" begin 
    feature = SMA(
        id="sma",
        window=14,
        ohlc=:close
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, sma(prices[:close], 14) |> padding)

    feature.window = 21
    feature.ohlc = :high

    get_values!(feature, prices)

    @test isapprox(feature.values, sma(prices[:high], 21) |> padding)
end

@testset "test ema" begin
    feature = EMA(
        id="ema",
        window=14,
        wilder=false,
        ohlc=:close
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, ema(prices[:close], 14, wilder=false) |> padding)

    feature.window = 21
    feature.wilder = true
    feature.ohlc = :high
    
    get_values!(feature, prices)

    @test isapprox(feature.values, ema(prices[:high], 21, wilder=true) |> padding)
end

@testset "test kama" begin
    feature = KAMA(
        id="kama",
        window=10,
        fast_window=2,
        slow_window=30,
        ohlc=:close
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, kama(prices[:close], 10, 2, 30) |> padding)

    feature.window = 14
    feature.fast_window = 10
    feature.ohlc = :high
    
    get_values!(feature, prices)

    @test isapprox(feature.values, kama(prices[:high], 14, 10, 35) |> padding)
end

@testset "test rsi" begin
    feature = RSI(
        id="rsi",
        window=14,
        wilder=true,
        ohlc=:close
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, rsi(prices[:close], 14, wilder=true) |> padding)

    feature.window = 21
    feature.wilder = false
    feature.ohlc = :high
    
    get_values!(feature, prices)

    @test isapprox(feature.values, rsi(prices[:high], 21, wilder=false) |> padding)
end

@testset "test adx" begin
    feature = ADX(
        id="adx",
        window=14,
        direction=:positive
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, adx(prices, 14, h=:high, l=:low, c=:close)[:di_plus] |> padding)

    feature.window = 21
    feature.direction = :negative

    get_values!(feature, prices)

    @test isapprox(feature.values, adx(prices, 21, h=:high, l=:low, c=:close)[:di_minus] |> padding)
end

@testset "test aroon oscillator" begin
    feature = AroonOscillator(
        id="aroon oscillator",
        window=25,
        direction=:up
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, aroon(prices, 25, h=:high, l=:low)[:up] |> padding)

    feature.window = 35
    feature.direction = :down

    get_values!(feature, prices)

    @test isapprox(feature.values, aroon(prices, 35, h=:high, l=:low)[:down] |> padding)
end

@testset "test awesome oscillator" begin
    feature = AwesomeOscillator(id="awesome oscillator")
    get_values!(feature, prices)

    @test isapprox(feature.values, awesomeoscillator(prices, h=:high, l=:low) |> padding)
end

@testset "test dpo" begin
    feature = DPO(
        id="dpo",
        window=14,
        ohlc=:close
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, dpo(prices[:close], 14) |> padding)

    feature.window = 21
    feature.ohlc = :high
    
    get_values!(feature, prices)

    @test isapprox(feature.values, dpo(prices[:high], 21) |> padding)
end

@testset "test mass index" begin
    feature = MassIndex(
        id="mass index",
        window1=14,
        window2=25
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, massindex(prices, 14, 25, h=:high, l=:low) |> padding)

    feature.window1 = 5
    feature.window2 = 30

    get_values!(feature, prices)

    @test isapprox(feature.values, massindex(prices, 5, 30, h=:high, l=:low) |> padding)
end

@testset "test trix" begin
    feature = TRIX(
        id="trix",
        window=14,
        ohlc=:close
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, trix(prices[:close], 14) |> padding)

    feature.window = 21
    feature.ohlc = :high
    
    get_values!(feature, prices)

    @test isapprox(feature.values, trix(prices[:high], 21) |> padding)
end

@testset "test vortex indicator" begin
    feature = VortexIndicator(
        id="vortex indicator",
        window=14,
        direction=:positive
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, vortex(prices, 14, h=:high, l=:low, c=:close)[:v_plus] |> padding)

    feature.window = 21
    feature.direction = :negative
    
    get_values!(feature, prices)
    
    @test isapprox(feature.values, vortex(prices, 21, h=:high, l=:low, c=:close)[:v_minus] |> padding)
end

@testset "test williams r" begin
    feature = WilliamsR(
        id="williams r",
        window=21
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, williamsr(prices, 21, c=:close, h=:high, l=:low) |> padding)
end

@testset "test stochastic oscillator" begin
    feature = StochasticOscillator(
        id="stochastic oscillator",
        window=14,
        fast_window=3,
        slow_window=3
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, stochasticoscillator(prices, 14, 3, 3, h=:high, l=:low, c=:close) |> padding)

    feature.window = 21
    feature.fast_window = 5
    feature.slow_window = 10

    get_values!(feature, prices)

    @test isapprox(feature.values, stochasticoscillator(prices, 21, 5, 10, h=:high, l=:low, c=:close) |> padding)
end

@testset "test macd" begin
    feature = MACD(
        id="macd",
        fast_window=12,
        slow_window=26,
        signal_window=9,
        ohlc=:close,
        output=:macd
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, macd(prices[:close], 12, 26, 9)[:macd] |> padding)
    
    feature.fast_window = 5
    feature.slow_window = 20
    feature.signal_window = 12
    feature.ohlc = :high
    feature.output = :dif
    
    get_values!(feature, prices)

    @test isapprox(feature.values, macd(prices[:high], 5, 20, 12)[:dif] |> padding)
end

@testset "test atr" begin
    feature = ATR(
        id="atr",
        window=16
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, atr(prices, 16, h=:high, l=:low, c=:close) |> padding)
end

@testset "test bollinger bands" begin
    feature = BollingerBands(
        id="bollinger bands",
        window=20,
        std_multiplier=2.0,
        ohlc=:close,
        band=:upper
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, bollingerbands(prices[:close], 20, 2.0)[:up] |> padding)

    feature.window = 35
    feature.std_multiplier = 1.2
    feature.ohlc = :high
    feature.band = :lower
    
    get_values!(feature, prices)

    @test isapprox(feature.values, bollingerbands(prices[:high], 35, 1.2)[:down] |> padding)

    feature.band = :up
end

@testset "test donchian channels" begin
    feature = DonchianChannels(
        id="donchian channels",
        window=20,
        channel=:lower,
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, donchianchannels(prices, 20, h=:high, l=:low)[:down] |> padding)
    
    feature.window = 35
    feature.channel = :middle
    
    get_values!(feature, prices)

    @test isapprox(feature.values, donchianchannels(prices, 35, h=:high, l=:low)[:mid] |> padding)
end

@testset "test keltner bands" begin
    feature = KeltnerBands(
        id="keltner bands",
        window=20,
        multiplier=2.0,
        band=:upper
    )
    get_values!(feature, prices)

    @test isapprox(feature.values, keltnerbands(prices, 20, 2.0, h=:high, l=:low, c=:close)[:kup] |> padding)

    feature.window = 35
    feature.multiplier = 1.5
    feature.band = :lower
    
    get_values!(feature, prices)

    @test isapprox(feature.values, keltnerbands(prices, 35, 1.5, h=:high, l=:low, c=:close)[:kdn] |> padding)
end

end
