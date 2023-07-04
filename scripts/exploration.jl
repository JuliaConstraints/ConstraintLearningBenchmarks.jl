include("generic.jl")

search_space(
    [domain(0:2), domain(0:5), domain(0:1)],
    USUAL_CONSTRAINTS[:all_different];
    parameters_explorations=1
)
