using DrWatson

@quickactivate "ConstraintLearningBenchmarks"

using ConstraintLearningBenchmarks
using ConstraintDomains
using Constraints
using Dictionaries

# Visualization for the Term.jl package (ignore)
if Term ∈ Base.loaded_modules |> values
    Base.max() = 0
    Base.isless(f1::Function, f2::Function) = isless(string(f1), string(f2))
    function Base.isless(
        fa1::ConstraintDomains.FakeAutomaton,
        fa2::ConstraintDomains.FakeAutomaton,
    )
        return isless(fa1.words |> length, fa2.words |> length)
    end
end
