# When running this file, make sure to set the `--code-coverage=all` command-line flag.

empty!(Base.DEPOT_PATH)

push!(Base.DEPOT_PATH, mktempdir(; cleanup = true))

# Base.runtests("all") # TODO: uncomment this line
Base.runtests("abstractarray") # TODO: delete this line
