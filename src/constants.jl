const BENCHED_CONSTRAINTS = deepcopy(USUAL_CONSTRAINTS)

domain_from_size(size::Int) = map(_ -> domain(0:size-1), 1:size)

const USUAL_DOMAINS = [domain_from_size(size) for size in 3:5]
