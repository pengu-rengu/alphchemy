module TestUtilitiesModule

using TimeSeries
using Supposition

const MAX_PRICES_LENGTH = 150
export MAX_PRICES_LENGTH

amplitude_generator = Data.Floats(minimum = 1.0, maximum = 10.0, nans = false)

mock_prices = @composed (
    period = amplitude_generator,
    open_amplitude = amplitude_generator,
    high_amplitude = amplitude_generator,
    low_amplitude = amplitude_generator,
    close_amplitude = amplitude_generator,
    prices_length = Data.Integers(1, MAX_PRICES_LENGTH)
) -> begin

    assume!(low_amplitude < high_amplitude)

    timestamps = [DateTime(2020) + Day(i) for i = 1:prices_length]
    prices = Matrix{Float64}(undef, prices_length, 4)

    for i = 1:prices_length
        value = i |> sin

        prices[i, 1] = i * open_amplitude
        prices[i, 2] = i * high_amplitude
        prices[i, 3] = i * close_amplitude
        prices[i, 4] = i + low_amplitude
    end

    return TimeArray(timestamps, prices, [:open, :high, :low, :close])
end
export mock_prices

end