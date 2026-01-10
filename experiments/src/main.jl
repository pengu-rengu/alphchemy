
include("features/features.jl")
include("features/featurevalues.jl")

include("network/network.jl")
include("network/logicnet.jl")
include("network/decisionnet.jl")

include("actions/actions.jl")
include("actions/logicactions.jl")
include("actions/decisionactions.jl")

include("optimizer/optimizer.jl")
include("optimizer/genetic.jl")

include("experiment/strategy.jl")
include("experiment/backtest.jl")
include("experiment/experiment.jl")
include("experiment/validate.jl")
include("experiment/parsejson.jl")
include("experiment/tojson.jl")

using .ExperimentModule
using .ParseJsonModule
using .ValidateModule
using .ToJsonModule
using JSON
using TimeSeries

data = readtimearray("data/btc_data.csv"; format="yyyy-mm-dd HH:MM:SS+SS:SS")

println(length(data))

json = read("src/strategy.json", String)

json = JSON.parse(json)

experiment = parse_experiment(json["experiment"])

validate_experiment(experiment)

results = run_experiment(experiment, data)

results = experiment_results_json(results)

results = JSON.json(results, 2)

println(results)

open("src/results.json", "w") do file
    write(file, results)
end
