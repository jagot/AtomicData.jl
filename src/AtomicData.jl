module AtomicData

using Unitful
using UnitfulAtomic

using Scratch

download_cache = ""

using DataFrames
using CSV
using HTTP

using Logging
using ProgressLogging

function __init__()
    global download_cache = @get_scratch!("AtomicData.jl")
end

function clear_cache!()
    files = readdir(download_cache)
    @info "Deleting files in cache dir" files
    foreach(f -> rm(joinpath(download_cache, f)), files)
end

include("download.jl")
include("levels.jl")
include("latex_tables.jl")

end # module
