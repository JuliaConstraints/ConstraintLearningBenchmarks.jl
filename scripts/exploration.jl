include("generic.jl")

# search_space(
#     [domain(0:2), domain(0:5), domain(0:1)],
#     USUAL_CONSTRAINTS[:all_different];
#     parameters_explorations=1
# )

# function explore(
#     domains;
#     constraints=USUAL_CONSTRAINTS,
#     exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
#     parameters_explorations=1
# )
#     for (s, c) in constraints, doms in domains
#         ConstraintLearningBenchmarks.generate_parameters(
#             s, c, doms; exploration_spaces, parameters_explorations
#         )
#     end

#     explo_path = joinpath(datadir(), "exploration_spaces")
#     mkpath(explo_path)

#     for (space, params) in exploration_spaces
#         file_solutions = joinpath(explo_path, space * "-solutions.txt")
#         file_non_sltns = joinpath(explo_path, space * "-non_sltns.txt")
#         isfile(file_solutions) && isfile(file_non_sltns) && continue
#         rm(file_solutions; force=true)
#         rm(file_non_sltns; force=true)
#         mkpath(dirname(file_solutions))

#         s, _, doms = ConstraintLearningBenchmarks.parse_name(space)
#         @info "exploring" space s doms params
#         c = USUAL_CONSTRAINTS[s]
#         S, S̅ = ConstraintDomains.explore(doms, c.concept; params...)
#         @info "ouput" S S̅
#         open(file_solutions, "w") do io
#             for s in S
#                 println(io, s)
#             end
#         end
#         open(file_non_sltns, "w") do io
#             for s in S̅
#                 println(io, s)
#             end
#         end
#     end
# end

ConstraintLearningBenchmarks.explore(
    [
    [domain(0:4), domain(0:1), domain(0:2), domain(0:3)],
    [domain(0:2), domain(0:2), domain(0:2), domain(0:2)],
    [domain(0:1), domain(0:1), domain(0:1), domain(0:1)],
    [domain(0:4), domain(0:4), domain(0:4), domain(0:4)],
    ];
    parameters_explorations = 1000 )
