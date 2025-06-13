function __init__()
    # If the UUID is not set in the environment ...
    if !haskey(ENV, "JULIACONSTRAINTS_UUID")
        @info "JULIACONSTRAINTS_UUID not set in the environment. Looking for it ..."
        # ... read it from the file ...
        path = joinpath(Base.Sys.DEPOT_PATH[1], "juliaconstraints", "uuid")
        ENV["JULIACONSTRAINTS_UUID"] = if isfile(path)
            @info "... found it in $path."
            UUID(read(path, UInt128))
        else # or generate a new one and write it to the file
            u = uuid4()
            str = """
            	... not found. Generating a new one and writing it to $path.
            	Please set it in the environment, `ENV["JULIACONSTRAINTS_UUID"] = "your_UUID"`, if you want to use a specific one.
            	\t`ConstraintLearningBenchmarks.get_system_uuid()`: $u
            """
            @warn str
            mkpath(dirname(path))
            open(path, "w") do f
                write(f, u.value)
            end
            u
        end
    end
end
