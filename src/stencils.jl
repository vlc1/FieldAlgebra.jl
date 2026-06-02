"""
    AbstractStencil{T}

Supertype for linear transformations of `AbstractField`s.
Applied by invoking `*`.
"""
abstract type AbstractStencil{T} end

Base.eltype(::Type{<:AbstractStencil{T}}) where {T} = T
Base.eltype(st::AbstractStencil) = eltype(typeof(st))

"""
    FieldOne{T}()
    FieldOne(U::Type) / FieldOne(x)

Type-level multiplicative identity for [`AbstractField`](@ref): the
pointwise-side analogue of scalar-side [`ScalarOne`](@ref), now reified as a
*stencil* (so it can serve as the neutral element of `*(stencil, field)`.

The parameter `T` is **bool-shaped** (`Bool` or `AbstractArray{Bool}`),
mirroring `ScalarOne`'s discipline so that promotion in surrounding arithmetic
recovers the value type without pinning a Stencil's coefficient eltype. The
second parameter `U` is the *value space* (e.g. `Float64`, `SMatrix{N,N,F}`)
recovered at materialize time via `one(U)`.

The outer constructors map any concrete value-space type `U` to its bool-
shape `T = _to_bool_shape(_unity_space(U))`, so
`FieldOne(Float64) === FieldOne{Bool, Float64}()` and
`eltype(FieldOne(Float64)) === Bool`. Materializes to `one(U)` —
e.g. `1.0` for `U = Float64`.

See also [`FieldZero`](@ref) for the additive identity.
"""
struct FieldOne{T} <: AbstractStencil{T}

    function FieldOne{T}() where {T}
        _assert_bool_shape(:FieldOne, T)
        applicable(one, T) || throw(ArgumentError(
            "FieldOne{T} requires `one(T)` to be defined (a " *
            "square-scalar shape); got T=$T"))
        new{T}()
    end
end

FieldOne(::Type{U}) where {U} =
       FieldOne{_to_bool_shape(_unity_space(U))}()
FieldOne(::U) where {U} = FieldOne(U)

LinearAlgebra.diag(::FieldOne{T}) where {T} = Fill(ScalarOne(T))
