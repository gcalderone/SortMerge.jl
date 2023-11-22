__precompile__(true)

module SortMerge

using Printf, SparseArrays, ProgressMeter, StatsBase

import Base.show
import Base.zip

import Base.length, Base.getindex

export sortmerge, nmatch, countmatch, subset_with_multiplicity, distinct_subsets


# --------------------------------------------------------------------
# Matched structure
#
struct Matched <: AbstractVector{Vector{Int}}
    orig_sizes::Vector{Int}
    matched::Vector{Vector{Int}}
    cmatch::Vector{SparseVector{Int,Int}}
    minmult::Vector{Int}
    maxmult::Vector{Int}
    nunique::Vector{Int}

    Matched(orig_sizes::Vector{Int}, matched::Vector{Vector{Int}}) =
        new(orig_sizes, matched, Vector{SparseVector{Int,Int}}(), Vector{Int}(), Vector{Int}(), Vector{Int}())
end

# Methods
length(mm::Matched) = length(mm.orig_sizes)
getindex(mm::Matched, source) = mm.matched[source]
zip(mm::Matched) = zip(map(i -> mm.matched[i], 1:length(mm))...)
nmatch(mm::Matched) = length(mm.matched[1])

function populate_stats!(mm::Matched)
    if length(mm.cmatch) < length(mm.orig_sizes)
        for i in 1:length(mm.orig_sizes)
            cm = countmap(mm.matched[i])
            push!(mm.cmatch, sparsevec(cm, mm.orig_sizes[i]))
            push!(mm.nunique, length(cm))
            if length(cm) == 0
                push!(mm.minmult, 0)
                push!(mm.maxmult, 0)
            else
                push!(mm.minmult, minimum(values(cm)))
                push!(mm.maxmult, maximum(values(cm)))
            end
        end
    end
    nothing
end

function countmatch(mm::Matched, source::Int)
    populate_stats!(mm)
    return mm.cmatch[source]
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
    return Matched(ret.orig_sizes,
                   [sortperm(sort1)[sort1[ret.matched[1]]],
                    sortperm(sort2)[sort2[ret.matched[2]]]])
end


function sortmerge_internal(A, B, sort1, sort2, sd_args...; sd=default_sd)
    size1 = size(A)[1]
    size2 = size(B)[1]

    match1 = Array{Int}(undef, 0)
    match2 = Array{Int}(undef, 0)

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
                push!(match1, j1)
                push!(match2, j2)
            end
        end
    end
    finish!(prog)

    mm = Matched([size1, size2], [match1, match2])
    return mm
end


show(io::IO, mime::MIME"text/plain", mm::Matched) = show(io, mm)
show(mm::Matched) = show(stdout, mm)
function show(io::IO, mm::Matched)
    populate_stats!(mm)
    for i in 1:length(mm.orig_sizes)
        @printf(io, "Input %1d: %12d / %12d  (%6.2f%%), min/max mult.: %6d : %6d\n",
                i, mm.nunique[i], mm.orig_sizes[i],
                100. * mm.nunique[i]/float(mm.orig_sizes[i]),
                mm.minmult[i], mm.maxmult[i])
    end
    @printf(io, "Output : %12d\n", nmatch(mm))
    nothing
end

#=
simple_join(A, B, match::Function) =
    sortmerge(A, B, sorted=true,
              sd=(A, B, i, j) -> (match(A[i], B[j])  ?  0  :  999))
=#


subset(mm::Matched, indices::Vector{Int}) =
    Matched(mm.orig_sizes, [mm.matched[i][indices] for i in 1:length(mm)])


function subset_with_multiplicity(mm::Matched, source::Int, multiplicity::Int)
    @assert multiplicity >= 1
    i = findall(countmatch(mm, source) .== multiplicity)
    if length(i) == 0
        return subset(mm, Int[])
    end
    j = sortmerge(i, mm.matched[source])[2]
    out = subset(mm, j)
    return out
end


function distinct_subsets(mm::Matched, source::Int)
    out = Vector{Matched}()
    for index in unique(mm[source])
        i = findall(mm[source] .== index)
        push!(out, subset(mm, i))
    end
    return out
end

end # module
