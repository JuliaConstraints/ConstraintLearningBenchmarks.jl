"""
ICN Storage System

Provides system-aware storage for ICN (Interpretable Compositional Networks) results.
This system follows the exact PerfChecker.jl pattern since ICN performance is system-dependent.
"""

import Base.Sys: CPUinfo, CPU_NAME, cpu_info, WORD_SIZE
import CpuId: simdbytes, cpucores, cputhreads, cputhreads_per_core
import UUIDs: UUID, uuid4, uuid5
import CSV
import JSON
import Pkg
import Dates: now

"""
    get_system_uuid() -> UUID

Get the system UUID from environment variable, following PerfChecker.jl pattern.
The UUID is automatically set up by the __init__() function.
"""
function get_system_uuid()
    return UUID(ENV["JULIACONSTRAINTS_UUID"])
end

"""
    flatten_icn_parameters(params...) -> String

Convert ICN parameters into a canonical string representation for UUID generation.
Following PerfChecker.jl's flatten_parameters pattern.
"""
function flatten_icn_parameters(params...)
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
                push!(param_strs, "$(k)=$(repr(v))")
            end
        else
            push!(param_strs, repr(param))
        end
    end
    return join(param_strs, "_")
end

"""
    get_icn_uuid(params...) -> UUID

Generate a deterministic UUID for ICN parameters, following PerfChecker.jl pattern.
"""
function get_icn_uuid(params...)
    param_string = flatten_icn_parameters(params...)
    system_uuid = get_system_uuid()
    return uuid5(system_uuid, param_string)
end

"""
    icn_filename(params...; ext::String="json") -> String

Generate a short, filesystem-safe filename for ICN data.
Following PerfChecker.jl's filename pattern.
"""
function icn_filename(params...; ext::String="json")
    uuid = get_icn_uuid(params...)
    return "$(uuid).$(ext)"
end

"""
    system_fingerprint() -> Dict

Create a system fingerprint with hardware and software information.
Similar to PerfChecker.jl's hardware info collection.
"""
function system_fingerprint()
    # CPU information
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
    save_icn_metadata(params...; metadata_file::String, system_metadata_file::String)

Save ICN parameter and system mapping to metadata files.
Following PerfChecker.jl's check_to_metadata pattern.
"""
function save_icn_metadata(params...; metadata_file::String, system_metadata_file::String)
    param_uuid = get_icn_uuid(params...)
    system_uuid = get_system_uuid()
    param_string = flatten_icn_parameters(params...)

    # Ensure directories exist
    mkpath(dirname(metadata_file))
    mkpath(dirname(system_metadata_file))

    # Save parameter metadata
    if !in_icn_metadata(metadata_file, param_string, system_uuid)
        open(metadata_file, "a") do io
            if !isfile(metadata_file) || filesize(metadata_file) == 0
                println(io, "param_uuid,system_uuid,parameters,full_description")
            end

            # Escape commas and quotes
            full_desc = replace(param_string, "," => ";", "\"" => "'")
            println(io, "$(param_uuid),$(system_uuid),\"$(repr(params))\",\"$(full_desc)\"")
        end
        @info "Writing ICN metadata" metadata_file
    end

    # Save system metadata
    if !in_system_metadata(system_metadata_file, system_uuid)
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
    in_icn_metadata(metadata_file::String, param_string::String, system_uuid::UUID) -> Bool

Check if parameter entry already exists in metadata file.
Following PerfChecker.jl's in_metadata pattern.
"""
function in_icn_metadata(metadata_file::String, param_string::String, system_uuid::UUID)
    if !isfile(metadata_file)
        return false
    end

    for line in eachline(metadata_file)
        if occursin("$(param_string),$(system_uuid)", line)
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
    load_icn_metadata(metadata_file::String) -> Dict{UUID, Dict}

Load ICN metadata from CSV file.
"""
function load_icn_metadata(metadata_file::String)
    if !isfile(metadata_file)
        return Dict{UUID,Dict}()
    end

    data = CSV.read(metadata_file, Dict)
    result = Dict{UUID,Dict}()

    for row in data
        param_uuid = UUID(row["param_uuid"])
        result[param_uuid] = Dict(
            :system_uuid => UUID(row["system_uuid"]),
            :parameters => eval(Meta.parse(row["parameters"])),
            :full_description => row["full_description"]
        )
    end

    return result
end

"""
    load_system_metadata(system_metadata_file::String) -> Dict{UUID, Dict}

Load system metadata from CSV file.
"""
function load_system_metadata(system_metadata_file::String)
    if !isfile(system_metadata_file)
        return Dict{UUID,Dict}()
    end

    data = CSV.read(system_metadata_file, Dict)
    result = Dict{UUID,Dict}()

    for row in data
        system_uuid = UUID(row["system_uuid"])
        result[system_uuid] = Dict(
            :cpu_name => row["cpu_name"],
            :cpu_cores => row["cpu_cores"],
            :cpu_threads => row["cpu_threads"],
            :julia_version => row["julia_version"],
            :os => row["os"],
            :arch => row["arch"],
            :machine => row["machine"],
            :timestamp => row["timestamp"],
            :full_fingerprint => JSON.parse(row["full_fingerprint"])
        )
    end

    return result
end
