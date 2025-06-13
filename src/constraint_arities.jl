"""
    get_constraint_arity(constraint_name::Symbol)

Returns the expected arity (number of variables) for a given constraint.
This is used to ensure proper domain configuration during exploration.
"""
function get_constraint_arity(constraint_name::Symbol)
    # Define known constraint arities
    # Most constraints are flexible, but some have fixed requirements
    constraint_arities = Dict{Symbol,Int}(
        :dist_different => 4,  # Requires exactly 4 variables for Golomb ruler
        # Add other fixed-arity constraints here as needed
        # Most other constraints are flexible and can work with variable arity
    )

    # Return specific arity if known, otherwise use a default flexible approach
    return get(constraint_arities, constraint_name, nothing)
end

"""
    create_domains_for_constraint(constraint_name::Symbol, domain_size::Int)

Creates appropriate domains for a constraint based on its arity requirements.
- For fixed-arity constraints: creates the required number of variables
- For flexible constraints: uses domain_size for both range and number of variables
"""
function create_domains_for_constraint(constraint_name::Symbol, domain_size::Int)
    arity = get_constraint_arity(constraint_name)

    if arity !== nothing
        # Fixed arity constraint - create exactly the required number of variables
        return fill(domain(1:domain_size), arity)
    else
        # Flexible constraint - use domain_size for both range and number of variables
        return fill(domain(1:domain_size), domain_size)
    end
end
