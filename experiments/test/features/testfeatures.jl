module TestFeatureModule

include("../testutilities.jl")
include("../../src/utils.jl")
include("../../src/network/network.jl")
include("../../src/network/logicnetwork.jl")
include("../../src/features/features.jl")
include("../../src/features/indicators.jl")
include("../../src/features/mlfeatures.jl")
include("../../src/features/featurevalues.jl")

using .TestUtilitiesModule
using .NetworkModule
using .LogicNetworkModule
using .FeaturesModule
using .FeatureValuesModule
using Statistics
using TimeSeries
using RollingFunctions
using Test
using Supposition

const mock_integer = Data.Integers(10, 100)
const mock_float = Data.Floats(minimum = -100.0, maximum = 100.0, nans = false)
const mock_boolean = Data.Booleans()
const mock_ohlc = Data.SampledFrom([:open, :high, :low, :close])
const mock_index = Data.Integers(1, MAX_PRICES_LENGTH)

@testset "test fill missing" begin
    @check (shorter_prices = mock_prices, longer_prices = mock_prices) -> begin
        shorter_length = shorter_prices |> length
        longer_length = longer_prices |> length

        assume!(shorter_length < longer_length)

        shorter_close = shorter_prices[:close]

        return shorter_close |> (longer_prices |> fill_missing) == [(longer_length - shorter_length) |> zeros; shorter_close |> values]
    end
end

@testset "test zero padding" begin
    @check (longer_length = mock_integer, shorter_length = mock_integer) -> begin
        assume!(shorter_length < longer_length)

        return (shorter_length |> ones) |> (longer_length |> ones |> zero_padding) == [(longer_length - shorter_length) |> zeros; shorter_length |> ones]
    end
end

@testset "test constant feature" begin
    @check (prices = mock_prices, value = mock_float) -> begin
        feature = ConstantFeature(
            id = "constant feature",
            constant = value
        )
        get_values!(feature, prices)

        return feature.values == fill(value, prices |> length)
    end
end

@testset "test bool feature" begin
    @check (prices = mock_prices, value = mock_boolean) -> begin
        feature = BoolFeature(
            id = "bool feature",
            constant = value
        )
        get_values!(feature, prices)

        return feature.values == fill(value, prices |> length)
    end
end

@testset "test raw prices" begin
    @check (prices = mock_prices, ohlc = mock_ohlc) -> begin
        feature = RawPrices(
            id = "raw prices",
            ohlc = ohlc
        )
        get_values!(feature, prices)

        return feature.values == prices[ohlc] |> values
    end
end

@testset "test relative prices" begin
    @check (prices = mock_prices, ohlc = mock_ohlc, index = mock_index) -> begin
        prices_length = prices |> length

        assume!(2 <= index <= prices_length)

        feature = RelativePrices(
            id = "relative prices",
            ohlc = ohlc
        )
        get_values!(feature, prices)

        feature_values = feature.values
        price_values = prices[ohlc] |> values

        return feature_values |> length == prices_length &&
        feature_values[1] == 0.0 &&
        isapprox(feature_values[index], price_values[index] / price_values[index - 1])
    end
end

@testset "test log prices" begin
    @check (prices = mock_prices, ohlc = mock_ohlc, index = mock_index) -> begin
        prices_length = prices |> length

        assume!(2 <= index <= prices_length)

        feature = LogPrices(
            id = "log prices",
            ohlc = ohlc
        )
        get_values!(feature, prices)

        feature_values = feature.values
        price_values = prices[ohlc] |> values

        return feature_values |> length == prices_length &&
        feature_values[1] == 0.0 &&
        isapprox(feature_values[index], (feature_values[index] / feature_values[index - 1]) |> log)
    end
end

@testset "test rolling mean" begin
    
end

end