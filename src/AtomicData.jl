module AtomicData

module AtomicUnits
using Unitful
@unit Ry "Ry" Rydberg 13.605_693_009u"eV" false;
@unit Ha "Ha" Hartree 27.211_386_02u"eV" false;

const _local_Unitful_basefactors = Unitful.basefactors
function __init__()
    # To use the atomic units outside this module
    merge!(Unitful.basefactors, _local_Unitful_basefactors)
    Unitful.register(AtomicUnits)
end
Unitful.register(AtomicUnits)
end # module AtomicUnits

using DataFrames
using CSV
using Unitful
using HTTP

function parse_J(J::Vector)
    function parse_number(j::AbstractString)
        if occursin("/", j)
            //(parse.(Ref(Int), split(j, "/"))...)
        else
            parse(Int, j)
        end
    end
    map(J) do j
        if ismissing(j) || j == "---"
            missing
        elseif occursin(",", j)
            parse_number.(split(j, ","))
        else
            parse_number(j)
        end
    end
end

function parse_eng(E::Vector{Union{Missing,String}}, unit)
    map(E) do EE
        if !ismissing(EE)
            for c in " ()[]"
                EE = replace(EE, c=>"")
            end
            v = parse(Float64, EE)
            if unit == u"Ha"
                v*u"Ry" |> u"Ha"
            else
                v*unit
            end
        else
            EE
        end
    end |> Vector{Union{Missing,Quantity}}
end

function parse_eng(E::Vector{Union{Missing,T}}, unit) where {T<:Real}
    map(E) do EE
        if !ismissing(EE)
            if unit == u"Ha"
                EE*u"Ry" |> u"Ha"
            else
                EE*unit
            end
        else
            EE
        end
    end |> Vector{Union{Missing,Quantity}}
end

function get_nist_data(io::IO, unit)
    df = io |> f -> CSV.File(f, delim='\t') |> DataFrame

    [df[1:2] DataFrame(J = parse_J(df[3]), Level = parse_eng(df[4], unit), Uncertainty = parse_eng(df[5], unit)) df[6:end]]
end

function get_nist_data(name::String, unit)
    units = Dict(u"cm"^(-1) => 0,
                 u"eV" => 1,
                 u"Ry" => 2,
                 u"Ha" => 2
                 )
    http_name = replace(name, " " => "+")
    url = "https://physics.nist.gov/cgi-bin/ASD/energy1.pl?encodedlist=XXT2&de=0&spectrum=$(http_name)&units=$(units[unit])&upper_limit=&parity_limit=both&conf_limit=All&conf_limit_begin=&conf_limit_end=&term_limit=All&term_limit_begin=&term_limit_end=&J_limit=&format=3&output=0&page_size=15&multiplet_ordered=0&conf_out=on&term_out=on&level_out=on&unc_out=on&j_out=on&lande_out=on&perc_out=on&biblio=on&temp=&submit=Retrieve+Data"

    req_body = HTTP.request("GET", url).body |> String
    occursin("Invalid element symbol", req_body) && error("Failed to retrieve atomic data for $(name)")
    req_body |> IOBuffer |> io -> get_nist_data(io, unit)
end

export get_nist_data

end # module
