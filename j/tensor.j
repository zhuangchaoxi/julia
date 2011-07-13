## tensor.j : Functions over tensors, not specialized to specific implementation

## Type aliases for convenience ##

typealias Vector{T} Tensor{T,1}
typealias Matrix{T} Tensor{T,2}
typealias DenseVector{T} Array{T,1}
typealias DenseMatrix{T} Array{T,2}
typealias DenseVecOrMat{T} Union(DenseVector{T}, DenseMatrix{T})

typealias Indices Union(Index, Vector{Index})
typealias Region Union(Size,Dims)

## Basic functions ##

size(t::Tensor, d) = size(t)[d]
ndims{T,n}(::Tensor{T,n}) = n
numel(t::Tensor) = prod(size(t))
length(v::Vector) = numel(v)
length(t::Tensor) = error("length not defined for ", typeof(t))
nnz(a::Tensor) = (n = 0; for i=1:numel(a); n += a[i] != 0 ? 1 : 0; end; n)
nnz(a::Tensor{Bool}) = (n = 0; for i=1:numel(a); n += a[i] == true ? 1 : 0; end; n)

## Constructors ##

# default arguments to similar()
similar{T}(a::Tensor{T})                      = similar(a, T, size(a))
similar   (a::Tensor, T::Type)                = similar(a, T, size(a))
similar{T}(a::Tensor{T}, dims::Dims)          = similar(a, T, dims)
similar{T}(a::Tensor{T}, dims::Size...)       = similar(a, T, dims)
similar   (a::Tensor, T::Type, dims::Size...) = similar(a, T, dims)

reshape(a::Tensor, dims::Dims) = (b = similar(a, dims);
                                  for i=1:numel(a); b[i] = a[i]; end;
                                  b)
reshape(a::Tensor, dims::Size...) = reshape(a, dims)

function fill(A::Tensor, x)
    for i = 1:numel(A)
        A[i] = x
    end
    return A
end

function copy_to(dest::Tensor, src::Tensor)
    for i=1:numel(src)
        dest[i] = copy(src[i])
    end
    return dest
end

copy(a::Tensor) = copy_to(similar(a), a)

eye(n::Size) = eye(n, n)
eye(m::Size, n::Size) = (a = zeros(m,n);
                         for i=1:min(m,n); a[i,i]=1; end;
                         a)
one{T}(x::Tensor{T,2}) = (m=size(x,1); n=size(x,2);
                          a = zeros(T,size(x));
                          for i=1:min(m,n); a[i,i]=1; end;
                          a)
zero{T}(x::Tensor{T,2}) = zeros(T,size(x))

linspace(start::Real, stop::Real, stride::Real) =
    ((start, stop, stride) = promote(start, stop, stride);
     [ i | i=start:stride:stop ])

linspace(start::Real, stop::Real) =
    ((start, stop) = promote(start, stop);
     [ i | i=start:stop ])

## Unary operators ##

conj{T <: Real}(x::Tensor{T}) = x
real{T <: Real}(x::Tensor{T}) = x
imag{T <: Real}(x::Tensor{T}) = zero(x)

macro unary_op(f)
    quote

        function ($f)(A::Tensor)
            F = similar(A)
            for i=1:numel(A)
                F[i] = ($f)(A[i])
            end
            return F
        end

    end # quote
end # macro

@unary_op (-)
@unary_op (~)
@unary_op (conj)

macro unary_c2r_op(f)
    quote

        function ($f){T}(A::Tensor{T})
            S = typeof(($f)(zero(T)))
            F = similar(A, S)
            for i=1:numel(A)
                F[i] = ($f)(A[i])
            end
            return F
        end

    end # quote
end # macro

@unary_c2r_op (real)
@unary_c2r_op (imag)

+{T<:Number}(x::Tensor{T}) = x
*{T<:Number}(x::Tensor{T}) = x

function !(A::Tensor{Bool})
    F = similar(A)
    for i=1:numel(A)
        F[i] = !A[i]
    end
    return F
end

## Binary arithmetic operators ##

*(A::Number, B::Tensor) = A .* B
*(A::Tensor, B::Number) = A .* B

./(x::Tensor, y::Tensor) = reshape( [ x[i] ./ y[i] | i=1:numel(x) ], size(x) )
./(x::Number, y::Tensor) = reshape( [ x    ./ y[i] | i=1:numel(y) ], size(y) )
./(x::Tensor, y::Number) = reshape( [ x[i] ./ y    | i=1:numel(x) ], size(x) )

/(A::Number, B::Tensor) = A ./ B
/(A::Tensor, B::Number) = A ./ B

.\(x::Tensor, y::Tensor) = reshape( [ x[i] .\ y[i] | i=1:numel(x) ], size(x) )
.\(x::Number, y::Tensor) = reshape( [ x    .\ y[i] | i=1:numel(y) ], size(y) )
.\(x::Tensor, y::Number) = reshape( [ x[i] .\ y    | i=1:numel(x) ], size(x) )

\(A::Number, B::Tensor) = A .\ B
\(A::Tensor, B::Number) = A .\ B

macro binary_arithmetic_op(f)
    quote

        function ($f){S,T}(A::Tensor{S}, B::Tensor{T})
           F = similar(A, promote_type(S,T))
           for i=1:numel(A)
              F[i] = ($f)(A[i], B[i])
           end
           return F
        end
        function ($f){T}(A::Number, B::Tensor{T})
           F = similar(B, promote_type(typeof(A),T))
           for i=1:numel(B)
              F[i] = ($f)(A, B[i])
           end
           return F
        end
        function ($f){T}(A::Tensor{T}, B::Number)
           F = similar(A, promote_type(T,typeof(B)))
           for i=1:numel(A)
              F[i] = ($f)(A[i], B)
           end
           return F
        end

    end # quote
end # macro

@binary_arithmetic_op (+)
@binary_arithmetic_op (-)
@binary_arithmetic_op (.*)
@binary_arithmetic_op (.^)

## promotion to complex ##

function complex{S<:Real,T<:Real}(A::Tensor{S}, B::Tensor{T})
    F = similar(A, typeof(complex(zero(S),zero(T))))
    for i=1:numel(A)
        F[i] = complex(A[i], B[i])
    end
    return F
end

function complex{T<:Real}(A::Real, B::Tensor{T})
    F = similar(B, typeof(complex(A,zero(T))))
    for i=1:numel(B)
        F[i] = complex(A, B[i])
    end
    return F
end

function complex{T<:Real}(A::Tensor{T}, B::Real)
    F = similar(A, typeof(complex(zero(T),B)))
    for i=1:numel(A)
        F[i] = complex(A[i], B)
    end
    return F
end

function complex{T<:Real}(A::Tensor{T})
    z = zero(T)
    F = similar(A, typeof(complex(z,z)))
    for i=1:numel(A)
        F[i] = complex(A[i], z)
    end
    return F
end

## Binary comparison operators ##

macro binary_comparison_op(f)
    quote

        function ($f)(A::Tensor, B::Tensor)
           F = similar(A, Bool)
           for i=1:numel(A)
              F[i] = ($f)(A[i], B[i])
           end
           return F
        end
        function ($f)(A::Number, B::Tensor)
           F = similar(B, Bool)
           for i=1:numel(B)
              F[i] = ($f)(A, B[i])
           end
           return F
        end
        function ($f)(A::Tensor, B::Number)
           F = similar(A, Bool)
           for i=1:numel(A)
              F[i] = ($f)(A[i], B)
           end
           return F
        end
    end
end

@binary_comparison_op (==)
@binary_comparison_op (!=)
@binary_comparison_op (<)
@binary_comparison_op (>)
@binary_comparison_op (<=)
@binary_comparison_op (>=)

## Binary boolean operators ##

macro binary_boolean_op(f)
    quote

        function ($f)(A::Tensor{Bool}, B::Tensor{Bool})
           F = similar(A, Bool)
           for i=1:numel(A)
              F[i] = ($f)(A[i], B[i])
           end
           return F
        end
        function ($f)(A::Bool, B::Tensor{Bool})
           F = similar(B, Bool)
           for i=1:numel(B)
              F[i] = ($f)(A, B[i])
           end
           return F
        end
        function ($f)(A::Tensor{Bool}, B::Bool)
           F = similar(A, Bool)
           for i=1:numel(A)
              F[i] = ($f)(A[i], B)
           end
           return F
        end

    end # quote
end # macro

@binary_boolean_op (&)
@binary_boolean_op (|)
@binary_boolean_op ($)

## code generator for specializing on the number of dimensions ##

function make_loop_nest(vars, ranges, body)
    expr = body
    for i=1:length(vars)
        v = vars[i]
        r = ranges[i]
        expr = quote
            for ($v) = ($r)
                $expr
            end
        end
    end
    expr
end

function gen_cartesian_map(cache, genbody, dims, exargnames, exargs...)
    N = length(dims)
    if !has(cache,N)
        dimargnames = { gensym() | i=1:N }
        ivars = { gensym() | i=1:N }
        body = genbody(ivars)
        fexpr =
        quote
            let _dummy_=nothing
                local _F_
                function _F_($(dimargnames...), $(exargnames...))
                    $make_loop_nest(ivars, dimargnames, body)
                end
                _F_
            end
        end
        f = eval(fexpr)
        cache[N] = f
    else
        f = cache[N]
    end
    return f(dims..., exargs...)
end


## Indexing: ref ##

ref(t::Tensor) = t
ref(t::Tensor, r::Real...) = ref(t,map(x->int32(round(x)),r)...)

ref(A::Vector, I::Vector{Index}) = [ A[i] | i = I ]
ref(A::Tensor{Any,1}, I::Vector{Index}) = { A[i] | i = I }

ref(A::Matrix, I::Index, J::Vector{Index})         = [ A[i,j] | i = I, j = J ]
ref(A::Matrix, I::Vector{Index}, J::Index)         = [ A[i,j] | i = I, j = J ]
ref(A::Matrix, I::Vector{Index}, J::Vector{Index}) = [ A[i,j] | i = I, j = J ]

function ref(A::Tensor, i0::Index, i1::Index)
    A[i0 + size(A,1)*(i1-1)]
end

function ref(A::Tensor, i0::Index, i1::Index, i2::Index)
    A[i0 + size(A,1)*((i1-1) + size(A,2)*(i2-1))]
end

function ref(A::Tensor, i0::Index, i1::Index, i2::Index, i3::Index)
    A[i0 + size(A,1)*((i1-1) + size(A,2)*((i2-1) + size(A,3)*(i3-1)))]
end

function ref(A::Tensor, I::Index...)
    dims = size(A)
    ndims = length(I)

    index = I[1]
    stride = 1
    for k=2:ndims
        stride = stride * dims[k-1]
        index += (I[k]-1) * stride
    end

    return A[index]
end

let ref_cache = nothing
global ref
function ref(A::Tensor, I::Indices...)
    X = similar(A, map(length, I))
    storeind = 1

    if is(ref_cache,nothing)
        ref_cache = HashTable()
    end
    gen_cartesian_map(ref_cache, ivars->:(X[storeind] = A[$(ivars...)];
                                          storeind += 1),
                      I,
                      {:A, :X, :storeind},
                      A, X, storeind)
    return X
end
end

## Indexing: assign ##

# 1-d indexing is assumed defined on subtypes
assign(t::Tensor, x, i::Index) =
    error("assign not defined for ",typeof(t))
assign(t::Tensor, x::Tensor, i::Index) =
    error("assign not defined for ",typeof(t))

assign(t::Tensor, x, r::Real...) = (t[map(x->int32(round(x)),r)...] = x)

function assign(A::Vector, x, I::Vector{Index})
    for i=I
        A[i] = x
    end
    return A
end

function assign(A::Vector, X::Tensor, I::Vector{Index})
    for i=1:length(I)
        A[I[i]] = X[i]
    end
    return A
end

assign(A::Matrix, x, i::Index, j::Index) = (A[(j-1)*size(A,1) + i] = x)
assign(A::Matrix, x::Tensor, i::Index, j::Index) = (A[(j-1)*size(A,1) + i] = x)

function assign(A::Matrix, x, I::Indices, J::Indices)
    for j=J, i=I
        A[i,j] = x
    end
    return A
end

function assign(A::Matrix, X::Tensor, I::Indices, J::Indices)
    count = 1
    for j=J, i=I
        A[i,j] = X[count]
        count += 1
    end
    return A
end

assign(A::Tensor, x, I0::Index, I::Index...) = assign_scalarND(A,x,I0,I...)
assign(A::Tensor, x::Tensor, I0::Index, I::Index...) =
    assign_scalarND(A,x,I0,I...)

assign(A::Tensor, x::Tensor, i0::Index, i1::Index) =
    A[i0 + size(A,1)*(i1-1)] = x
assign(A::Tensor, x, i0::Index, i1::Index) = A[i0 + size(A,1)*(i1-1)] = x

assign(A::Tensor, x, i0::Index, i1::Index, i2::Index) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*(i2-1))] = x
assign(A::Tensor, x::Tensor, i0::Index, i1::Index, i2::Index) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*(i2-1))] = x

assign(A::Tensor, x, i0::Index, i1::Index, i2::Index, i3::Index) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*((i2-1) + size(A,3)*(i3-1)))] = x
assign(A::Tensor, x::Tensor, i0::Index, i1::Index, i2::Index, i3::Index) =
    A[i0 + size(A,1)*((i1-1) + size(A,2)*((i2-1) + size(A,3)*(i3-1)))] = x

function assign_scalarND(A, x, I0, I...)
    dims = size(A)
    index = I0
    stride = 1
    for k=1:length(I)
        stride = stride * dims[k]
        index += (I[k]-1) * stride
    end
    A[index] = x
    return A
end

let assign_cache = nothing
global assign
function assign(A::Tensor, x, I0::Indices, I::Indices...)
    if is(assign_cache,nothing)
        assign_cache = HashTable()
    end
    gen_cartesian_map(assign_cache, ivars->:(A[$(ivars...)] = x),
                      append(tuple(I0), I),
                      {:A, :x},
                      A, x)
    return A
end
end

let assign_cache = nothing
global assign
function assign(A::Tensor, X::Tensor, I0::Indices, I::Indices...)
    refind = 1

    if is(assign_cache,nothing)
        assign_cache = HashTable()
    end
    gen_cartesian_map(assign_cache, ivars->:(A[$(ivars...)] = X[refind];
                                             refind += 1),
                      append(tuple(I0), I),
                      {:A, :X, :refind},
                      A, X, refind)
    return A
end
end

## Reductions ##

function contains(itr, x)
    for y=itr
        if y==x
            return true
        end
    end
    return false
end

contains(s::Number, n::Int) = (s == n)

areduce{T}(f::Function, A::Tensor{T}, region::Region) = areduce(f,A,region,T)

let areduce_cache = nothing
# generate the body of the N-d loop to compute a reduction
function gen_areduce_core(ivars, f)
    n = length(ivars)
    # limits and vars for reduction loop
    lo    = { gensym() | i=1:n }
    hi    = { gensym() | i=1:n }
    rvars = { gensym() | i=1:n }
    setlims = { quote
        # each dim of reduction is either 1:sizeA or ivar:ivar
        if contains(region,$i)
            $lo[i] = 1
            $hi[i] = size(A,$i)
        else
            $lo[i] = $hi[i] = $ivars[i]
        end
               end | i=1:n }
    rranges = { :( ($lo[i]):($hi[i]) ) | i=1:n }  # lo:hi for all dims
    quote
        _tot = ($f)()
        $(setlims...)
        $make_loop_nest(rvars, rranges,
                        :(_tot = ($f)(_tot, A[$(rvars...)])))
        R[$(ivars...)] = _tot
    end
end

global areduce
function areduce(f::Function, A::Tensor, region::Region, RType::Type)
    dimsA = size(A)
    ndimsA = length(dimsA)
    dimsR = ntuple(ndimsA, i->(contains(region, i) ? 1 : dimsA[i]))
    R = similar(A, RType, dimsR)
    
    if is(areduce_cache,nothing)
        areduce_cache = HashTable()
    end
    gen_cartesian_map(areduce_cache, iv->gen_areduce_core(iv,:f),
                      ntuple(ndimsA, i->(Range1(1,dimsR[i]))),
                      {:f, :A, :region, :R},
                      f, A, region, R)
    return R
end
end

function max{T}(A::Tensor{T})
    if subtype(T,Int)
        v = typemin(T)
    else
        v = convert(T,-Inf)
    end
    for i=1:numel(A)
        v = max(v,A[i])
    end
    v
end

function min{T}(A::Tensor{T})
    if subtype(T,Int)
        v = typemax(T)
    else
        v = convert(T,Inf)
    end
    for i=1:numel(A)
        v = min(v,A[i])
    end
    v
end

function sum{T}(A::Tensor{T})
    v = zero(T)
    for i=1:numel(A)
        v = sum(v,A[i])
    end
    v
end

function prod{T}(A::Tensor{T})
    v = one(T)
    for i=1:numel(A)
        v = prod(v,A[i])
    end
    v
end

for f = (:max, :min, :sum, :prod)
    @eval function ($f){T}(A::Tensor{T,2}, dim::Region)
       if isinteger(dim)
          if dim == 1
            [ ($f)(A[:,i]) | i=1:size(A, 2) ]
         elseif dim == 2
            [ ($f)(A[i,:]) | i=1:size(A, 1) ]
         end
       elseif dim == (1,2)
            ($f)(A)
       end
    end
end

max (A::Tensor, region::Region) = areduce(max,  A, region)
min (A::Tensor, region::Region) = areduce(min,  A, region)
sum (A::Tensor, region::Region) = areduce(sum,  A, region)
prod(A::Tensor, region::Region) = areduce(prod, A, region)

for f = (:all, :any, :count)
    @eval function ($f)(A::Tensor{Bool,2}, dim::Region)
        if isinteger(dim)
           if dim == 1
             [ ($f)(A[:,i]) | i=1:size(A, 2) ]
          elseif dim == 2
             [ ($f)(A[i,:]) | i=1:size(A, 1) ]
          end
        elseif dim == (1,2)
             ($f)(A)
        end
    end
end

all(A::Tensor{Bool}, region::Region) = areduce(all, A, region)
any(A::Tensor{Bool}, region::Region) = areduce(any, A, region)
count(A::Tensor{Bool}, region::Region) = areduce(count, A, region, Int32)

function isequal(x::Tensor, y::Tensor)
    if size(x) != size(y)
        return false
    end

    for i=1:numel(x)
        if !isequal(x[i], y[i])
            return false
        end
    end
    return true
end

for (f, op) = ((:cumsum, :+), (:cumprod, :(.*)) )
    @eval function ($f)(v::Vector)
        n = length(v)
        c = similar(v, n)
        if n == 0; return c; end

        c[1] = v[1]
        for i=2:n
           c[i] = ($op)(v[i], c[i-1])
        end
        return c
    end
end

## iteration support for arrays as ranges ##

start(a::Tensor) = 1
next(a::Tensor,i) = (a[i],i+1)
done(a::Tensor,i) = (i > numel(a))
isempty(a::Tensor) = (numel(a) == 0)

## map over arrays ##

#map(f, v::Vector) = [ f(v[i]) | i=1:length(v) ]
#map(f, M::Matrix) = [ f(M[i,j]) | i=1:size(M,1), j=1:size(M,2) ]

function map(f, A::Tensor)
    F = similar(A, size(A))
    for i=1:numel(A)
        F[i] = f(A[i])
    end
    return F
end

function cartesian_map(body, t::Tuple, it...)
    idx = length(t)-length(it)
    if idx == 0
        body(it)
    else
        for i = t[idx]
            cartesian_map(body, t, i, it...)
        end
    end
end

## Transpose, Permute ##

reverse(v::Vector) = [ v[length(v)-i+1] | i=1:length(v) ]

transpose(x::Vector)  = [ x[j]         | i=1, j=1:size(x,1) ]
ctranspose(x::Vector) = [ conj(x[j])   | i=1, j=1:size(x,1) ]

function ctranspose(a::Matrix)
    m,n = size(a)
    b = similar(a, n, m)
    for i=1:m, j=1:n
        b[j,i] = conj(a[i,j])
    end
    return b
end

function transpose(a::Matrix)
    m,n = size(a)
    b = similar(a, n, m)
    for i=1:m, j=1:n
        b[j,i] = a[i,j]
    end
    return b
end

function permute(A::Tensor, perm)
    dimsA = size(A)
    ndimsA = length(dimsA)
    dimsP = ntuple(ndimsA, i->dimsA[perm[i]])
    P = similar(A, dimsP)

    count = 1
    function permute_one(ind)
        P[count] = A[ntuple(ndimsA, i->ind[perm[i]])...]
        count += 1
    end

    cartesian_map(permute_one, ntuple(ndimsA, i->(Range1(1,dimsP[i]))) )
    return P
end

function ipermute(A::Tensor, perm)
    dimsA = size(A)
    ndimsA = length(dimsA)
    dimsP = ntuple(ndimsA, i->dimsA[perm[i]])
    P = similar(A, dimsP)

    count = 1
    function permute_one(ind)
        P[ntuple(ndimsA, i->ind[perm[i]])...] = A[count]
        count += 1
    end

    cartesian_map(permute_one, ntuple(ndimsA, i->(Range1(1,dimsP[i]))) )
    return P
end

## Other array functions ##

repmat(a::Matrix, m::Size, n::Size) = reshape([ a[i,j] | i=1:size(a,1),
                                                         k=1:m,
                                                         j=1:size(a,2),
                                                         l=1:n],
                                              size(a,1)*m,
                                              size(a,2)*n)


accumarray(I::Vector, J::Vector, V) = accumarray (I, J, V, max(I), max(J))


function accumarray{T<:Number}(I::Vector, J::Vector, V::T, m::Size, n::Size)
    A = similar(V, m, n)
    for k=1:length(I)
        A[I[k], J[k]] += V
    end
    return A
end

function accumarray(I::Indices, J::Indices, V::Vector, m::Size, n::Size)
    A = similar(V, m, n)
    for k=1:length(I)
        A[I[k], J[k]] += V[k]
    end
    return A
end

function find{T}(A::Vector{T})
    nnzA = nnz(A)
    I = zeros(Size, nnzA)
    z = zero(T)
    count = 1
    for i=1:length(A)
        if A[i] != z
            I[count] = i
            count += 1
        end
    end
    return I
end

function find{T}(A::Matrix{T})
    nnzA = nnz(A)
    I = zeros(Size, nnzA)
    J = zeros(Size, nnzA)
    z = zero(T)
    count = 1
    for i=1:size(A,1), j=1:size(A,2)
        if A[i,j] != z
            I[count] = i
            J[count] = j
            count += 1
        end
    end
    return (I, J)
end

function find{T}(A::Tensor{T})
    ndimsA = ndims(A)
    nnzA = nnz(A)
    I = ntuple(ndimsA, x->zeros(Size, nnzA))
    z = zero(T)

    count = 1
    function find_one(ind)
        Aind = A[ind...]
        if Aind != z
            for i=1:ndimsA
                I[i][count] = ind[i]
            end
            count += 1
        end
    end

    cartesian_map(find_one, ntuple(ndims(A), d->(1:size(A,d))) )
    return I
end

sub2ind(dims, i::Index) = i
sub2ind(dims, i::Index, j::Index) = (j-1)*dims[1] + i
sub2ind(dims) = 1

function sub2ind(dims, I::Index...)
    ndims = length(dims)
    index = I[1]
    stride = 1
    for k=2:ndims
        stride = stride * dims[k-1]
        index += (I[k]-1) * stride
    end
    return index
end

sub2ind(dims, I::Vector...) =
    [ sub2ind(dims, map(X->X[i], I)...) | i=1:length(I[1]) ]

function ind2sub(dims, ind::Index)
    ndims = length(dims)
    x = tuple(1, cumprod(dims)...)

    sub = ()
    for i=ndims:-1:1
        rest = rem(ind-1, x[i]) + 1
        sub = tuple(div(ind - rest, x[i]) + 1, sub...)
        ind = rest
    end
    return sub
end

## subarrays ##

type SubArray{T,N,A<:Tensor,I<:(Indices...)} <: Tensor{T,N}
    parent::A
    indexes::I
    dims::Dims
    
    SubArray(p::A, i::I) = new(p, i, map(length, i))
end

sub{T,N}(A::Tensor{T,N}, i::NTuple{N,Indices}) =
    SubArray{T,N,typeof(A),typeof(i)}(A, i)

sub(A::Tensor, i::Indices...) = sub(A, i)

size(s::SubArray) = s.dims
ndims{T,N}(s::SubArray{T,N}) = N

copy(s::SubArray) = copy_to(similar(s.parent, size(s)), s)
similar(s::SubArray, T::Type, dims::Dims) = similar(s.parent, T, dims)

ref(s::SubArray) = s

ref{T}(s::SubArray{T,1}, i::Index) = s.parent[s.indexes[1][i]]

ref{T}(s::SubArray{T,2}, i::Index, j::Index) =
    s.parent[s.indexes[1][i], s.indexes[2][j]]

ref(s::SubArray, is::Index...) = s.parent[map(ref, s.indexes, is)...]

ref(s::SubArray, i::Index) = s[ind2sub(size(s), i)...]
