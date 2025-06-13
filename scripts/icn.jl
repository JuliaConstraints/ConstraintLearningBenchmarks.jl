include("generic.jl")

using CompositionalNetworks
using JSON
using Dates
using Statistics
using ConstraintLearningBenchmarks: get_icn_uuid, icn_filename, save_icn_metadata, create_domains_for_constraint

using Evolutionary

# SECTION - Experiment Configuration
const ICN_EXPERIMENT_PARAMS = Dict(
    :domains_sizes => [3, 4, 5],  # Based on USUAL_DOMAINS
    :optimizers => [
        GeneticOptimizer(100, 50, true, 64, nothing),  # global_iter, local_iter, memoize, pop_size, sampler
        # MetaheuristicsOptimizer can be added when the extension is loaded
    ],
    :metrics => [hamming, manhattan],
    :search_modes => [:complete, :partial],
    :complete_search_limit => 5^5,
    :solutions_limit => 1000
)

# SECTION - Helper Functions
function create_icn_for_constraint(constraint_name::Symbol)
    """Create an ICN configuration appropriate for the given constraint."""
    return ICN(
        parameters=[:dom_size, :numvars],
        layers=[Transformation, Arithmetic, Aggregation, Comparison],
        connection=[1, 2, 3, 4]
    )
end

function generate_experiment_name(constraint_name, domain_size, optimizer_type, metric)
    """Generate a unique name for the experiment configuration."""
    return "$(constraint_name)_dom$(domain_size)_$(optimizer_type)_$(metric)"
end

function save_experiment_results(results::Dict, constraint_name::Symbol, domain_size::Int, optimizer, metric)
    """Save experiment results to JSON file using UUID-based naming."""
    # Ensure the results directory exists
    results_dir = joinpath(datadir("icn_results"))
    mkpath(results_dir)

    # Create metadata files paths at root of data folder
    metadata_file = joinpath(datadir(), "icn_metadata.csv")
    system_metadata_file = joinpath(datadir(), "system_metadata.csv")

    # Generate UUID-based filename using ICN storage system
    optimizer_name = string(typeof(optimizer))
    metric_name = string(metric)
    timestamp = string(now())

    # Save metadata and get UUID
    param_uuid, system_uuid = save_icn_metadata(
        constraint_name, domain_size, optimizer_name, metric_name, timestamp;
        metadata_file=metadata_file,
        system_metadata_file=system_metadata_file
    )

    # Create UUID-based filename
    filename = icn_filename(constraint_name, domain_size, optimizer_name, metric_name, timestamp; ext="json")
    save_path = joinpath(results_dir, filename)

    # Save results
    write(save_path, JSON.json(results, 2))
    @info "Results saved to: $save_path (UUID: $param_uuid)"

    return save_path, param_uuid
end

function evaluate_icn_on_test_domains(learned_icn, constraint, constraint_name, base_domain_size)
    """Evaluate the learned ICN on different domain sizes for generalization testing."""
    test_results = Dict()

    for test_size in [base_domain_size + 1, base_domain_size + 2]
        @info "Testing on domain size: $test_size"

        # Create test domains using constraint-aware logic
        test_domains = create_domains_for_constraint(constraint_name, test_size)

        # Generate test configurations using the same parameter mechanism as search_space
        # Use search_space to get properly parameterized configurations
        X, X̅, _ = search_space(
            test_domains, constraint;
            exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
            parameters_explorations=1,
            settings=ExploreSettings(test_domains)
        )

        # Convert to the format expected by the evaluation
        test_configs = [collect.(X)..., collect.(X̅)...]

        # Evaluate learned ICN on test configurations
        evaluations = []
        for config in test_configs
            result = evaluate(learned_icn, config; numvars=length(config), dom_size=test_size)
            push!(evaluations, result)
        end

        # Calculate statistics
        valid_evaluations = filter(x -> !isinf(x) && !isnan(x), evaluations)
        if !isempty(valid_evaluations)
            test_results[test_size] = Dict(
                :mean => mean(valid_evaluations),
                :median => median(valid_evaluations),
                :std => std(valid_evaluations),
                :min => minimum(valid_evaluations),
                :max => maximum(valid_evaluations),
                :count => length(valid_evaluations),
                :total_configs => length(evaluations)
            )
        else
            test_results[test_size] = Dict(
                :error => "No valid evaluations",
                :total_configs => length(evaluations)
            )
        end
    end

    return test_results
end

# SECTION - Main ICN Learning Loop
function run_icn_experiments()
    """Main function to run ICN learning experiments on all benchmarked constraints."""

    @info "Starting ICN learning experiments"
    @info "Total constraints to process: $(length(BENCHED_CONSTRAINTS))"

    experiment_count = 0
    total_experiments = length(BENCHED_CONSTRAINTS) *
                        length(ICN_EXPERIMENT_PARAMS[:domains_sizes]) *
                        length(ICN_EXPERIMENT_PARAMS[:optimizers]) *
                        length(ICN_EXPERIMENT_PARAMS[:metrics])

    for (constraint_name, constraint) in BENCHED_CONSTRAINTS
        @info "Learning error function for $(string(constraint_name))"

        for domain_size in ICN_EXPERIMENT_PARAMS[:domains_sizes]
            @info "Processing domain size: $domain_size"

            # Create domains using constraint-aware logic
            domains = create_domains_for_constraint(constraint_name, domain_size)

            # Get or generate search space using existing infrastructure
            X, X̅, has_data = search_space(
                domains, constraint;
                exploration_spaces=Dict{String,Dict{Symbol,Any}}(),
                parameters_explorations=1,
                settings=ExploreSettings(domains)
            )

            @info "Search space retrieved" solutions = length(X) non_solutions = length(X̅) cached = has_data

            # Convert to new Configuration format if we have data
            if !isempty(X) || !isempty(X̅)
                configurations = Set([
                    Solution.(collect.(X))...,
                    NonSolution.(collect.(X̅))...
                ])

                @info "Configurations created: $(length(configurations))"

                for optimizer in ICN_EXPERIMENT_PARAMS[:optimizers]
                    for metric in ICN_EXPERIMENT_PARAMS[:metrics]
                        experiment_count += 1
                        experiment_name = generate_experiment_name(
                            constraint_name, domain_size,
                            nameof(typeof(optimizer)), metric
                        )

                        # Check if results already exist using UUID-based system
                        results_dir = joinpath(datadir("icn_results"))
                        mkpath(results_dir)
                        metadata_file = joinpath(datadir(), "icn_metadata.csv")

                        # Generate the UUID that would be used for this experiment
                        optimizer_name = string(typeof(optimizer))
                        metric_name = string(metric)
                        test_uuid = get_icn_uuid(constraint_name, domain_size, optimizer_name, metric_name, "test")

                        # Check if this experiment already exists in metadata
                        experiment_exists = false
                        if isfile(metadata_file)
                            try
                                for line in eachline(metadata_file)
                                    if occursin(string(constraint_name), line) &&
                                       occursin(string(domain_size), line) &&
                                       occursin(optimizer_name, line) &&
                                       occursin(metric_name, line)
                                        experiment_exists = true
                                        break
                                    end
                                end
                            catch
                                # If there's an error reading metadata, continue with experiment
                            end
                        end

                        if experiment_exists
                            @info "Skipping experiment $experiment_count/$total_experiments (results exist): $experiment_name"
                            continue
                        end

                        @info "Running experiment $experiment_count/$total_experiments: $experiment_name"

                        # Create ICN for this constraint
                        icn = create_icn_for_constraint(constraint_name)

                        # Time the learning process
                        learning_time = @elapsed begin
                            # Learn using the new explore_learn function
                            learned_icn, success = explore_learn(
                                domains,
                                constraint.concept,
                                optimizer;
                                icn=icn,
                                configurations=configurations,
                                metric_function=[metric]
                            )

                            @info "Learning completed" success = success
                        end

                        # Prepare results dictionary
                        results = Dict{Any,Any}(
                            :experiment_name => experiment_name,
                            :constraint => string(constraint_name),
                            :domain_size => domain_size,
                            :optimizer => string(typeof(optimizer)),
                            :optimizer_params => Dict(
                                :global_iter => optimizer.global_iter,
                                :local_iter => optimizer.local_iter,
                                :pop_size => optimizer.pop_size,
                                :memoize => optimizer.memoize
                            ),
                            :metric => string(metric),
                            :success => success,
                            :has_cached_data => has_data,
                            :learning_time => learning_time,
                            :configurations_count => length(configurations),
                            :solutions_count => length(X),
                            :non_solutions_count => length(X̅),
                            :timestamp => string(now())
                        )

                        # Add ICN information if learning was successful
                        if success && !isnothing(learned_icn)
                            results[:icn_weights] = learned_icn.weights
                            results[:icn_parameters] = collect(learned_icn.parameters)
                            results[:icn_layers] = [string(typeof(layer)) for layer in learned_icn.layers]

                            # Test on different domain sizes for generalization
                            @info "Testing generalization on different domain sizes"
                            test_results = evaluate_icn_on_test_domains(
                                learned_icn, constraint, constraint_name, domain_size
                            )
                            results[:generalization_tests] = test_results
                        else
                            results[:error] = "Learning failed or returned nothing"
                        end

                        # Save results using UUID-based naming
                        save_path, param_uuid = save_experiment_results(results, constraint_name, domain_size, optimizer, metric)
                    end
                end
            else
                @warn "No search space data available for $(constraint_name) with domain size $domain_size"
            end
        end
    end

    @info "ICN learning experiments completed!"
    @info "Total experiments run: $experiment_count"
end

# SECTION - Execution
@info "ICN Learning Experiments Script Loaded"
@info "Available functions:"
@info "  - run_icn_experiments(): Run all ICN learning experiments"
@info "  - ICN_EXPERIMENT_PARAMS: View/modify experiment parameters"

# Uncomment the following line to run experiments automatically
run_icn_experiments()
