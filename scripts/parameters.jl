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

exploration_spaces = Dict{String,Dict{Symbol,Any}}()
parameters_explorations = 1

for (s, c) in USUAL_CONSTRAINTS
    ConstraintLearningBenchmarks.generate_parameters(
        s, c, [domain(0:2), domain(0:5), domain([0, 1])]; exploration_spaces, parameters_explorations
    )
end

exploration_spaces
