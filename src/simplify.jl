# `simplify` is owned by AlgebraCore; these methods extend it for AbstractField.
# Structural simplification of a field expression tree (post-order, single pass),
# mirroring ScalarAlgebra/src/simplify.jl for AbstractScalar. The helper names
# (`_simplify_args`, `_simplify_call`, ...) are private to FieldAlgebra.
simplify(fd::AbstractField) = fd

# Fill is spatially invariant: fold the wrapped scalar via scalar `simplify`.
# Keeps FieldZero a FieldZero (simplify(ScalarZero) === ScalarZero).
simplify(fd::Fill) = Fill(simplify(fd.val))

# FieldCall
_simplify_args(::Tuple{}) = ()
_simplify_args((x, xs...)::Tuple{AbstractField, Vararg}) =
    (simplify(x), _simplify_args(xs)...)

simplify(fd::FieldCall) = _simplify_call(fd.fn, _simplify_args(fd.args))

# additive identities
_simplify_call(::typeof(+), args) = _simplify_add(args)

# both invariant → fold via scalar `simplify`
_simplify_add((a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val + b.val))

# zero identity against a non-invariant field
_simplify_add((a, _)::Tuple{AbstractField, FieldZero}) = a
_simplify_add((_, b)::Tuple{FieldZero, AbstractField}) = b

# tiebreakers (FieldZero <: Fill, so these corners are otherwise ambiguous)
_simplify_add((a, b)::Tuple{Fill, FieldZero}) = Fill(simplify(a.val + b.val))
_simplify_add((a, b)::Tuple{FieldZero, Fill}) = Fill(simplify(a.val + b.val))
_simplify_add((a, b)::Tuple{FieldZero, FieldZero}) = Fill(simplify(a.val + b.val))

# fallback: rebuild the node directly (operators throw for two-field *,/,\,^)
_simplify_add(args) = FieldCall(+, args)

# subtractive identities
_simplify_call(::typeof(-), args) = _simplify_sub(args)

# unary
_simplify_sub((a,)::Tuple{FieldZero}) = a                       # -0 → 0
_simplify_sub((a,)::Tuple{Fill}) = Fill(simplify(-a.val))
_simplify_sub((a,)::Tuple{FieldCall{typeof(-), <:Tuple{AbstractField}}}) =
    only(a.args)                                                # -(-a) → a
_simplify_sub((a,)::Tuple{AbstractField}) = FieldCall(-, (a,))

# binary
_simplify_sub((a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val - b.val))
_simplify_sub((a, _)::Tuple{AbstractField, FieldZero}) = a      # a - 0 → a
_simplify_sub((_, b)::Tuple{FieldZero, AbstractField}) = FieldCall(-, (b,))  # 0 - b → -b
_simplify_sub((a, b)::Tuple{Fill, FieldZero}) = Fill(simplify(a.val - b.val))
_simplify_sub((a, b)::Tuple{FieldZero, Fill}) = Fill(simplify(a.val - b.val))
_simplify_sub((a, b)::Tuple{FieldZero, FieldZero}) = Fill(simplify(a.val - b.val))
_simplify_sub(args) = FieldCall(-, args)

# multiplicative identities (FieldCall(*) arises from broadcast `.*` or field*scalar)
_simplify_call(::typeof(*), args) = _simplify_mul(args)

_simplify_mul((a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val * b.val))

# multiplication by zero absorbs (mirrors scalar mul-by-zero)
_simplify_mul((a, b)::Tuple{AbstractField, FieldZero}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))
_simplify_mul((a, b)::Tuple{FieldZero, AbstractField}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))
_simplify_mul((a, b)::Tuple{Fill, FieldZero}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))
_simplify_mul((a, b)::Tuple{FieldZero, Fill}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))
_simplify_mul((a, b)::Tuple{FieldZero, FieldZero}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))

_simplify_mul(args) = FieldCall(*, args)

# division / exponentiation: fold invariant operands only (no field one-identity)
_simplify_call(::typeof(/), args) = _simplify_rdiv(args)
_simplify_rdiv((a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val / b.val))
_simplify_rdiv(args) = FieldCall(/, args)

_simplify_call(::typeof(\), args) = _simplify_ldiv(args)
_simplify_ldiv((a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val \ b.val))
_simplify_ldiv(args) = FieldCall(\, args)

_simplify_call(::typeof(^), args) = _simplify_pow(args)
_simplify_pow((a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val ^ b.val))
_simplify_pow(args) = FieldCall(^, args)

# Generic fallback: reconstruct with already-simplified args (unary math fns, etc.)
_simplify_call(fn, args) = FieldCall(fn, args)

# Shifted: simplify the term, then distribute the shift over a FieldCall. The
# field analogue of scalar `_simplify_ref` / `_simplify_ref_call`. Zero-shift,
# Fill/FieldZero invariance, and Shifted-of-Shifted are folded by the Shifted
# constructor (see fields.jl).
simplify(fd::Shifted) = _simplify_shift(fd.shift, simplify(fd.term))

_simplify_shift(shift, term::FieldCall) =
    _simplify_call(term.fn, map(a -> _simplify_shift(shift, a), term.args))
_simplify_shift(shift, term::AbstractField) = Shifted(shift, term)
