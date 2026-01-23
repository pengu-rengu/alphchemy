module TestUtilsModule

using TimeSeries
using Supposition

const MAX_LENGTH = 150

length_gen = Data.Integers(1, MAX_LENGTH)
export length_gen

int_gen = Data.Integers{Int}()
export int_gen

float_gen = Data.Floats{Float64}()
export float_gen

amplitude_gen = Data.Floats{Float64}(minimum = 1.0, maximum = 10.0, nans = false)

mock_data = @composed (
    open_amplitude = amplitude_gen,
    high_amplitude = amplitude_gen,
    low_amplitude = amplitude_gen,
    close_amplitude = amplitude_gen,
    len = length_gen
) -> begin

    valid_amplitudes = low_amplitude < high_amplitude
    assume!(valid_amplitudes)

    timestamps = [DateTime(2000) + Minute(i) for i ∈ 1:len]
    data = Matrix{Float64}(undef, len, 4)

    for i = 1:len
        value = sin(i)

        data[i, 1] = i * open_amplitude
        data[i, 2] = i * high_amplitude
        data[i, 3] = i * low_amplitude
        data[i, 4] = i * close_amplitude
    end
    
    return TimeArray(timestamps, data, [:open, :high, :low, :close])
end
export mock_data

end