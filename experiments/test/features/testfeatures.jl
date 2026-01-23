module TestFeaturesModule

include("../../src/features/features.jl")
include("../testutils.jl")

using Test
using Supposition
using TimeSeries
using .TestUtilsModule
using .FeaturesModule

float_gen = Data.Floats{Float64}(
    minimum = -100.0,
    maximum = 100.0,
    nans = false
)

@testset "pad_vector" begin
    @check (vector_len = length_gen, vector_value = float_gen, data = mock_data) -> begin

        data_len = length(data)
        assume!(vector_len ≤ data_len)

        vector = fill(vector_value, vector_len)
        padded_vector = pad_vector(vector, data)
        
        pad_len = data_len - vector_len

        nan_check = all(isnan, padded_vector[1:pad_len])
        vector_check = padded_vector[pad_len + 1:end] == vector

        return nan_check && vector_check
    end
end

@testset "log_returns" begin
    @check (len = length_gen, idx = length_gen) -> begin
        assume!(2 ≤ idx ≤ len)

        vector = [sin(i) + 1.1 for i ∈ 1:len]
        returns = log_returns(vector)

        ratio = vector[idx] / vector[idx - 1]
        expected_return = log(ratio)

        return returns[idx - 1] ≈ expected_return
    end
end

end