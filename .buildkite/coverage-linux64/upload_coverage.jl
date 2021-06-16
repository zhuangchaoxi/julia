empty!(Base.DEPOT_PATH)

push!(Base.DEPOT_PATH, mktempdir(; cleanup = true))

import Pkg

Pkg.update() # this ensures that we download the General registry, which we only need to do once

Pkg.add(; name = "Coverage", uuid = "a2441757-f6aa-5fb2-8edb-039e3f45d037", version = "1")

Pkg.precompile()

import Coverage

# `fcs_base`, `fcs_stdlib`, and `fcs` are each a `Vector{Coverage.FileCoverage}`
const fcs_base = Coverage.process_folder("base");
const fcs_stdlib = Coverage.process_folder("stdlib");
const fcs = vcat(fcs_base, fcs_stdlib);

# Exclude external stdlibs (stdlibs that live in external repos) from coverage.
const get_external_stdlib_prefixes = function (stdlib_dir)
    filename_list = filter(x -> isfile(joinpath(stdlib_dir, x)), readdir(stdlib_dir))

    # find all of the files like `Pkg.version`, `Statistics.version`, etc.
    regex_matches_or_nothing = match.(Ref(r"^([\w].*?)\.version$"), filename_list)
    regex_matches = filter(x -> x !== nothing, regex_matches_or_nothing)

    # get the names of the external stdlibs, like `Pkg`, `Statistics`, etc.
    external_stdlib_names = only.(regex_matches)
    prefixes_1 = joinpath.(Ref(stdlib_dir), external_stdlib_names, Ref(""))
    prefixes_2 = joinpath.(Ref(stdlib_dir), string.(external_stdlib_names, Ref("-")))

    prefixes = vcat(prefixes_1, prefixes_2)
    unique!(prefixes)
    sort!(prefixes)

    # example of what `prefixes` might look like:
    # 4-element Vector{String}:
    # "stdlib/Pkg-"
    # "stdlib/Pkg/"
    # "stdlib/Statistics-"
    # "stdlib/Statistics/"
    return prefixes
end
const external_stdlib_prefixes = get_external_stdlib_prefixes("stdlib")
@info "# Begin list of external stdlibs"
for (i, x) in enumerate(external_stdlib_prefixes)
    @info "$(i). $(x)"
end
@info "# End list of external stdlibs"
@info "" length(fcs)
filter!(fcs) do fc
    all(x -> !startswith(fc.filename, x), external_stdlib_prefixes)
end;
@info "" length(fcs)

@info "This logging message is to confirm that everything prior to the uploads was a success"

# In order to upload to Codecov, you need to have the `CODECOV_TOKEN` environment variable defined
# Coverage.Codecov.submit_local(fcs)
