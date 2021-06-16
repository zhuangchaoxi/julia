empty!(Base.DEPOT_PATH)

push!(Base.DEPOT_PATH, mktempdir(; cleanup = true))

import Pkg

Pkg.update() # this ensures that we download the General registry, which we only need to do once

const stdlib_dir = joinpath(pwd(), "stdlib")

function get_stdlib_names(stdlib_dir::AbstractString)
    stdlib_names = String[]
    for x in readdir(stdlib_dir)
        if isfile(joinpath(stdlib_dir, x, "Project.toml"))
            push!(stdlib_names, x)
        end
    end
    unique!(stdlib_names)
    sort!(stdlib_names)
    return stdlib_names
end

const stdlib_names = get_stdlib_names(stdlib_dir)

@info "# Begin list of stdlibs"
for (i, x) in enumerate(stdlib_names)
    @info "$(i). $(x)"
end
@info "# End list of stdlibs"

# for stdlib_name in stdlib_names # TODO: uncomment this line
for stdlib_name in ["Base64"] # TODO: delete this line
    Pkg.activate(joinpath(stdlib_dir, stdlib_name))
    Pkg.instantiate()
    Pkg.precompile()
    Pkg.status()
    Pkg.test(; coverage = true)
end
