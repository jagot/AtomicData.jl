using Printf

Jstr(J::Rational) = isone(denominator(J)) ? "$(numerator(J))" : "$(numerator(J))/$(denominator(J))"
Jstr(J::Integer) = "$J"
Jstr(J::AbstractString) = J
Jstr(J::AbstractVector) = join(Jstr.(J), ",")

function term_str(term, J)
    i = findfirst(!isnumeric, term)
    mult = i > 1 ? parse(Int, term[1:i-1]) : 0
    isoddterm = term[end] == '*'
    termsym = isoddterm ? term[i:end-1] : term[i:end]

    terms = (i > 1 ? "\$^{$mult}\$$(termsym)" : termsym)*(isoddterm ? "\$^{\\textrm{o}}\$" : "")
    ismissing(J) ? terms : "$(terms)\$_{$(Jstr(J))}\$"
end

function cfg_str(cfg)
    subshells = map(split(cfg, ".")) do s
        if s[1] == '('
            i = findfirst(isequal('<'), s)
            term = strip(isnothing(i) ? s[2:end-1] : s[2:i-1])
            J = isnothing(i) ? missing : strip(s[i+1:end-2])
            "($(term_str(term, J)))"
        else
            i = findlast(!isnumeric, s)
            i < length(s) ? "$(s[1:i])\$^{$(s[i+1:end])}\$" : s
        end
    end
    join(subshells, " ")
end

limit_str(::Missing) = ""

function limit_str(cfg)
    m = match(r"(.*)\((.*)\)", cfg)

    if isnothing(m)
        cfg
    else
        a,b = split(m[2], " ")
        cfgs = cfg_str("$(a).($(b))")
        "$(m[1]) [$(cfg_str(cfgs))]"
    end
end

function latex_table(io::IO, data, name; offset=0u"eV")
    no_offset = iszero(NoUnits(offset/u"eV"))

    write(io, "\\section{$name}\n\\footnotesize\n")
    write(io, "\\tablehead{%\n")
    write(io, "\\textbf{Configuration}&\\textbf{Term}&\\textbf{Energy}")
    no_offset || write(io, "&\\textbf{Offset energy}")
    write(io, "\\\\\n\\hline\n")
    write(io, "}\n")
    write(io, "\\begin{supertabular}{l|l|l$(no_offset ? "" : "|l")}\n")

    cfgs = data[!,1]
    terms = data[!,2]
    Js = data[!,3]
    Es = data[!,4]
    for (cfg,term,J,E) in zip(cfgs,terms,Js,Es)
        Eoff = NoUnits((E + offset)/u"eV")
        ismissing(term) && continue
        if term == "Limit"
            write(io, "\\hline\n")
            write(io, @sprintf("%s & Limit & %08.5f eV", limit_str(cfg), NoUnits(E/u"eV")))
            no_offset || write(io, @sprintf("& %08.5f eV", Eoff))
            write(io, "\\\\\n")
            continue
        end
        write(io, @sprintf("%s & %s & %08.5f eV", cfg_str(cfg), term_str(term,J), NoUnits(E/u"eV")))
            no_offset || write(io, @sprintf("& %08.5f eV", Eoff))
        write(io, "\\\\\n")

    end

    write(io, "\\end{supertabular}\n\n")
end

function latex_table(fun::Function, filename::String)
    open(filename, "w") do file
        write(file, raw"""\documentclass[11pt]{article}
\usepackage[margin=2cm]{geometry}
\usepackage{multicol}
\usepackage{supertabular}
\usepackage{amsmath}
\usepackage{amssymb}
\begin{document}
\twocolumn

""")
        fun(file)
        write(file, "\n\n\\end{document}\n")
    end
end

latex_table(filename::String, data, name; kwargs...) =
    latex_table(file -> latex_table(file, data, name; kwargs...), filename)

export latex_table
