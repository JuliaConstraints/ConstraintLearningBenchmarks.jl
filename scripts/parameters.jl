include("generic.jl")

# Visualization for the Term.jl package (ignore)
# if Term ∈ Base.loaded_modules |> values
#     Base.max() = 0
#     Base.isless(f1::Function, f2::Function) = isless(string(f1), string(f2))
#     function Base.isless(
#         fa1::ConstraintDomains.FakeAutomaton,
#         fa2::ConstraintDomains.FakeAutomaton,
#     )
#         return isless(fa1.words |> length, fa2.words |> length)
#     end
# end

# function DrWatson.savename(s::Symbol, params::Dict, d)
#     st(x::Function) = "\'" * string(x) * "\'"
#     st(x) = string(x)

#     fred = (a, b) -> a * "_" * b

#     fmap = p -> st(p.first) * "=" * st(p.second)
#     params_str = mapreduce(fmap, fred, params; init="")

#     domains_str = mapreduce(string, fred, d; init="")

#     return string(s) * "_" * params_str * "_domains=" * domains_str
# end

# function generate_parameters!(D::Dict, iterations::Int, s::Symbol, c, d=domain())
#     valid_tuples = n -> Iterators.product([(0, 1) for _ in 1:n]...) |> collect |> vec

#     for (i, param_set) in enumerate(c.params)
#         aux_opts = filter(p -> isone(p.second), param_set) |> keys |> collect
#         required = filter(p -> iszero(p.second), param_set) |> keys |> collect

#         # param_set_string = length(c.params) > 1 ? "$s =>\n\tparameter set $i/$(length(c.params))" : "$s"

#         vt = valid_tuples(length(aux_opts))
#         for (j, x) in vt |> enumerate
#             optional = filter(p -> isone(p[2]), zip(aux_opts, x) |> collect) .|> first
#             # if isempty(optional)
#             #     if isempty(required)
#             #         @info "Constraint: $param_set_string (no parameters)"
#             #     else
#             #         @info "Constraint: $param_set_string" required
#             #     end
#             # else
#             #     str = param_set_string * "\n\t optional set $(j-1)/$(length(vt)-1)"
#             #     if isempty(required)
#             #         @info "Constraint: $str" optional
#             #     else
#             #         @info "Constraint: $str" required optional
#             #     end
#             # end

#             P = Dict{Symbol,Any}()
#             for p in Iterators.flatten((optional, required))
#                 push!(P, p => ConstraintDomains.generate_parameters(d, p))
#             end
#             for i in 1:iterations
#                 Q = Dict{Symbol,Any}()
#                 for (k, v) in P
#                     # @info "debug" k v
#                     push!(Q, k => rand(v))
#                 end
#                 push!(D, savename(s, Q, d) => Q)
#             end
#             # Q1 = Dictionary(keys(P), map(rand, values(P)))
#             # Q2 = Dictionary(keys(P), map(rand, values(P)))
#             # @info "Parameters: " Dictionary(P) Q1 Q2
#         end
#     end
# end

# function generate_parameters(d=domain(); constraints=USUAL_CONSTRAINTS, parameter_explorations=1)
#     exploration_spaces = Dict{String,Dict{Symbol,Any}}()
#     for (s, c) in constraints
#         generate_parameters!(exploration_spaces, parameter_explorations, s, c, d)
#     end
#     return exploration_spaces
# end

exploration_spaces = Dict{String,Dict{Symbol,Any}}()
parameter_explorations = 10

for (s, c) in USUAL_CONSTRAINTS
    ConstraintLearningBenchmarks.generate_parameters(
        s, c, [domain(0:2), domain(0:5), domain(0:1)]; exploration_spaces, parameter_explorations
    )
end

exploration_spaces
