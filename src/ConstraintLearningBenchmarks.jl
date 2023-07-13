module ConstraintLearningBenchmarks

# usings
# using BenchmarkTools
using ConstraintCommons
using ConstraintDomains
# using ConstraintLearning
using Constraints
using CSV
# using DataFrames
# using DataVoyager
# using Dictionaries
# using Distributed
using DrWatson
# using JSON
# using Statistics
# using StatsBase
using Tables

using Base:
    IOError, UV_EEXIST, UV_ESRCH,
    Process, open

using Base.Filesystem:
    File, open, JL_O_CREAT, JL_O_RDWR, JL_O_RDONLY, JL_O_EXCL,
    samefile

# constants
# export ALL_PARAMETERS
# export BENCHED_CONSTRAINTS
export EXPLORATION_VARIABLES
export USUAL_DOMAINS

# others
# export analyse_composition
# export analyze_icn
# export compositions_benchmark
# export icn_benchmark
export search_space
# export visualize_compositions
# export visualize_icn

# includes
include("constants.jl")
include("parameters.jl")
include("exploration.jl")
# include("extra_constraints.jl")
# include("icn.jl")
# include("composition.jl")
# include("analyze.jl")

end
