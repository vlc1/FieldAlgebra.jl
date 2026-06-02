"""
    AbstractField{T}

Supertype of every symbolic grid expression. An `AbstractField{T}` behaves
like a dimension- and size-less array whose `eltype` is `T`: its grid rank
`N` is unknown until it is materialized against concrete arrays, but its
element type `T` (the value each cell will hold once materialized) is fixed
at construction. Field analogue of [`AbstractScalar`](@ref).
"""
abstract type AbstractField{T} end

Base.eltype(::Type{<:AbstractField{T}}) where {T} = T
Base.eltype(fd::AbstractField) = eltype(typeof(fd))

"""
    FieldSym{S, T}()

Placeholder for a discrete field named `S` (a `Symbol`) whose cells hold
values of the concrete type `T` (default `Float64`). Substituted with an
`AbstractArray` at `materialize` and indexed per cell. Field analogue of
[`ScalarSym`](@ref).
"""
struct FieldSym{S, T} <: AbstractField{T}

    function FieldSym{S, T}() where {S, T}
        _assert_concrete(:FieldSym, T)
        new{S, T}()
    end
end

FieldSym{S}() where {S} = FieldSym{S, Float64}()

"""
    @field name [T = Float64]

Bind `name` to `FieldSym{:name, T}()`. `@field x` ≡
`x = FieldSym{:x, Float64}()`; `@field x Float32` ≡
`x = FieldSym{:x, Float32}()`.
"""
macro field(name, T = :Float64)
    name isa Symbol ||
        throw(ArgumentError("@field expects a variable name, got `$(name)`"))
    :($(esc(name)) = $FieldSym{$(QuoteNode(name)), $(esc(T))}())
end

"""
    Fill{T} <: AbstractField{T}

Broadcast-to-grid bridge from scalar-land to field-land: wraps a single value
(a literal or an [`AbstractScalar`](@ref)) and presents it as a spatially-
invariant `AbstractField`.
"""
struct Fill{T,S<:AbstractScalar{T}} <: AbstractField{T}
    val::S

    function Fill{T}(val::S) where {T,S<:AbstractScalar{T}}
        _assert_concrete(:Fill, T)
        new{T,S}(val)
    end
end

Fill(val::AbstractScalar) = Fill{eltype(val)}(val)
Fill(val) = Fill(asscalar(val))

"""
    FieldZero{T} = Fill{ScalarZero{T}}
    FieldZero(T::Type) / FieldZero(x)

Type-level additive identity for [`AbstractField`](@ref), defined as the `Fill`
of a scalar-side [`ScalarZero`](@ref). The parameter `T` is bool-shaped (`Bool`
or `AbstractArray{Bool}`), mirroring `ScalarZero`'s discipline; the outer
constructors map any concrete value-space type to its bool shape, so
`FieldZero(Float64) === Fill(ScalarZero{Bool}())` and
`eltype(FieldZero(Float64)) === Bool` (the `Fill{<:AbstractScalar}`
specialization reports `eltype(ScalarZero{Bool}) === Bool`; the `Float64` is
the *input* the bool-shape ctor consumes, recovered by promotion in surrounding
arithmetic).

Materializes to a broadcast of `zero(T)` (Bool false, etc.) — promotion in
surrounding arithmetic recovers the cell type, exactly as for
[`ScalarZero`](@ref) in scalar-land.
"""
const FieldZero{T} = Fill{T, ScalarZero{T}}

FieldZero(T::Type)       = Fill(ScalarZero(T))
FieldZero(::T) where {T} = Fill(ScalarZero(T))
