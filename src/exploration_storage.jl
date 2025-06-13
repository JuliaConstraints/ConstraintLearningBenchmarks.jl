"""
Exploration Storage System

Provides UUID-based storage for exploration data to avoid filesystem filename length limits.
This system is used for constraint exploration results which are deterministic and system-independent.
"""

import UUIDs: UUID, uuid4, uuid5
import CSV
import JSON

# Base UUID for exploration data (deterministic seed)
const EXPLORATION_BASE_UUID = UUID("12345678-1234-5678-9abc-123456789abc")

"""
    flatten_exploration_parameters(s::Symbol, params, domains) -> String

Convert exploration parameters into a canonical string representation for UUID generation.
"""
function flatten_exploration_parameters(s::Symbol, params, domains)
    # Convert parameters to string representation with safe handling of complex types
    param_strs = String[]

    # Sort by keys only to avoid comparing values of different types
    sorted_keys = sort(collect(keys(params)))

    for k in sorted_keys
        v = params[k]
        # Handle different parameter types safely
        if isa(v, AbstractMatrix)
            # Convert matrix to a deterministic string representation
            v_str = "Matrix($(size(v)),$(hash(v)))"
        elseif isa(v, AbstractArray)
            # Convert array to a deterministic string representation
            v_str = "Array($(length(v)),$(hash(v)))"
        elseif isa(v, Function)
            # Convert function to its name
            v_str = string(v)
        else
            # Use repr for other types
            v_str = repr(v)
        end
        push!(param_strs, "$(k)=$(v_str)")
    end
    params_str = join(param_strs, ",")

    # Convert domains to string representation
    domains_str = join(string.(domains), "_")

    # Combine all components
    return "$(s)|$(params_str)|$(domains_str)"
end

"""
    get_exploration_uuid(s::Symbol, params, domains) -> UUID

Generate a deterministic UUID for exploration parameters.
"""
function get_exploration_uuid(s::Symbol, params, domains)
    param_string = flatten_exploration_parameters(s, params, domains)
    return uuid5(EXPLORATION_BASE_UUID, param_string)
end

"""
    exploration_filename(s::Symbol, params, domains; ext::String="txt") -> String

Generate a short, filesystem-safe filename for exploration data.
"""
function exploration_filename(s::Symbol, params, domains; ext::String="txt")
    uuid = get_exploration_uuid(s, params, domains)
    return "$(uuid).$(ext)"
end

"""
    save_exploration_metadata(s::Symbol, params, domains, metadata_file::String)

Save parameter mapping to metadata file for later lookup.
"""
function save_exploration_metadata(s::Symbol, params, domains, metadata_file::String)
    uuid = get_exploration_uuid(s, params, domains)
    param_string = flatten_exploration_parameters(s, params, domains)

    # Ensure directory exists
    mkpath(dirname(metadata_file))

    # Check if entry already exists
    if isfile(metadata_file) && filesize(metadata_file) > 0
        try
            # Read CSV file properly
            existing_data = CSV.File(metadata_file)
            for row in existing_data
                if row.uuid == string(uuid)
                    return uuid  # Already exists
                end
            end
        catch e
            @warn "Could not read metadata file $metadata_file: $e"
            # Continue to write new entry
        end
    end

    # Append new entry
    open(metadata_file, "a") do io
        if !isfile(metadata_file) || filesize(metadata_file) == 0
            # Write header if file is new/empty
            println(io, "uuid,symbol,parameters,domains,full_description")
        end

        # Escape commas and quotes in the full description
        full_desc = replace(param_string, "," => ";", "\"" => "'")
        println(io, "$(uuid),$(s),\"$(repr(params))\",\"$(repr(domains))\",\"$(full_desc)\"")
    end

    return uuid
end

"""
    load_exploration_metadata(metadata_file::String) -> Dict{UUID, Dict}

Load exploration metadata from CSV file.
"""
function load_exploration_metadata(metadata_file::String)
    if !isfile(metadata_file)
        return Dict{UUID,Dict}()
    end

    data = CSV.read(metadata_file, Dict)
    result = Dict{UUID,Dict}()

    for row in data
        uuid = UUID(row["uuid"])
        result[uuid] = Dict(
            :symbol => Symbol(row["symbol"]),
            :parameters => eval(Meta.parse(row["parameters"])),
            :domains => eval(Meta.parse(row["domains"])),
            :full_description => row["full_description"]
        )
    end

    return result
end

"""
    lookup_exploration_parameters(uuid::UUID, metadata_file::String) -> Union{Dict, Nothing}

Look up original parameters from UUID.
"""
function lookup_exploration_parameters(uuid::UUID, metadata_file::String)
    metadata = load_exploration_metadata(metadata_file)
    return get(metadata, uuid, nothing)
end

"""
    migrate_exploration_file(old_path::String, new_path::String, s::Symbol, params, domains, metadata_file::String)

Migrate an existing exploration file from long filename to UUID-based filename.
"""
function migrate_exploration_file(old_path::String, new_path::String, s::Symbol, params, domains, metadata_file::String)
    if isfile(old_path) && !isfile(new_path)
        # Save metadata
        save_exploration_metadata(s, params, domains, metadata_file)

        # Copy file to new location
        cp(old_path, new_path)

        @info "Migrated exploration file" old_path new_path
        return true
    end
    return false
end
