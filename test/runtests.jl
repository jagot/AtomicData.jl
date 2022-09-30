using AtomicData
using Test
using Unitful
using UnitfulAtomic

@testset "Simple queries" begin
    for unit in [u"cm^-1", u"eV", u"Ry", u"hartree"]
        for el in ["He I", "He II", "W I", "Xe I", "Xe II"]
            df = get_nist_data(el, unit)
            # Slightly bogus checks
            @test size(df,1) > 0
            @test size(df,2) > 0
        end
    end
end

@testset "Caching mechanism" begin
    # We need to test that the caching mechanism respects the unit
    # choice, to not get wrong values, when subsequently querying with
    # different units. We get around this, by storing each unit choice
    # separately, which is slightly wasteful, but sure to work.
    for (unit,ref) in [(u"cm^-1",159_855.9743297u"cm^-1"),
                       (u"eV",19.81961484203u"eV"),
                       (u"Ry",1.456714822454u"Ry"),
                       (u"hartree",0.728357411225u"hartree")]
        df = get_nist_data("He I", unit)

        @test df.Configuration[2] == "1s.2s"
        E1s_2s = df.Level[2]
        @test E1s_2s ≈ ref
    end
end

@testset "LaTeX table generation" begin
    df = get_nist_data("He I", u"hartree")
    mktempdir() do dir
        filename = joinpath(dir, "HeI.tex")
        latex_table(filename, df, "He I")
        @test isfile(filename)
    end
end
