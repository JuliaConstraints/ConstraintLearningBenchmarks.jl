function DrWatson.savename(s::Symbol, params, d)
    st(x::Function) = "\'" * string(x) * "\'"
    st(x) = string(x)

    dim = get(params, :dim, 1)
    if :vals ∈ keys(params)
        params[:vals] = @view params[:vals][:, dim == 1 ? 1 : (1:dim)]
    end

    fred = (a, b) -> a * "_" * b

    fmap = p -> st(p.first) * "=" * st(p.second)
    params_str = mapreduce(fmap, fred, params; init="")

    domains_str = mapreduce(string, fred, d)

    return string(s) * params_str * "_domains=" * domains_str
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
                push!(D, savename(s, Q, d) => Q)
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