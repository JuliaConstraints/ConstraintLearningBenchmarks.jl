using DrWatson

@quickactivate "ConstraintLearningBenchmarks"

import ConstraintLearningBenchmarks: BENCHED_CONSTRAINTS, search_space, ConstraintLearningBenchmarks
import ConstraintDomains: ExploreSettings, domain, ConstraintDomains
import Constraints

# Visualization for the Term.jl package (ignore)
if "Term" ∈ map(k -> k.name, Base.loaded_modules |> keys |> collect)
    Base.max() = 0
    Base.isless(f1::Function, f2::Function) = isless(string(f1), string(f2))
    function Base.isless(
        fa1::ConstraintDomains.FakeAutomaton,
        fa2::ConstraintDomains.FakeAutomaton,
    )
        return isless(fa1.words |> length, fa2.words |> length)
    end
end
