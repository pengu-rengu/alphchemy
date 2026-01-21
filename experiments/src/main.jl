module MainModule

include("features/features.jl")
include("features/featurevalues.jl")

include("network/network.jl")
include("network/penalties.jl")
include("network/evaluate.jl")

include("actions/actions.jl")
include("actions/doactions.jl")

include("optimizer/optimizer.jl")
include("optimizer/genetic.jl")

include("experiment/strategy.jl")
include("experiment/backtest.jl")
include("experiment/experiment.jl")
include("experiment/parsejson.jl")
include("experiment/tojson.jl")

using .ExperimentModule
using .ParseJsonModule
using .ToJsonModule
using JSON
using TimeSeries
using Redis

function run_experiment_json(json::AbstractDict, data::TimeArray)::Dict{String, Any}
    try
        experiment = parse_experiment(json)
        results = run_experiment(experiment, data)
        
        return experiment_results_json(results)
    catch e
        if isa(e, AssertionError)
            return Dict(
                "error" => "$e",
                "is_internal" => false
            )
        end
        
        error_msg = sprint(showerror, e, catch_backtrace())
        println(error_msg)

        return Dict(
            "error" => error_msg,
            "is_internal" => true
        )
    end
end
export run_experiment_json

function main()
    data = readtimearray("data/btc_data.csv"; format="yyyy-mm-dd HH:MM:SS+SS:SS")
    
    redis = RedisConnection(host = "localhost", port = 6379)

    while true
        println("waiting")

        experiment_data = brpop(redis, "experiments", 0)[2]
        experiment_json = JSON.parse(experiment_data)

        println("running $(experiment_json["title"])")
        
        results = run_experiment_json(experiment_json, data)
        
        try
            entry_json = Dict(
                "experiment" => experiment_json,
                "results" => results
            )
            entry_json = JSON.json(entry_json, allownan = true)

            open("data/experiments.jsonl", "a") do file
                write(file, entry_json * "\n")
            end
        catch e
            error_msg = sprint(showerror, e, catch_backtrace())
            
            println("Internal error occurred when processing JSON")
            println(error_msg)
        end
    end
end

main()

end