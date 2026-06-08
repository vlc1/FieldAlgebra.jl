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

# Spatially-invariant operands fold via scalar `simplify`, for any fn. Because
# FieldZero <: Fill, this subsumes the all-invariant cases for every op; the
# per-op rules below only add the FieldZero shortcuts and the disambiguators
# that break dispatch ties with these generic methods.
_simplify_call(fn, (a,)::Tuple{Fill}) = Fill(simplify(fn(a.val)))
_simplify_call(fn, (a, b)::Tuple{Fill, Fill}) = Fill(simplify(fn(a.val, b.val)))

# Generic fallback: reconstruct with already-simplified args. Covers /,\,^ (no
# field identity beyond Fill-folding), unary math fns, and any other callable.
_simplify_call(fn, args) = FieldCall(fn, args)

# additive identities: x + 0 → x, 0 + x → x
_simplify_call(::typeof(+), args) = _simplify_add(args)
_simplify_call(::typeof(+), (a,)::Tuple{Fill}) = Fill(simplify(a.val))
_simplify_call(::typeof(+), (a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val + b.val))
_simplify_add((a, _)::Tuple{AbstractField, FieldZero}) = a
_simplify_add((_, b)::Tuple{FieldZero, AbstractField}) = b
_simplify_add((a, _)::Tuple{FieldZero, FieldZero}) = a
_simplify_add(args) = FieldCall(+, args)

# subtractive identities: -0 → 0, -(-a) → a, a - 0 → a, 0 - b → -b
_simplify_call(::typeof(-), args) = _simplify_sub(args)
_simplify_call(::typeof(-), (a,)::Tuple{Fill}) = Fill(simplify(-a.val))
_simplify_call(::typeof(-), (a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val - b.val))
_simplify_sub((a,)::Tuple{FieldCall{typeof(-), <:Tuple{AbstractField}}}) = only(a.args)
_simplify_sub((a, _)::Tuple{AbstractField, FieldZero}) = a
_simplify_sub((_, b)::Tuple{FieldZero, AbstractField}) = FieldCall(-, (b,))
_simplify_sub((a, _)::Tuple{FieldZero, FieldZero}) = a
_simplify_sub(args) = FieldCall(-, args)

# multiplicative identities: x * 0 → 0 (absorb)
_simplify_call(::typeof(*), args) = _simplify_mul(args)
_simplify_call(::typeof(*), (a,)::Tuple{Fill}) = Fill(simplify(a.val))
_simplify_call(::typeof(*), (a, b)::Tuple{Fill, Fill}) = Fill(simplify(a.val * b.val))
_simplify_mul((a, b)::Tuple{AbstractField, FieldZero}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))
_simplify_mul((a, b)::Tuple{FieldZero, AbstractField}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))
_simplify_mul((a, b)::Tuple{FieldZero, FieldZero}) =
    FieldZero(Base.promote_op(*, eltype(a), eltype(b)))
_simplify_mul(args) = FieldCall(*, args)

# Shifted: simplify the term, then distribute the shift over a FieldCall. The
# field analogue of scalar `_simplify_ref` / `_simplify_ref_call`. Zero-shift,
# Fill/FieldZero invariance, and Shifted-of-Shifted are folded by the Shifted
# constructor (see fields.jl).
simplify(fd::Shifted) = _simplify_shift(fd.shift, simplify(fd.term))

_simplify_shift(shift, term::FieldCall) =
    _simplify_call(term.fn, map(a -> _simplify_shift(shift, a), term.args))
_simplify_shift(shift, term::AbstractField) = Shifted(shift, term)
