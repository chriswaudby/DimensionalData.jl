"""
Dimension is the abstract supertype of all dimension types.

Example concrete implementations are `X`, `Y`, `Z`, 
`Ti` (Time), and the arbirary `Dim{:custom}` dimension.

`Dimension`s label the axes of an `AbstractDimesnionalArray`, 
or other dimensional data. They may also provide an alternate index 
to lookup for each array axis.


Example:
```julia
using Dates
x = X(2:2:10)
y = Y(['a', 'b', 'c'])
ti = Ti(DateTime(2021, 1):Month(1):DateTime(2021, 12))
```

```julia
A = DimensionalArray(rand(3, 5, 12), (y, x, ti));
```

For simplicity, the same `Dimension` types are also used as wrappers 
in `getindex`, like:

```julia
x = A[X(2), Y(3)]
```

Dimension can also wrap [`Selectors`](@ref).

```julia
x = A[X(Between(3, 4)), Y(At('b'))]
```

`Dimension` objects may have [`mode`](@ref) and [`metadata`](@ref) fields
to track additional information about the data and the index, and their relationship.
"""
abstract type Dimension{T,IM,M} end

"""
Abstract supertype for independent dimensions. Thise will plot on the X axis.
"""
abstract type IndependentDim{T,IM,M} <: Dimension{T,IM,M} end

"""
Abstract supertype for Dependent dimensions. These will plot on the Y axis.
"""
abstract type DependentDim{T,IM,M} <: Dimension{T,IM,M} end

"""
Abstract parent type for all X dimensions. 
"""
abstract type XDim{T,IM,M} <: IndependentDim{T,IM,M} end

"""
Abstract parent type for all Y dimensions.
"""
abstract type YDim{T,IM,M} <: DependentDim{T,IM,M} end

"""
Abstract parent type for all Z dimensions.
"""
abstract type ZDim{T,IM,M} <: Dimension{T,IM,M} end

"""
Abstract parent type for all time dimensions.

For an index with `Interval` sampling the locus will automatically be
set to `Start()`, as a date/time index generally defines the start of a 
month, second etc, not the central point as is more common with spatial data.
`"""
abstract type TimeDim{T,IM,M} <: IndependentDim{T,IM,M} end

ConstructionBase.constructorof(d::Type{<:Dimension}) = basetypeof(d)

const DimType = Type{<:Dimension}
const DimTuple = Tuple{<:Dimension,Vararg{<:Dimension}} where N
const DimTypeTuple = Tuple{Vararg{DimType}}
const DimVector = Vector{<:Dimension}
const DimOrDimType = Union{Dimension,DimType}
const AllDims = Union{Dimension,DimTuple,DimType,DimTypeTuple,DimVector}


# Getters
val(dim::Dimension) = dim.val
mode(dim::Dimension) = dim.mode
mode(dim::Type{<:Dimension}) = NoIndex()
metadata(dim::Dimension) = dim.metadata

order(dim::Dimension) = order(mode(dim))
indexorder(dim::Dimension) = indexorder(order(dim))
arrayorder(dim::Dimension) = arrayorder(order(dim))
relationorder(dim::Dimension) = relationorder(order(dim))

locus(dim::Dimension) = locus(mode(dim))
sampling(dim::Dimension) = sampling(mode(dim))

# DimensionalData interface methods
rebuild(dim::D, val, mode::IndexMode=mode(dim), metadata=metadata(dim)) where D <: Dimension =
    constructorof(D)(val, mode, metadata)

dims(x::Dimension) = x
dims(x::DimTuple) = x
name(dim::Dimension) = name(typeof(dim))
shortname(d::Dimension) = shortname(typeof(d))
shortname(d::Type{<:Dimension}) = name(d) # Use `name` as fallback
units(dim::Dimension) =
    metadata(dim) == nothing ? nothing : get(val(metadata(dim)), :units, nothing)


bounds(dim::Dimension) = bounds(mode(dim), dim)
bounds(dims::DimTuple) = map(bounds, dims)
bounds(dims::Tuple{}) = ()
bounds(dims::DimTuple, lookupdims::Tuple) = bounds(dims[[dimnum(dims, lookupdims)...]]...)
bounds(dims::DimTuple, lookupdim::DimOrDimType) = bounds(dims[dimnum(dims, lookupdim)])


# Base methods
Base.eltype(dim::Type{<:Dimension{T}}) where T = T
Base.eltype(dim::Type{<:Dimension{A}}) where A<:AbstractArray{T} where T = T
Base.size(dim::Dimension) = size(val(dim))
Base.axes(dim::Dimension) = axes(val(dim))
Base.eachindex(dim::Dimension) = eachindex(val(dim))
Base.length(dim::Dimension) = length(val(dim))
Base.ndims(dim::Dimension) = 0
Base.ndims(dim::Dimension{<:AbstractArray}) = ndims(val(dim))
Base.getindex(dim::Dimension) = val(dim)
Base.getindex(dim::Dimension{<:AbstractArray}, I...) = getindex(val(dim), I...)
Base.iterate(dim::Dimension{<:AbstractArray}, args...) = iterate(val(dim), args...)
Base.first(dim::Dimension) = val(dim)
Base.last(dim::Dimension) = val(dim)
Base.first(dim::Dimension{<:AbstractArray}) = first(val(dim))
Base.last(dim::Dimension{<:AbstractArray}) = last(val(dim))
Base.firstindex(dim::Dimension{<:AbstractArray}) = firstindex(val(dim))
Base.lastindex(dim::Dimension{<:AbstractArray}) = lastindex(val(dim))
Base.step(dim::Dimension) = step(mode(dim))
Base.Array(dim::Dimension{<:AbstractArray}) = Array(val(dim))
Base.:(==)(dim1::Dimension, dim2::Dimension) =
    typeof(dim1) == typeof(dim2) &&
    val(dim1) == val(dim2) &&
    mode(dim1) == mode(dim2) &&
    metadata(dim1) == metadata(dim2)

# AbstractArray methods where dims are the dispatch argument

@inline rebuildsliced(A, data, I, name::String=name(A)) =
    rebuild(A, data, slicedims(A, I)..., name)

Base.@propagate_inbounds Base.getindex(A::AbstractArray, dim::Dimension, dims::Vararg{<:Dimension}) =
    getindex(A, dims2indices(A, (dim, dims...))...)

Base.@propagate_inbounds Base.setindex!(A::AbstractArray, x, dim::Dimension, dims::Vararg{<:Dimension}) =
    setindex!(A, x, dims2indices(A, (dim, dims...))...)

Base.@propagate_inbounds Base.view(A::AbstractArray, dim::Dimension, dims::Vararg{<:Dimension}) =
    view(A, dims2indices(A, (dim, dims...))...)

@inline Base.axes(A::AbstractArray, dims::DimOrDimType) = axes(A, dimnum(A, dims))
@inline Base.size(A::AbstractArray, dims::DimOrDimType) = size(A, dimnum(A, dims))


"""
Dimensions with user-set type paremeters
"""
abstract type ParametricDimension{X,T,IM,M} <: Dimension{T,IM,M} end

"""
    Dim{X}(val, mode, metadata)
    Dim{X}(val=:; [mode=Auto()], [metadata=nothing])

A generic dimension. For use when custom dims are required when loading
data from a file. The sintax is ugly and verbose to use for indexing,
ie `Dim{:lat}(1:9)` rather than `Lat(1:9)`. This is the main reason
they are not the only type of dimension availabile.

```julia
dim = Dim{:custom}(['a', 'b', 'c'])
```
"""
struct Dim{X,T,IM<:IndexMode,M} <: ParametricDimension{X,T,IM,M}
    val::T
    mode::IM
    metadata::M
    Dim{X}(val, mode, metadata) where X =
        new{X,typeof(val),typeof(mode),typeof(metadata)}(val, mode, metadata)
end

Dim{X}(val=:; mode=Auto(), metadata=nothing) where X =
    Dim{X}(val, mode, metadata)
name(::Type{<:Dim{X}}) where X = "Dim $X"
shortname(::Type{<:Dim{X}}) where X = "$X"
basetypeof(::Type{<:Dim{X}}) where {X} = Dim{X}

"""
    AnonDim()

Anonymous dimension. Used when extra dimensions are created, 
such as during transpose of a vector.
"""
struct AnonDim{T} <: Dimension{T,NoIndex,Nothing} 
    val::T
end

val(dim::AnonDim) = dim.val
mode(::AnonDim) = NoIndex()
metadata(::AnonDim) = nothing
name(::AnonDim) = "Anon"

"""
    @dim typ [supertype=Dimension] [name=string(typ)] [shortname=string(typ)]

Macro to easily define specific dimensions.

Example:
```julia
@dim Lat "Lattitude" "lat"
@dim Lon XDim "Longitude"
```
"""
macro dim end

macro dim(typ::Symbol, args...)
    dimmacro(typ::Symbol, :Dimension, args...)
end

macro dim(typ::Symbol, supertyp::Symbol, args...)
    dimmacro(typ, supertyp, args...)
end

dimmacro(typ, supertype, name=string(typ), shortname=string(typ)) =
    esc(quote
        struct $typ{T,IM<:IndexMode,M} <: $supertype{T,IM,M}
            val::T
            mode::IM
            metadata::M
        end
        $typ(val=:; mode=Auto(), metadata=nothing) =
            $typ(val, mode, metadata)
        DimensionalData.name(::Type{<:$typ}) = $name
        DimensionalData.shortname(::Type{<:$typ}) = $shortname
    end)

# Define some common dimensions.
@dim X XDim
@doc """
X [`Dimension`](@ref). `X <: XDim <: IndependentDim`

## Example:
```julia
x = X(2:2:10)
```
""" X

@dim Y YDim
@doc """
Y [`Dimension`](@ref). `Y <: YDim <: DependentDim`

## Example:
```julia
y = Y(['a', 'b', 'c'])
```
""" Y

@dim Z ZDim
@doc """
Z [`Dimension`](@ref). `Z <: ZDim <: Dimension`

## Example:
```julia
z = Z(10:10:100)
```
""" Z

@dim Ti TimeDim "Time"
@doc """
Time [`Dimension`](@ref). `Ti <: TimeDim <: IndependentDim`

`Time` is already used by Dates, so we use `Ti` to avoid clashing.

## Example:
```julia
ti = Ti(DateTime(2021, 1):Month(1):DateTime(2021, 12))
```
""" Ti

# Time dimensions need to default to the Start() locus, as that is
# nearly always the format and Center intervals are difficult to
# calculate with DateTime step values.
identify(locus::AutoLocus, dimtype::Type{<:TimeDim}, index) = Start()

const Time = Ti # For some backwards compat
