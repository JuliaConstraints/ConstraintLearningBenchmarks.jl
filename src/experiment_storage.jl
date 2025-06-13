"""
Unified Experiment Storage System

Provides consistent UUID-based storage for all experiment types (exploration, ICN, etc.)
to avoid filesystem filename length limits and ensure proper metadata tracking.
"""

import UUIDs: UUID, uuid4, uuid5
import CSV
import JSON
import Dates: now
import Base.Sys: CPUinfo, CPU_NAME, cpu_info, WORD_SIZE
import CpuId: simdbytes, cpucores, cputhreads, cputhreads_per_core

# Base UUIDs for different experiment types
const EXPLORATION_BASE_UUID = UUID("12345678-1234-5678-9abc-123456789abc")
const ICN_BASE_UUID = UUID("87654321-4321-8765-cba9-876543210fed")

"""
    get_system_uuid() -> UUID

Get the system UUID from environment variable, following PerfChecker.jl pattern.
"""
function get_system_uuid()
    return UUID(ENV["JULIACONSTRAINTS_UUID"])
end

"""
    flatten_parameters(params...) -> String

Convert parameters into a canonical string representation for UUID generation.
"""
function flatten_parameters(params...)
    param_strs = String[]
    for param in params
        if isa(param, Symbol)
            push!(param_strs, string(param))
        elseif isa(param, AbstractString)
            push!(param_strs, param)
        elseif isa(param, Dict) || isa(param, NamedTuple)
            # Handle parameter dictionaries
            sorted_pairs = sort(collect(pairs(param)))
            for (k, v) in sorted_pairs
                if isa(v, AbstractMatrix)
                    v_str = "Matrix($(size(v)),$(hash(v)))"
                elseif isa(v, AbstractArray)
                    v_str = "Array($(length(v)),$(hash(v)))"
                elseif isa(v, Function)
                    v_str = string(v)
                else
                    v_str = repr(v)
                end
                push!(param_strs, "$(k)=$(v_str)")
            end
        elseif isa(param, AbstractArray)
            # Handle domain arrays
            push!(param_strs, join(string.(param), "_"))
        else
            push!(param_strs, repr(param))
        end
    end
    return join(param_strs, "|")
end

"""
    get_experiment_uuid(experiment_type::Symbol, params...) -> UUID

Generate a deterministic UUID for experiment parameters.
"""
function get_experiment_uuid(experiment_type::Symbol, params...)
    base_uuid = if experiment_type == :exploration
        EXPLORATION_BASE_UUID
    elseif experiment_type == :icn
        ICN_BASE_UUID
    else
        error("Unknown experiment type: $experiment_type")
    end

    param_string = flatten_parameters(params...)
    return uuid5(base_uuid, param_string)
end

"""
    get_system_experiment_uuid(experiment_type::Symbol, params...) -> UUID

Generate a system-dependent UUID for experiment parameters (for ICN-like experiments).
"""
function get_system_experiment_uuid(experiment_type::Symbol, params...)
    param_string = flatten_parameters(params...)
    system_uuid = get_system_uuid()
    return uuid5(system_uuid, param_string)
end

"""
    experiment_filename(experiment_type::Symbol, params...; ext::String="json") -> String

Generate a short, filesystem-safe filename for experiment data.
"""
function experiment_filename(experiment_type::Symbol, params...; ext::String="json")
    if experiment_type == :icn
        uuid = get_system_experiment_uuid(experiment_type, params...)
    else
        uuid = get_experiment_uuid(experiment_type, params...)
    end
    return "$(uuid).$(ext)"
end

"""
    system_fingerprint() -> Dict

Create a system fingerprint with hardware and software information.
"""
function system_fingerprint()
    cpu_info_data = cpu_info()
    cpu_name = length(cpu_info_data) > 0 ? cpu_info_data[1].model : "Unknown"

    return Dict(
        "cpu_name" => cpu_name,
        "cpu_cores" => cpucores(),
        "cpu_threads" => cputhreads(),
        "threads_per_core" => cputhreads_per_core(),
        "word_size" => WORD_SIZE,
        "simd_bytes" => simdbytes(),
        "julia_version" => string(VERSION),
        "os" => string(Sys.KERNEL),
        "arch" => string(Sys.ARCH),
        "machine" => gethostname(),
        "timestamp" => string(now())
    )
end

"""
    save_experiment_metadata(experiment_type::Symbol, params...;
                           metadata_file::String,
                           system_metadata_file::String="")

Save experiment metadata to files. For system-dependent experiments, also saves system metadata.
"""
function save_experiment_metadata(experiment_type::Symbol, params...;
    metadata_file::String,
    system_metadata_file::String="")

    # Generate UUIDs
    if experiment_type == :icn
        param_uuid = get_system_experiment_uuid(experiment_type, params...)
        system_uuid = get_system_uuid()
        needs_system_metadata = true
    else
        param_uuid = get_experiment_uuid(experiment_type, params...)
        system_uuid = nothing
        needs_system_metadata = false
    end

    param_string = flatten_parameters(params...)

    # Ensure directories exist
    mkpath(dirname(metadata_file))
    if needs_system_metadata && !isempty(system_metadata_file)
        mkpath(dirname(system_metadata_file))
    end

    # Save parameter metadata
    if !in_experiment_metadata(metadata_file, param_string, system_uuid)
        open(metadata_file, "a") do io
            if !isfile(metadata_file) || filesize(metadata_file) == 0
                if needs_system_metadata
                    println(io, "param_uuid,system_uuid,experiment_type,parameters,full_description")
                else
                    println(io, "param_uuid,experiment_type,parameters,full_description")
                end
            end

            # Escape commas and quotes
            full_desc = replace(param_string, "," => ";", "\"" => "'")
            if needs_system_metadata
                println(io, "$(param_uuid),$(system_uuid),$(experiment_type),\"$(repr(params))\",\"$(full_desc)\"")
            else
                println(io, "$(param_uuid),$(experiment_type),\"$(repr(params))\",\"$(full_desc)\"")
            end
        end
        @info "Writing experiment metadata" metadata_file experiment_type
    end

    # Save system metadata if needed
    if needs_system_metadata && !isempty(system_metadata_file) && !in_system_metadata(system_metadata_file, system_uuid)
        fingerprint = system_fingerprint()
        open(system_metadata_file, "a") do io
            if !isfile(system_metadata_file) || filesize(system_metadata_file) == 0
                println(io, "system_uuid,cpu_name,cpu_cores,cpu_threads,julia_version,os,arch,machine,timestamp,full_fingerprint")
            end

            println(io, "$(system_uuid),\"$(fingerprint["cpu_name"])\",$(fingerprint["cpu_cores"]),$(fingerprint["cpu_threads"]),\"$(fingerprint["julia_version"])\",\"$(fingerprint["os"])\",\"$(fingerprint["arch"])\",\"$(fingerprint["machine"])\",\"$(fingerprint["timestamp"])\",\"$(JSON.json(fingerprint))\"")
        end
        @info "Writing system metadata" system_metadata_file
    end

    return param_uuid, system_uuid
end

"""
    in_experiment_metadata(metadata_file::String, param_string::String, system_uuid::Union{UUID,Nothing}) -> Bool

Check if experiment entry already exists in metadata file.
"""
function in_experiment_metadata(metadata_file::String, param_string::String, system_uuid::Union{UUID,Nothing})
    if !isfile(metadata_file)
        return false
    end

    search_string = if system_uuid !== nothing
        "$(param_string),$(system_uuid)"
    else
        param_string
    end

    for line in eachline(metadata_file)
        if occursin(search_string, line)
            return true
        end
    end
    return false
end

"""
    in_system_metadata(system_metadata_file::String, system_uuid::UUID) -> Bool

Check if system entry already exists in system metadata file.
"""
function in_system_metadata(system_metadata_file::String, system_uuid::UUID)
    if !isfile(system_metadata_file)
        return false
    end

    for line in eachline(system_metadata_file)
        if startswith(line, string(system_uuid))
            return true
        end
    end
    return false
end

"""
    save_experiment_results(experiment_type::Symbol, results::Dict, params...;
                           results_dir::String,
                           metadata_file::String,
                           system_metadata_file::String="")

Save experiment results with proper metadata tracking.
"""
function save_experiment_results(experiment_type::Symbol, results::Dict, params...;
    results_dir::String,
    metadata_file::String,
    system_metadata_file::String="")

    # Ensure results directory exists
    mkpath(results_dir)

    # Save metadata and get UUID
    param_uuid, system_uuid = save_experiment_metadata(
        experiment_type, params...;
        metadata_file=metadata_file,
        system_metadata_file=system_metadata_file
    )

    # Create filename and save results
    filename = experiment_filename(experiment_type, params...; ext="json")
    save_path = joinpath(results_dir, filename)

    # Add metadata to results
    results_with_metadata = copy(results)
    results_with_metadata[:experiment_uuid] = string(param_uuid)
    results_with_metadata[:experiment_type] = string(experiment_type)
    results_with_metadata[:timestamp] = string(now())
    if system_uuid !== nothing
        results_with_metadata[:system_uuid] = string(system_uuid)
    end

    write(save_path, JSON.json(results_with_metadata, 2))
    @info "Results saved to: $save_path (UUID: $param_uuid)"

    return save_path, param_uuid
end

# Legacy compatibility functions for existing code
const get_exploration_uuid = (params...) -> get_experiment_uuid(:exploration, params...)
const exploration_filename = (params...; ext="json") -> experiment_filename(:exploration, params...; ext=ext)
const save_exploration_metadata = (params...; metadata_file) -> save_experiment_metadata(:exploration, params...; metadata_file=metadata_file)[1]

const get_icn_uuid = (params...) -> get_system_experiment_uuid(:icn, params...)
const icn_filename = (params...; ext="json") -> experiment_filename(:icn, params...; ext=ext)
const save_icn_metadata = (params...; metadata_file, system_metadata_file) -> save_experiment_metadata(:icn, params...; metadata_file=metadata_file, system_metadata_file=system_metadata_file)
