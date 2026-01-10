module TestUtilitiesModule

using TimeSeries

function mock_prices(length::Int)::TimeArray
    timestamps = [DateTime(2020) + Day(i) for i = 1:length]
    prices = Matrix{Float64}(undef, length, 4)

    for i = 1:length
        prices[i, 1] = i + 1
        prices[i, 2] = i + 3
        prices[i, 3] = i
        prices[i, 4] = i + 2
    end

    return TimeArray(timestamps, prices, [:open, :high, :low, :close])
end
export mock_prices

end