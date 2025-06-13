module ConstraintLearningBenchmarks

# imports
import ConstraintCommons
import ConstraintDomains: domain, ConstraintDomains
import Constraints: USUAL_CONSTRAINTS, Constraint, Constraints, concept
import CSV
import DrWatson: DrWatson, savename, datadir
import Tables
import UUIDs: UUID, uuid4, uuid5

# includes
include("constants.jl")
include("parameters.jl")
include("constraint_arities.jl")
include("experiment_storage.jl")
include("exploration_storage.jl")
include("icn_storage.jl")
include("exploration.jl")
include("init.jl")

# exports
export generate_parameters, generate_parameters!
export search_space, explore
export parse_name, parse_domains, parse_params, is_uuid_format, parse_domains_safe
export get_exploration_uuid, exploration_filename, save_exploration_metadata, load_exploration_metadata
export get_icn_uuid, icn_filename, save_icn_metadata, load_icn_metadata, load_system_metadata
export flatten_exploration_parameters, flatten_icn_parameters
export get_system_uuid, system_fingerprint
export get_constraint_arity, create_domains_for_constraint
export get_experiment_uuid, get_system_experiment_uuid, experiment_filename
export save_experiment_metadata, save_experiment_results, flatten_parameters
export BENCHED_CONSTRAINTS, USUAL_DOMAINS

end
