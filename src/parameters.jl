# Import necessary functions for UUID handling
import UUIDs: UUID
import DrWatson: datadir

function DrWatson.savename(s::Symbol, params, d)
    st(x::Function) = "\'" * string(x) * "\'"
    st(x) = string(x)

    dim = get(params, :dim, 1)
    if :vals ∈ keys(params)
        params[:vals] = @view params[:vals][:, dim == 1 ? 1 : (1:dim)]
    end

    fred = (a, b, s) -> a * s * b
    fred1 = (a, b) -> fred(a, b, "-")
    fred2 = (a, b) -> fred(a, b, "_")

    fmap = p -> st(p.first) * "=" * st(p.second)
    params_str = mapreduce(fmap, fred1, params; init="")
    if !isempty(params_str)
        params_str = "-" * params_str[2:end]
    end

    domains_str = mapreduce(string, fred2, d)

    return string(s) * params_str * "-domains=" * domains_str
end

function parse_domains(domains)
    S = split(domains, '=')
    S = split(S[end], '_')
    return map(str -> begin
            try
                eval(Meta.parse(str)) |> domain
            catch e
                # If parsing fails (e.g., for UUID segments), skip this part
                @warn "Could not parse domain segment '$str', skipping"
                nothing
            end
        end, S) |> filter(!isnothing)
end

function is_uuid_format(name::AbstractString)
    # Check if string matches UUID format: 8-4-4-4-12 characters
    parts = split(name, '-')
    return length(parts) == 5 &&
           length(parts[1]) == 8 &&
           length(parts[2]) == 4 &&
           length(parts[3]) == 4 &&
           length(parts[4]) == 4 &&
           length(parts[5]) == 12 &&
           all(p -> all(c -> isdigit(c) || c in 'a':'f' || c in 'A':'F', p), parts)
end

function parse_domains_safe(domains_str)
    try
        return parse_domains(domains_str)
    catch e
        @warn "Could not parse domains from string: $domains_str, error: $e"
        # Return empty domain list as fallback
        return []
    end
end

function parse_params(params)
    D = Dict{Symbol,String}()
    if !isempty(params)
        function f(str)
            v = split(str, '=')
            D[Symbol(v[1])] = v[2]
        end
        foreach(f, params)
    end
    return D
end

function parse_name(name::AbstractString)
    # Check if this is a UUID format
    if is_uuid_format(name)
        # For UUID format, we need to look up metadata
        # Try to find metadata file in the standard location
        metadata_file = joinpath(datadir(), "exploration_metadata.csv")

        if isfile(metadata_file)
            try
                uuid = UUID(name)
                metadata = lookup_exploration_parameters(uuid, metadata_file)
                if metadata !== nothing
                    return metadata[:symbol], metadata[:parameters], metadata[:domains]
                end
            catch e
                @warn "Could not parse UUID or lookup metadata for $name: $e"
            end
        end

        # For UUID format without metadata, we can't meaningfully parse it
        # Return a placeholder that will be handled gracefully
        @warn "UUID-based exploration space '$name' found but no metadata available. Skipping."
        return :unknown, Dict{Symbol,Any}(), []
    else
        # Legacy format parsing
        v = split(name, "-")
        s = Symbol(v[1])
        domains = v[end] |> parse_domains_safe
        params = v[2:end-1] |> parse_params
        return s, params, domains
    end
end

function generate_parameters!(D::Dict, iterations::Int, s::Symbol, c, d=domain())
    valid_tuples = n -> Iterators.product([(0, 1) for _ in 1:n]...) |> collect |> vec

    for (i, param_set) in enumerate(c.params)
        aux_opts = filter(p -> isone(p.second), param_set) |> keys |> collect
        required = filter(p -> iszero(p.second), param_set) |> keys |> collect

        vt = valid_tuples(length(aux_opts))
        for (j, x) in vt |> enumerate
            optional = filter(p -> isone(p[2]), zip(aux_opts, x) |> collect) .|> first

            P = Dict{Symbol,Any}()
            for p in Iterators.flatten((optional, required))
                push!(P, p => ConstraintDomains.generate_parameters(d, p))
            end
            for i in 1:iterations
                Q = Dict{Symbol,Any}()
                for (k, v) in P
                    # @info "debug" k v
                    push!(Q, k => rand(v))
                end
                # Use UUID-based naming instead of long descriptive names
                uuid = get_exploration_uuid(s, Q, d)
                push!(D, string(uuid) => Q)
            end
        end
    end
end

function generate_parameters(
    s::Symbol,
    c::Constraint,
    d;
    exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
    parameters_explorations=1
)
    generate_parameters!(
        exploration_spaces,
        parameters_explorations,
        s, c, d
    )
    return exploration_spaces
end
