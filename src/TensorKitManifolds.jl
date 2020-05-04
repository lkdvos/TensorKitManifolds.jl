module TensorKitManifolds

export base, checkbase, isisometry, isunitary
export projecthermitian, projecthermitian!, projectantihermitian, projectantihermitian!
export projectisometric, projectisometric!
export Grassmann, Stiefel, Unitary
export inner, retract, transport, transport!

using TensorKit

# Every submodule -- Grassmann, Stiefel, and Unitary -- implements their own methods for
# these. The signatures should be
# inner(W, Δ₁::Tangent, Δ₂::Tangent; metric)
# retract(W, Δ::Tangent, α::Real; alg)
# transport(Θ::Tangent, W, Δ::Tangent, α::Real, W′; alg)
# where the keyword arguments `alg` and `metric` should always be accepted, even if there is
# only one option for them and they are ignored. The `Tangent` is just a placeholder for the
# tangent type of each manifold. Similarly each submodule defines a `project!` function,
# which too should accept a keyword argument `metric`, even if it is ignored.
function inner end
function retract end
function transport end
function transport! end
function base end
function checkbase end
checkbase(x, y, z, args...) = checkbase(checkbase(x, y), z, args...)

# the machine epsilon for the elements of an object X, name inspired from eltype
eleps(X) = eps(real(eltype(X)))

function isisometry(W::AbstractTensorMap; tol = 10*eleps(W))
    WdW = W'*W
    s = zero(float(real(eltype(W))))
    for (c,b) in blocks(WdW)
        _subtractone!(b)
        s += dim(c)*length(b)
    end
    return norm(WdW) <= tol*sqrt(s)
end

isunitary(W::AbstractTensorMap; tol = 10*eleps(W)) =
    isisometry(W; tol = tol) && isisometry(W'; tol = tol)

function projecthermitian!(W::AbstractTensorMap)
    codomain(W) == domain(W) ||
        throw(DomainError("Tensor with distinct domain and codomain cannot be hermitian."))
    for (c,b) in blocks(W)
        _projecthermitian!(b)
    end
    return W
end
function projectantihermitian!(W::AbstractTensorMap)
    codomain(W) == domain(W) ||
        throw(DomainError("Tensor with distinct domain and codomain cannot be anithermitian."))
    for (c,b) in blocks(W)
        _projectantihermitian!(b)
    end
    return W
end

struct PolarNewton <: TensorKit.OrthogonalFactorizationAlgorithm
end
function projectisometric!(W::AbstractTensorMap; alg = Polar())
    if alg isa TensorKit.Polar || alg isa TensorKit.SDD
        foreach(blocks(W)) do (c,b)
            _polarsdd!(b)
        end
    elseif alg isa TensorKit.SVD
        foreach(blocks(W)) do (c,b)
            _polarsvd!(b)
        end
    elseif alg isa PolarNewton
        foreach(blocks(W)) do (c,b)
            _polarnewton!(b)
        end
    else
        throw(ArgumentError("unkown algorithm for projectisometric!: alg = $alg"))
    end
    return W
end

function projectcomplement!(X::AbstractTensorMap, W::AbstractTensorMap;
                            tol = 10*eleps(X))
    P = W'*X
    nP = norm(P)
    nX = norm(X)
    dP = dim(P)
    while nP > tol*max(dP, nX)
        X = mul!(X, W, P, -1, 1)
        P = W'*X
        nP = norm(P)
    end
    return X
end

projecthermitian(W::AbstractTensorMap) = projecthermitian!(copy(W))
projectantihermitian(W::AbstractTensorMap) = projectantihermitian!(copy(W))

function projectisometric(W::AbstractTensorMap;
                          alg::TensorKit.OrthogonalFactorizationAlgorithm = Polar())
    return projectisometric!(copy(W); alg=alg)
end
function projectcomplement(X::AbstractTensorMap, W::AbstractTensorMap,
                           tol = 10*eleps(X))
    return projectcomplement!(copy(X), W; tol=tol)
end

include("auxiliary.jl")
include("grassmann.jl")
include("stiefel.jl")
include("unitary.jl")

end
