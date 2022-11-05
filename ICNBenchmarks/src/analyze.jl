function analyze_icn()
    @info """Start the analyze of files in $datadir("compositions")"""
    df = DataFrame()
    for f in readdir(datadir("compositions"); join = true)
        d = JSON.parsefile(f)
        inds1 = Indices(["icn_time", "nthreads"])
        d1 = view(Dictionary(d),inds1)
        inds2 = Indices(["icn_iterations", "loss_sampler", "domains_size", "memoize", "metric", "sampling", "generations", "search", "population", "concept"])
        d2 = view(Dictionary(d["params"]), inds2)
        d3 = merge(d1, d2)
        d3["loss_sampler"] = string(d3["loss_sampler"])

        if isempty(df)
            df = DataFrame(Dict(pairs(d3)))
        else
            push!(df, Dict(pairs(d3)))
        end
    end
    return df
end

"""
icn_iterations, time, composition_number, rsd, mean, std, icn_time, memoize, var, concept, partial_search_limit, sampling, generations
cov, complete_search_limit, median, search, population, selection_rate
{
  "icn_iterations": 16,
  "time": 0.356123463,
  "composition_number": 1,
  
  "rsd": 2.8284271247461907,
  "maths": "all_different = identity ∘ sum ∘ sum ∘ count_eq_left",
  
  "mean": 0.037037037037037035,
  "std": 0.10475656017578483,
  "icn_time": 5.040572709,
  "memoize": false,
  "composition": "\"\"\"\n    all_different(x; X = zeros(length(x), 1), param=nothing, dom_size)\n\nComposition `all_different` generated by CompositionalNetworks.jl.\n```\nall_different = identity ∘ sum ∘ sum ∘ count_eq_left\n```\n\"\"\"\nfunction all_different(x; X=zeros(length(x), 1), param=nothing, dom_size)\n    CompositionalNetworks.tr_in(\n        Tuple([CompositionalNetworks.tr_count_eq_left]), X, x, param\n    )\n    for i in 1:length(x)\n        X[i, 1] = CompositionalNetworks.ar_sum(@view X[i, :])\n    end\n    return CompositionalNetworks.ag_sum(@view X[:, 1]) |>\n           (y -> CompositionalNetworks.co_identity(y; param, dom_size, nvars=length(x)))\nend\n",
  "var": 0.010973936899862827,
  "concept": "all_different",
  "partial_search_limit": 256,
  "sampling": 100,
  "generations": 16,
  "cov": 0.010973936899862827,
  "complete_search_limit": 46656,
  "median": 0.0,
  "search": "complete",
  "population": 1024,
  "selection_rate": 0.9375
}

"""

function analyze_composition()
    @info """Start the analyze of files in $datadir("composition_results")"""
    df = DataFrame()
    for f in filter(x -> endswith(x, ".json"),readdir(datadir("composition_results"); join = true))
        d = JSON.parsefile(f)

        inds1 = Indices(["symbols_count","icn_iterations", "time", "composition_number", "mean", "std", "icn_time", "memoize", "var", "concept", "partial_search_limit", "sampling", "generations",
        "cov", "complete_search_limit", "median", "search", "population", "selection_rate"])
        d1 = view(Dictionary(d),inds1)
        
        if isempty(df)
            df = DataFrame(Dict(pairs(d1)))
        else
            push!(df, Dict(pairs(d1)))
        end
    end
    return df
end

visualize_icn() = Voyager(analyze_icn())

visualize_compositions() = Voyager(analyze_composition())