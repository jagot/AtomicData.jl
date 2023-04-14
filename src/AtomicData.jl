module AtomicData

using Unitful
using UnitfulAtomic

using Scratch

download_cache = ""

function __init__()
    global download_cache = @get_scratch!("AtomicData.jl")
end

using DataFrames
using CSV
using HTTP

function parse_J(J::AbstractVector)
    function parse_number(j::AbstractString)
        if occursin("/", j)
            //(parse.(Ref(Int), split(j, "/"))...)
        else
            parse(Int, j)
        end
    end
    map(J) do j
        if ismissing(j) || j == "---" || isempty(strip(j))
            missing
        elseif occursin(",", j)
            parse_number.(split(j, ","))
        else
            parse_number(j)
        end
    end
end

function parse_eng(E::AbstractVector{<:Union{Missing,AbstractString}}, unit)
    map(E) do EE
        if !ismissing(EE)
            for c in " ()[]"
                EE = replace(EE, c=>"")
            end
            isempty(strip(EE)) && return missing
            v = parse(Float64, EE)
            if unit == u"hartree"
                v*u"Ry" |> u"hartree"
            else
                v*unit
            end
        else
            EE
        end
    end |> Vector{Union{Missing,Quantity}}
end

function parse_eng(E::AbstractVector{<:Union{Missing,Real}}, unit)
    map(E) do EE
        if !ismissing(EE)
            if unit == u"hartree"
                EE*u"Ry" |> u"hartree"
            else
                EE*unit
            end
        else
            EE
        end
    end |> Vector{Union{Missing,Quantity}}
end

function get_nist_data(f::CSV.File, unit)
    df = DataFrame(f)

    mapping = Vector{Tuple{Int,Symbol,Function}}()
    for (i,k) in enumerate(propertynames(df))
        (k == :Prefix || k == :Suffix) && continue
        sk = string(k)
        (nk,fun) = if occursin(r"^J", sk)
            (:J, parse_J)
        elseif occursin(r"^Level", sk)
            (:Level, Base.Fix2(parse_eng, unit))
        elseif occursin(r"^Uncertainty", sk)
            (:Uncertainty, Base.Fix2(parse_eng, unit))
        else
            (k, identity)
        end
        push!(mapping, (i, nk, fun))
    end

    reduce(hcat, DataFrame(sym => fun(df[!, i])) for (i,sym,fun) in mapping)
end

function download(name, url, filename)
    req_body = HTTP.request("GET", url).body |> String
    occursin("Invalid element symbol", req_body) && error("Failed to retrieve atomic data for $(name)")
    @info "Downloading from" url filename
    open(filename, "w") do file
        write(file, req_body)
    end
end

function download_dataset(name, url, unit_id)
    filename = joinpath(download_cache, "$(name)-units=$(unit_id).csv")
    isfile(filename) || download(name, url, filename)
    filename
end

function get_nist_data(name::String, unit)
    units = Dict(u"cm"^(-1) => 0,
                 u"eV" => 1,
                 u"Ry" => 2,
                 u"hartree" => 2)
    unit_id = units[unit]
    http_name = replace(name, " " => "+")
    base_url = "https://physics.nist.gov/cgi-bin/ASD/energy1.pl"
    http_params = [
                  "de" => "0",
                  "spectrum" => http_name,
                  "units" => unit_id,
                  "upper_limit" => "",
                  "parity_limit" => "both",
                  "conf_limit" => "All",
                  "conf_limit_begin" => "",
                  "conf_limit_end" => "",
                  "term_limit" => "All",
                  "term_limit_begin" => "",
                  "term_limit_end" => "",
                  "J_limit" => "",
                  "format" => "3",
                  "output" => "0",
                  "page_size" => "15",
                  "multiplet_ordered" => "0",
                  "conf_out" => "on",
                  "term_out" => "on",
                  "level_out" => "on",
                  "unc_out" => "on",
                  "j_out" => "on",
                  "lande_out" => "on",
                  "perc_out" => "on",
                  "biblio" => "on",
                  "temp" => "",
                  "submit" => "Retrieve+Data",
    ]
    url = "$(base_url)?"*join(["$(k)=$(v)" for (k,v) in http_params], "&")

    get_nist_data(CSV.File(download_dataset(name, url, unit_id), delim='\t'), unit)
end

function clear_cache!()
    files = readdir(download_cache)
    @info "Deleting files in cache dir" files
    foreach(f -> rm(joinpath(download_cache, f)), files)
end

export get_nist_data

include("latex_tables.jl")

end # module
