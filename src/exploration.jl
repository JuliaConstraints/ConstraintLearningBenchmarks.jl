# Helper function to open files in O_EXCL mode
function tryopen_exclusive(path::String, mode::Integer=0o666)
    try
        return open(path, JL_O_RDWR | JL_O_CREAT | JL_O_EXCL, mode)
    catch ex
        (isa(ex, IOError) && ex.code == UV_EEXIST) || rethrow(ex)
    end
    return nothing
end

function search_space(
    domains,
    constraint;
    exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
    parameters_explorations=0,
    settings=ExploreSettings(domains),
    symb=Constraints.shrink_concept(concept(constraint)) |> Symbol,
    parameters...
)
    if parameters_explorations > 0
        generate_parameters(
            symb, constraint, domains;
            exploration_spaces,
            parameters_explorations
        )
    else
        name = savename(symb, parameters, domains)
        exploration_spaces[name] = Dict(parameters)
    end

    # Define the output folder and make the related path if necessary
    output_folder = joinpath(datadir("search_spaces"))
    mkpath(output_folder)

    # Define the file names TODO: make better metaprogramming
    search = settings.search

    for (k, p) in exploration_spaces
        @info " " k p
    end


    return nothing

    search === :complete || push!(d, :limit => settings.solutions_limit)

    for p in parameters
        push!(d, p.first => string(p.second))
    end

    d̅ = copy(d)

    push!(d, :configurations => :X)
    push!(d̅, :configurations => :X̅)

    X_file = joinpath(output_folder, "$(savename(d)).csv")
    X̅_file = joinpath(output_folder, "$(savename(d̅)).csv")

    # Check if existing data are present
    has_data = isfile(X_file) && isfile(X̅_file)

    function read_csv_as_set(file)
        configs = Set{Vector{Int}}()
        for r in CSV.Rows(file; header=false, types=Int)
            push!(configs, collect(Int, r))
        end
        return configs
    end

    # Load or compute the exploration of the search space
    X, X̅ = Set{Vector{Int}}(), Set{Vector{Int}}()
    if has_data
        @warn "Following exploration settings have data" X_file X̅_file
        X, X̅ = read_csv_as_set(X_file), read_csv_as_set(X̅_file)
    else
        @warn "Following exploration settings doesn't have data, generating solutions & non_solutions..." X_file X̅_file
        X_file, X̅_file = tryopen_exclusive(X_file), tryopen_exclusive(X̅_file)
        if (!isnothing(X_file))
            X, X̅ = explore(domains, concept; settings, parameters...)
            files = [X_file]
            configs = [X]
            for (file, config) in zip(files, configs), x in config
                CSV.write(file, Tables.table(reshape(x, (1, length(x)))); append=true)
            end
        end

        if (!isnothing(X̅_file))
            files = [X̅_file]
            configs = [X̅]
            for (file, config) in zip(files, configs), x in config
                CSV.write(file, Tables.table(reshape(x, (1, length(x)))); append=true)
            end
        end
    end

    return X, X̅, has_data
end
