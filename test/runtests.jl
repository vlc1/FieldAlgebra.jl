using StencilAlgebra
using ScalarAlgebra
using LinearAlgebra
using Test

@testset "StencilAlgebra" begin

    @testset "AbstractField eltype" begin
        @test eltype(AbstractField{Float64}) === Float64
        @test eltype(AbstractField{Float32}) === Float32
    end

    @testset "FieldSym" begin
        fd = @inferred FieldSym{:u}()
        @test fd isa FieldSym{:u, Float64}
        @test fd isa AbstractField{Float64}
        @test eltype(fd) === Float64

        fd32 = @inferred FieldSym{:u, Float32}()
        @test fd32 isa FieldSym{:u, Float32}
        @test eltype(fd32) === Float32

        @test_throws ArgumentError FieldSym{:u, AbstractFloat}()
    end

    @testset "@field macro" begin
        @field u
        @test u isa FieldSym{:u, Float64}

        @field v Float32
        @test v isa FieldSym{:v, Float32}
    end

    @testset "Fill from AbstractScalar" begin
        sc = ScalarConst(3.0)
        f = @inferred Fill(sc)
        @test f isa Fill{Float64, ScalarConst{Float64}}
        @test f isa AbstractField{Float64}
        @test eltype(f) === Float64
        @test f.val === sc

        sym = ScalarSym{:a}()
        fs = @inferred Fill(sym)
        @test fs isa Fill{Float64}
        @test eltype(fs) === Float64
    end

    @testset "Fill from plain value" begin
        f = Fill(2.0)
        @test f isa Fill{Float64}
        @test eltype(f) === Float64

        f32 = Fill(Float32(1.0))
        @test f32 isa Fill{Float32}
        @test eltype(f32) === Float32
    end

    @testset "Fill rejects abstract T" begin
        @test isconcretetype(Float64)
        @test !isconcretetype(AbstractFloat)
    end

    @testset "AbstractStencil" begin
        @test AbstractStencil{Float64} isa Type
        @test isabstracttype(AbstractStencil)
    end

    @testset "FieldZero" begin
        fz = FieldZero(Float64)
        @test fz isa Fill{Bool, ScalarZero{Bool}}
        @test fz isa FieldZero{Bool}
        @test fz isa AbstractField{Bool}
        @test eltype(fz) === Bool

        fz_val = FieldZero(1.0)
        @test fz_val isa FieldZero{Bool}

        fz32 = FieldZero(Float32)
        @test fz32 isa FieldZero{Bool}
    end

    @testset "FieldOne" begin
        fo = FieldOne(Float64)
        @test fo isa FieldOne{Bool}
        @test fo isa AbstractStencil{Bool}
        @test eltype(fo) === Bool

        fo_val = FieldOne(1.0)
        @test fo_val isa FieldOne{Bool}

        d = LinearAlgebra.diag(FieldOne(Float64))
        @test d isa Fill{Bool, ScalarOne{Bool}}
        @test d isa AbstractField{Bool}

        @test_throws ArgumentError FieldOne{Float64}()
    end

end
