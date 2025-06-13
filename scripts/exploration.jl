include("generic.jl")

using JSON
using Dates
using Statistics
using ConstraintLearningBenchmarks: save_experiment_results, BENCHED_CONSTRAINTS, create_domains_for_constraint

# SECTION - Exploration Experiment Configuration
const EXPLORATION_EXPERIMENT_PARAMS = Dict(
    :domain_sizes => [3, 4, 5],  # Based on USUAL_DOMAINS
    :parameters_explorations_values => [1, 2, 3]
)

# SECTION - Helper Functions
function analyze_exploration_results(X::Set, X̅::Set, constraint_name::Symbol, domains_config::Vector)
    """Analyze exploration results and compute statistics."""
    solutions = collect(X)
    non_solutions = collect(X̅)

    # Basic statistics
    total_configurations = length(solutions) + length(non_solutions)
    solution_ratio = length(solutions) / max(total_configurations, 1)

    # Domain analysis
    domain_sizes = [length(d) for d in domains_config]
    total_possible = prod(domain_sizes)
    coverage_ratio = total_configurations / total_possible

    # Variable analysis
    num_variables = length(domains_config)

    return Dict(
        :constraint => string(constraint_name),
        :num_variables => num_variables,
        :domain_sizes => domain_sizes,
        :total_possible_configurations => total_possible,
        :total_explored_configurations => total_configurations,
        :solutions_count => length(solutions),
        :non_solutions_count => length(non_solutions),
        :solution_ratio => solution_ratio,
        :coverage_ratio => coverage_ratio,
        :exploration_efficiency => solution_ratio > 0 ? coverage_ratio / solution_ratio : 0.0
    )
end

function check_exploration_experiment_exists(constraint_name::Symbol, domains_config::Vector, params_explorations::Int, metadata_file::String)
    """Check if exploration experiment already exists in metadata."""
    if !isfile(metadata_file)
        return false
    end

    try
        for line in eachline(metadata_file)
            if occursin(string(constraint_name), line) &&
               occursin(string(params_explorations), line) &&
               occursin("exploration", line)
                return true
            end
        end
    catch
        return false
    end
    return false
end

# SECTION - Main Exploration Loop
function run_exploration_experiments()
    """Main function to run exploration experiments on all benchmarked constraints."""

    @info "Starting exploration experiments"
    @info "Total constraints to process: $(length(BENCHED_CONSTRAINTS))"

    experiment_count = 0
    total_experiments = length(BENCHED_CONSTRAINTS) *
                        length(EXPLORATION_EXPERIMENT_PARAMS[:domain_sizes]) *
                        length(EXPLORATION_EXPERIMENT_PARAMS[:parameters_explorations_values])

    # Set up storage paths
    results_dir = joinpath(datadir("exploration_results"))
    metadata_file = joinpath(datadir(), "exploration_experiment_metadata.csv")
    mkpath(results_dir)

    for (constraint_name, constraint) in BENCHED_CONSTRAINTS
        @info "Processing constraint: $(string(constraint_name))"

        for domain_size in EXPLORATION_EXPERIMENT_PARAMS[:domain_sizes]
            @info "Processing domain size: $domain_size"

            # Create domains using constraint-aware logic
            domains_config = create_domains_for_constraint(constraint_name, domain_size)

            for params_explorations in EXPLORATION_EXPERIMENT_PARAMS[:parameters_explorations_values]
                experiment_count += 1
                experiment_name = "$(constraint_name)_dom$(domain_size)_params$(params_explorations)"

                # Check if experiment already exists
                if check_exploration_experiment_exists(constraint_name, domains_config, params_explorations, metadata_file)
                    @info "Skipping experiment $experiment_count/$total_experiments (results exist): $experiment_name"
                    continue
                end

                @info "Running experiment $experiment_count/$total_experiments: $experiment_name"

                # Time the exploration process
                exploration_time = @elapsed begin
                    # Run exploration using the existing infrastructure
                    X, X̅, has_cached_data = search_space(
                        domains_config, constraint;
                        exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
                        parameters_explorations=params_explorations,
                        settings=ExploreSettings(domains_config)
                    )

                    @info "Exploration completed" solutions = length(X) non_solutions = length(X̅) cached = has_cached_data
                end

                # Analyze results
                analysis = analyze_exploration_results(X, X̅, constraint_name, domains_config)

                # Prepare results dictionary
                results = Dict{Any,Any}(
                    :experiment_name => experiment_name,
                    :constraint => string(constraint_name),
                    :domain_size => domain_size,
                    :domains_configuration => string.(domains_config),
                    :parameters_explorations => params_explorations,
                    :has_cached_data => has_cached_data,
                    :exploration_time => exploration_time,
                    :timestamp => string(now())
                )

                # Add analysis results
                merge!(results, analysis)

                # Add sample solutions and non-solutions (limited to avoid huge files)
                sample_size = min(100, length(X))
                if sample_size > 0
                    sample_solutions = collect(X)[1:min(sample_size, length(X))]
                    results[:sample_solutions] = [collect(sol) for sol in sample_solutions]
                end

                sample_size = min(100, length(X̅))
                if sample_size > 0
                    sample_non_solutions = collect(X̅)[1:min(sample_size, length(X̅))]
                    results[:sample_non_solutions] = [collect(non_sol) for non_sol in sample_non_solutions]
                end

                # Save results using unified storage system
                save_path, experiment_uuid = save_experiment_results(
                    :exploration, results, constraint_name, domain_size, params_explorations;
                    results_dir=results_dir,
                    metadata_file=metadata_file
                )

                @info "Experiment completed and saved" uuid = experiment_uuid path = basename(save_path)
            end
        end
    end

    @info "Exploration experiments completed!"
    @info "Total experiments run: $experiment_count"
end

# SECTION - Execution
@info "Exploration Experiments Script Loaded"
@info "Available functions:"
@info "  - run_exploration_experiments(): Run all exploration experiments"
@info "  - EXPLORATION_EXPERIMENT_PARAMS: View/modify experiment parameters"

# Run the experiments
run_exploration_experiments()
