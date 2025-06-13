import JSON
import Dates: now

"""
    serialize_parameters(params::Dict)

Convert parameters dictionary to JSON-serializable format by converting functions to strings.
"""
function serialize_parameters(params::Dict)
    serialized = Dict{String,Any}()
    for (k, v) in params
        key_str = string(k)
        if isa(v, Function)
            serialized[key_str] = string(v)
        elseif isa(v, AbstractArray) && !isempty(v) && isa(first(v), Function)
            serialized[key_str] = string.(v)
        else
            serialized[key_str] = v
        end
    end
    return serialized
end

function search_space(
    domains,
    constraint;
    exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
    parameters_explorations=0,
    settings=ExploreSettings(domains),
    symb=Constraints.shrink_concept(constraint.concept) |> Symbol,
    parameters...
)
    # Handle exploration_spaces: generate if empty, keep if provided
    if isempty(exploration_spaces)
        if parameters_explorations > 0
            generate_parameters(
                symb, constraint, domains;
                exploration_spaces,
                parameters_explorations
            )
        else
            # Use UUID-based naming instead of long descriptive names
            uuid = get_exploration_uuid(symb, Dict(parameters), domains)
            exploration_spaces[string(uuid)] = Dict(parameters)
        end
    end

    for (k, p) in exploration_spaces
        @info " " k p
    end

    # Use the same data format and location as the local explore function
    explo_path = joinpath(datadir(), "exploration_spaces")
    metadata_file = joinpath(datadir(), "exploration_metadata.csv")  # CSV at root of data folder
    mkpath(explo_path)

    # Collect all solutions and non-solutions from all exploration spaces
    X, X̅ = Set{Vector{Int}}(), Set{Vector{Int}}()

    # Process each space using pure UUID filenames
    for (space_id, params) in exploration_spaces
        # Generate UUID and pure filename
        if occursin("-", space_id) && !occursin(".txt", space_id) && length(space_id) != 36
            # Legacy format - try to parse and convert
            try
                s, parsed_params, doms = ConstraintLearningBenchmarks.parse_name(space_id)
                uuid = get_exploration_uuid(s, parsed_params, doms)

                # Save metadata for this conversion
                save_exploration_metadata(s, parsed_params, doms, metadata_file)

                # Check for legacy files and migrate if needed
                legacy_solutions = joinpath(explo_path, space_id * "-solutions.txt")
                legacy_non_sltns = joinpath(explo_path, space_id * "-non_sltns.txt")

                # Pure UUID filename
                exploration_file = joinpath(explo_path, "$(uuid).txt")

                # Migrate legacy files to new format if they exist
                if isfile(legacy_solutions) || isfile(legacy_non_sltns)
                    @info "Migrating legacy files for $space_id to $uuid.txt"
                    # Will be handled in the generation section below
                end
            catch e
                @warn "Could not parse legacy space name: $space_id, using as-is"
                # Generate a UUID for this unknown format
                uuid = get_exploration_uuid(symb, params, domains)
                exploration_file = joinpath(explo_path, "$(uuid).txt")
                save_exploration_metadata(symb, params, domains, metadata_file)
            end
        else
            # UUID format or new generation
            if length(space_id) == 36 && occursin("-", space_id)
                # Existing UUID format
                uuid = UUID(space_id)
            else
                # Generate new UUID
                uuid = get_exploration_uuid(symb, params, domains)
            end

            # Pure UUID filename
            exploration_file = joinpath(explo_path, "$(uuid).txt")

            # Save metadata
            save_exploration_metadata(symb, params, domains, metadata_file)
        end

        if isfile(exploration_file)
            @info "Loading existing data for space: $space_id from $(basename(exploration_file))"
            # Read from single file with JSON format
            data = JSON.parsefile(exploration_file)

            # Add solutions and non-solutions to collections
            for sol in data["solutions"]
                push!(X, sol)
            end
            for non_sol in data["non_solutions"]
                push!(X̅, non_sol)
            end
        else
            @info "Generating data for space: $space_id -> $(basename(exploration_file))"

            # Check for legacy files to migrate
            legacy_solutions = joinpath(explo_path, space_id * "-solutions.txt")
            legacy_non_sltns = joinpath(explo_path, space_id * "-non_sltns.txt")

            if isfile(legacy_solutions) && isfile(legacy_non_sltns)
                @info "Migrating legacy files to new format"
                # Read legacy files
                S_vectors = []
                S̅_vectors = []

                open(legacy_solutions, "r") do io
                    for line in eachline(io)
                        if !isempty(strip(line))
                            vec_str = strip(line, ['(', ')'])
                            if !isempty(vec_str)
                                vec = parse.(Int, split(vec_str, ','))
                                push!(S_vectors, vec)
                            end
                        end
                    end
                end

                open(legacy_non_sltns, "r") do io
                    for line in eachline(io)
                        if !isempty(strip(line))
                            vec_str = strip(line, ['(', ')'])
                            if !isempty(vec_str)
                                vec = parse.(Int, split(vec_str, ','))
                                push!(S̅_vectors, vec)
                            end
                        end
                    end
                end
            else
                # Generate new exploration data
                c = constraint
                doms = domains

                S, S̅ = ConstraintDomains.explore(doms, c.concept; params...)
                @info "Generated data for $space_id" solutions = length(S) non_solutions = length(S̅)

                # Convert tuples to vectors for type consistency
                S_vectors = [collect(s) for s in S]
                S̅_vectors = [collect(s̅) for s̅ in S̅]
            end

            # Add to our collections
            union!(X, S_vectors)
            union!(X̅, S̅_vectors)

            # Write to single JSON file with pure UUID name
            mkpath(dirname(exploration_file))
            data = Dict(
                "solutions" => S_vectors,
                "non_solutions" => S̅_vectors,
                "metadata" => Dict(
                    "constraint" => string(symb),
                    "parameters" => serialize_parameters(params),
                    "domains" => string.(domains),
                    "generated_at" => string(now())
                )
            )

            write(exploration_file, JSON.json(data, 2))
            @info "Saved exploration data to $(basename(exploration_file))"

            # Clean up legacy files if they exist
            rm(legacy_solutions; force=true)
            rm(legacy_non_sltns; force=true)
        end
    end

    # Determine if we had cached data (all spaces had existing files)
    has_data = all(space_id -> begin
            try
                # Generate the UUID for this space
                if occursin("-", space_id) && !occursin(".txt", space_id) && length(space_id) != 36
                    # Legacy format
                    s, parsed_params, doms = ConstraintLearningBenchmarks.parse_name(space_id)
                    uuid = get_exploration_uuid(s, parsed_params, doms)
                elseif length(space_id) == 36 && occursin("-", space_id)
                    # Existing UUID format
                    uuid = UUID(space_id)
                else
                    # Generate new UUID
                    uuid = get_exploration_uuid(symb, exploration_spaces[space_id], domains)
                end

                # Check for pure UUID filename
                exploration_file = joinpath(explo_path, "$(uuid).txt")
                isfile(exploration_file)
            catch
                false
            end
        end, keys(exploration_spaces))

    return X, X̅, has_data
end

function explore(
    domains;
    constraints=USUAL_CONSTRAINTS,
    exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
    parameters_explorations=1
)
    # Generate exploration spaces for all constraints and domains
    for (s, c) in constraints, doms in domains
        ConstraintLearningBenchmarks.generate_parameters(
            s, c, doms; exploration_spaces, parameters_explorations
        )
    end

    explo_path = joinpath(datadir(), "exploration_spaces")
    metadata_file = joinpath(datadir(), "exploration_metadata.csv")
    mkpath(explo_path)

    # Process each exploration space
    for (space, params) in exploration_spaces
        # Try to parse the space name to get constraint info
        s, parsed_params, doms = ConstraintLearningBenchmarks.parse_name(space)

        # Skip if we couldn't determine the constraint (fallback case)
        if s == :unknown
            @warn "Skipping exploration space with unknown constraint: $space"
            continue
        end

        # Check if constraint exists in the constraints dictionary
        if !haskey(constraints, s)
            @warn "Constraint $s not found in constraints dictionary, skipping space: $space"
            continue
        end

        # Use new UUID-based file format
        uuid = get_exploration_uuid(s, parsed_params, doms)
        exploration_file = joinpath(explo_path, "$(uuid).txt")

        # Check if we already have data for this exploration
        if isfile(exploration_file)
            @info "Skipping existing exploration" space uuid
            continue
        end

        # Save metadata for this exploration
        save_exploration_metadata(s, parsed_params, doms, metadata_file)

        @info "exploring" space s doms params
        c = constraints[s]
        S, S̅ = ConstraintDomains.explore(doms, c.concept; params...)
        @info "output" solutions = length(S) non_solutions = length(S̅)

        # Convert tuples to vectors for consistency
        S_vectors = [collect(sol) for sol in S]
        S̅_vectors = [collect(non_sol) for non_sol in S̅]

        # Save to new JSON format
        data = Dict(
            "solutions" => S_vectors,
            "non_solutions" => S̅_vectors,
            "metadata" => Dict(
                "constraint" => string(s),
                "parameters" => serialize_parameters(params),
                "domains" => string.(doms),
                "generated_at" => string(now())
            )
        )

        write(exploration_file, JSON.json(data, 2))
        @info "Saved exploration data to $(basename(exploration_file))"
    end
end
