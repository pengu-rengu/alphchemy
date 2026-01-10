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

shorter_prices = mock_prices(5)
longer_prices = mock_prices(10)

shorter_close = shorter_prices[:close]
shorter_close_values = shorter_close |> values

@testset "test fill missing" begin
    @test shorter_close |> fill_missing(longer_prices) == [zeros(5); shorter_close_values]
end

@testset "test zero padding" begin
    longer = ones(10)
    shorter = ones(5)

    @test shorter |> zero_padding(longer) == [zeros(5); ones(5)]
end

@testset "test constant feature" begin
    feature = Constant(
        id="constant feature",
        constant=10.0
    )
    get_values!(feature, longer_prices)

    @test feature.values == fill(10.0, longer_prices |> length)
end

@testset "test bool feature" begin
    feature = BoolFeature(
        id="bool feature",
        constant=true
    )
    get_values!(feature, longer_prices)

    @test feature.values == trues(longer_prices |> length)
end

@testset "test raw prices" begin
    feature = RawPrices(
        id="raw prices",
        ohlc=:close
    )
    get_values!(feature, longer_prices)

    @test feature.values == longer_prices[:close] |> values
end

@testset "test relative prices" begin
    feature = RelativePrices(
        id="relative prices",
        ohlc=:close
    )
    get_values!(feature, shorter_prices)

    feature_values = feature.values
    
    @test length(feature_values) == 5
    @test feature_values[1] == 0.0
    @test isapprox(feature_values[2], shorter_close_values[2] / shorter_close_values[1])
    @test isapprox(feature_values[3], shorter_close_values[3] / shorter_close_values[2])
    @test isapprox(feature_values[4], shorter_close_values[4] / shorter_close_values[3])
    @test isapprox(feature_values[5], shorter_close_values[5] / shorter_close_values[4])
end

@testset "test log prices" begin
    shorter_prices = mock_prices(5)

    feature = LogPrices(
        id="log prices",
        ohlc=:close
    )
    get_values!(feature, shorter_prices)

    feature_values = feature.values

    @test length(feature_values) == 5
    @test feature_values[1] == 0.0
    @test isapprox(feature_values[2], (shorter_close_values[2] / shorter_close_values[1]) |> log)
    @test isapprox(feature_values[3], (shorter_close_values[3] / shorter_close_values[2]) |> log)
    @test isapprox(feature_values[4], (shorter_close_values[4] / shorter_close_values[3]) |> log)
    @test isapprox(feature_values[5], (shorter_close_values[5] / shorter_close_values[4]) |> log)
end

@testset "test rolling mean" begin
    feature = RollingMean(
        id="rolling mean",
        window=4,
        sub_feature=RawPrices(
            id="raw prices",
            ohlc=:close
        )
    )
    get_values!(feature, shorter_prices)

    @test feature.values |> length == 5
    @test (@view feature.values[1:3]) == 3 |> zeros
    @test isapprox(feature.values[4], shorter_close_values[1:4] |> mean)
    @test isapprox(feature.values[5], shorter_close_values[2:5] |> mean)
end

@testset "test rolling std" begin
    feature = RollingStd(
        id="rolling std",
        window=4,
        sub_feature=RawPrices(
            id="raw prices",
            ohlc=:close
        )
    )
    get_values!(feature, shorter_prices)

    @test feature.values |> length == 5
    @test (@view feature.values[1:3]) == 3 |> zeros
    @test isapprox(feature.values[4], (@view shorter_close_values[1:4]) |> std)
    @test isapprox(feature.values[5], (@view shorter_close_values[2:5]) |> std)
end

@testset "test rolling quantile" begin
    feature = RollingQuantile(
        id="rolling quantile",
        window=4,
        quantile=0.67,
        sub_feature=RawPrices(
            id="raw prices",
            ohlc=:close
        )
    )
    get_values!(feature, shorter_prices)

    @test feature.values |> length == 5
    @test (@view feature.values[1:3]) == 3 |> zeros
    @test feature.values[4] == quantile((@view shorter_close_values[1:4]), 0.67)
    @test feature.values[5] == quantile((@view shorter_close_values[2:5]), 0.67)
end

@testset "test comparison" begin
    longer_length = longer_prices |> length

    feature = Comparison(
        id = "comparion feature",
        sub_feature1 = Constant(
            id = "constant 1",
            constant = 0.0
        ),
        sub_feature2 = Constant(
            id = "constant 2",
            constant = 1.0
        )
    )
    get_values!(feature, longer_prices)

    @test feature.values == longer_length |> trues

    feature.sub_feature1.constant = 2.0

    get_values!(feature, longer_prices)
    @test feature.values == longer_length |> falses
end

@testset "test logic network feature" begin
    feature = NetworkFeature(
        id = "logic network feature",
        sub_features = [
            BoolFeature(
                id = "true feature",
                constant = true
            )
        ],
        network = LogicNetwork(
            nodes = [
                LogicNode(
                    operation = :AND,
                    input1_index = 1,
                    input1_type = :feature,
                    input2_index = 1,
                    input2_type = :feature
                )
            ],
            default_value = false
        ),
        output_pointer = NodePointer(
            anchor = :from_start,
            index = 1
        )
    )
    get_values!(feature, shorter_prices)

    @test feature.values == 5 |> trues
end

end