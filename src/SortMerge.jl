__precompile__(true)

module SortMerge

using Printf, SparseArrays, ProgressMeter, StatsBase
using DataStructures

import Base.show
import Base.zip

import Base.length, Base.size, Base.getindex,
       Base.firstindex, Base.lastindex, Base.IndexStyle

export sortmerge, nmatch, countmatch, multimatch, simple_join

# --------------------------------------------------------------------
# Source structure
#
struct Source
    size::Int
    cmatch::SparseVector{Int,Int}
end


# --------------------------------------------------------------------
# Matched structure
#
struct Matched <: AbstractVector{Vector{Int}}
    nsrc::Int
    nrow::Int
    sources::Vector{Source}
    matched::Matrix{Int}
end

# Methods
length(mm::Matched) = mm.nsrc
size(mm::Matched) = (mm.nsrc,)
getindex(mm::Matched, inds) = mm.matched[:, inds]
firstindex(mm::Matched) = 1
lastindex(mm::Matched) = mm.nsrc
IndexStyle(::Type{Matched}) = IndexLinear()

nmatch(mm::Matched) = mm.nrow
countmatch(mm::Matched, source::Int) = mm.sources[source].cmatch

zip(mm::Matched) = zip(map(i -> mm.matched[:,i], 1:mm.nsrc)...)


function subset(mm::Matched, selected::Vector{Int})
    match = fill(0, length(selected), mm.nsrc)
    sources = Vector{Source}()
    for i in 1:mm.nsrc
        match[:, i] = mm[i][selected]
        cm = countmap(match[:, i])
        ii = collect(keys(cm))
        cc = collect(values(cm))
        push!(sources, Source(mm.sources[i].size,
                              sparsevec(ii, cc, mm.sources[i].size)))
    end
    return Matched(mm.nsrc, length(selected), sources, match)
end


function multimatch(mm::Matched, source::Int, multi::Int; group=false)
    @assert multi >= 1
    index = findall(countmatch(mm, source) .== multi)
    index_out = sortmerge(index, mm.matched[:,source])[2]
    matrix = mm.matched[index_out,:]

    out = Vector{Matched}()
    ngroups = (group  ?  length(index)  :  1)
    for igroup in 1:ngroups
        jj = (group  ?
              findall(matrix[:,source] .== index[igroup])  :
              collect(1:length(index_out)))

        sources = Vector{Source}()
        for i in 1:mm.nsrc
            push!(sources, Source(mm.sources[i].size,
                                  sparsevec(unique(mm.matched[index_out[jj], i]),
                                            multi, length(mm.sources[i].cmatch))))
        end
        push!(out, Matched(mm.nsrc, length(jj), sources, mm.matched[index_out[jj],:]))
    end

    (group)  &&  (return out)
    return out[1]
end


default_lt(v::AbstractVector{T}, i, j) where T <: Number         = (v[i] < v[j])
default_lt(v::AbstractVector{T}, i, j) where T <: AbstractString = (v[i] < v[j])

default_sd(A::AbstractVector{T1}, B::AbstractVector{T2}, i, j) where {T1 <: Number, T2 <: Number} =
    sign(A[i] - B[j])
function default_sd(A::AbstractVector{T1}, B::AbstractVector{T2}, i, j) where {T1 <: AbstractString, T2 <: AbstractString}
    if A[i] == B[j]
        return 0
    end
    if A[i] < B[j]
        return -1
    end
    return 1
end


function sortmerge(A, B, sd_args...;
                   sd=default_sd,
                   sort1=nothing,
                   sort2=nothing,
                   lt1=default_lt,
                   lt2=default_lt,
                   sorted=false)
    size1 = size(A)[1]
    size2 = size(B)[1]

    if sorted
        return sortmerge_internal(A, B, 1:size1, 1:size2, sd_args...; sd=sd)
    end

    if isnothing(sort1)
        sort1 = sortperm(1:size1, lt=(i, j) -> (lt1(A, i, j)))
    end
    if isnothing(sort2)
        sort2 = sortperm(1:size2, lt=(i, j) -> (lt2(B, i, j)))
    end
    ret = sortmerge_internal(A, B, sort1, sort2, sd_args...; sd=sd)

    ret = Matched(ret.nsrc, ret.nrow, ret.sources,
                  hcat(sortperm(sort1)[sort1[ret.matched[:, 1]]],
                       sortperm(sort2)[sort2[ret.matched[:, 2]]]))
    return ret
end


function sortmerge_internal(A, B, sort1, sort2, sd_args...; sd=default_sd)
    size1 = size(A)[1]
    size2 = size(B)[1]

    match = Array{Int}(undef, 0)
    cm1 = DefaultDict{Int,Int}(0)
    cm2 = DefaultDict{Int,Int}(0)

    prog = Progress(size1, desc="SortMerge ", dt=0.5, color=:light_black)
    i2a = 1
    for i1 in 1:size1
        ProgressMeter.update!(prog, i1)
        for i2 in i2a:size2
            j1 = sort1[i1]
            j2 = sort2[i2]
            if length(sd_args) > 0  # This improves performances
                dd = Int(sd(A, B, j1, j2, sd_args...))
            else
                dd = Int(sd(A, B, j1, j2))
            end

            if     dd == -1; break
            elseif dd ==  1; i2a += 1
            elseif dd ==  0
                append!(match, [j1, j2])
                cm1[j1] += 1
                cm2[j2] += 1
            end
        end
    end
    finish!(prog)

    side1 = Source(size1, sparsevec(cm1, size1))
    side2 = Source(size2, sparsevec(cm2, size2))
    mm = Matched(2, div(length(match), 2), [side1, side2], transpose(reshape(match, 2, :)))
    return mm
end


show(io::IO, mime::MIME"text/plain", mm::Matched) = show(io, mm)
show(mm::Matched) = show(stdout, mm)
function show(io::IO, mm::Matched)
    for i in 1:length(mm.sources)
        ss = mm.sources[i]
        uu = length(unique(mm.matched[:,i]))
        maxmult = 0
        (length(ss.cmatch) > 0)  &&  (maxmult = maximum(ss.cmatch))
        @printf(io, "Input %1d: %12d / %12d  (%6.2f%%)  -  max mult. %d\n",
                i, uu, ss.size, 100. * uu/float(ss.size), maxmult)
    end
    @printf(io, "Output : %12d\n", size(mm.matched)[1])
    nothing
end


simple_join(A, B, match::Function) =
    sortmerge(A, B, sorted=true,
              sd=(A, B, i, j) -> (match(A[i], B[j])  ?  0  :  999))


end # module
