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

function get_nist_levels(f::CSV.File, unit)
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

# function download(name, url, filename)
#     req_body = HTTP.request("GET", url).body |> String
#     occursin("Invalid element symbol", req_body) && error("Failed to retrieve atomic data for $(name)")
#     @info "Downloading from" url filename
#     open(filename, "w") do file
#         write(file, req_body)
#     end
# end

levels_filename(base_name) = joinpath(download_cache, "levels", base_name)

function download_levels_dataset(url, base_name)
    filename = levels_filename(base_name)
    dir = dirname(filename)
    isdir(dir) || mkpath(dir)

    if !isfile(filename)
        download_many([url], [filename], download_successful = req_body -> begin
                          !occursin("Invalid element symbol", req_body)
                      end)
    end
    filename
end

function nist_levels_url(Z::Integer, Q::Integer, unit)
    units = Dict(u"cm"^(-1) => 0,
                 u"eV" => 1,
                 u"Ry" => 2,
                 u"hartree" => 2)
    unit_id = units[unit]
    name = "Z=$(Z) $(Q)"
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
    base_name = "$(Z)/$(Q)-units=$(unit_id).csv"
    url,base_name
end

functio

function get_nist_levels(name::String, unit)
    Z,Q = parse_element(name)
    url,base_name = nist_levels_url(Z, Q, unit)
    get_nist_levels(CSV.File(download_levels_dataset(url, base_name), delim='\t'), unit)
end

function get_all_nist_levels(unit)
    urls = String[]
    filenames = String[]
    for Q = 0:118
        for Z = 1:118
            Q ≥ Z && continue
            url,base_name = nist_levels_url(Z, Q, unit)
            filename = levels_filename(base_name)

            push!(urls, url)
            push!(filenames, filename)
        end
    end

    download_many(urls, filenames, download_successful = req_body -> begin
                      !occursin("Invalid element symbol", req_body)
                  end)
end

export get_nist_levels
