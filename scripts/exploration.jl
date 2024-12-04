include("generic.jl")

# NOTE - The Following code is for testing purposes only (maybe t should be moved ...)

ConstraintLearningBenchmarks.explore(
    [
        [domain(0:4), domain(0:1), domain(0:2), domain(0:3)],
        [domain(0:2), domain(0:2), domain(0:2), domain(0:2)],
        [domain(0:1), domain(0:1), domain(0:1), domain(0:1)],
        [domain(0:4), domain(0:4), domain(0:4), domain(0:4)],
    ];
    parameters_explorations=1)
