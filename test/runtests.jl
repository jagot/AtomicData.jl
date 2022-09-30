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
