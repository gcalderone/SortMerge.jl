__precompile__(true)

module SortMerge

using Printf

import Base.show
import Base.sortperm

import Base.iterate, Base.length, Base.size, Base.getindex,
       Base.firstindex, Base.lastindex, Base.IndexStyle

import StatsBase.countmap

export sortmerge, sortperm, indices, countmap

struct Result <: AbstractArray{Int, 1}
    size::Int
    sortperm::Vector{Int}
    match::Vector{Int}
    countmap::Vector{Int}
    elapsed::Float64
    elapsed_sorting::Float64
end

iterate(jj::Result, state=1) = state > length(jj.match) ? nothing : (jj.match[state], state+1)
length(jj::Result) = length(jj.match)
size(jj::Result) = (length(jj.match),)
getindex(jj::Result, i)	= jj.match[i]
firstindex(jj::Result) = 1
lastindex(jj::Result) = length(jj.match)
IndexStyle(Result::Type) = IndexLinear()

function show(stream::IO, j::Result)
    u1 = length(unique(j.match))
    @printf("Input  : %10d / %10d  (%6.2f%%) - max mult. %d\n", u1, j.size, 100. * u1/float(j.size), maximum(j[1].countmap))
end

function show(stream::IO, j::NTuple{2,Result})
    @assert length(j[1].match) == length(j[2].match)
    u1 = length(unique(j[1].match))
    u2 = length(unique(j[2].match))
    @printf("Input A: %10d / %10d  (%6.2f%%) - max mult. %d | sort : %.3gs\n", u1, j[1].size, 100. * u1/float(j[1].size), maximum(j[1].countmap), j[1].elapsed_sorting)
    @printf("Input B: %10d / %10d  (%6.2f%%) - max mult. %d | sort : %.3gs\n", u2, j[2].size, 100. * u2/float(j[2].size), maximum(j[2].countmap), j[1].elapsed_sorting)
    @printf("Output : %10d.                                      | total: %.3gs\n", length(j[1].match), j[1].elapsed)
end

function default_lt(v, i, j)
    return v[i] < v[j]
end
function default_sd(A, B, i, j)
    return sign(A[i] - B[j])
end

function sortmerge(j::NTuple{2, Result},
                   A, B, args...;
                   sd=default_sd,
                   quiet=false)
    return sortmerge(A, B, args..., sort1=j[1].sortperm, sort2=j[2].sortperm, sd=sd, quiet=quiet)
end
function sortmerge(A, B, args...;
                   sd=default_sd,
                   quiet=false,
                   sort1=Vector{Int}(),
                   sort2=Vector{Int}(),
                   lt1=default_lt,
                   lt2=default_lt,
                   sorted=false)

    elapsed = (Base.time_ns)()
    size1 = size(A)[1]
    size2 = size(B)[1]

    elapsed_sorting1 = (Base.time_ns)()
    if length(sort1) == 0
        sort1 = collect(range(1, length=size1))
        (sorted)  ||  (sort1 = sortperm(sort1, lt=(i, j) -> (lt1(A, i, j))))
    end
    elapsed_sorting1 = ((Base.time_ns)() - elapsed_sorting1) / 1.e9
    elapsed_sorting2 = (Base.time_ns)()
    if length(sort2) == 0
        sort2 = collect(range(1, length=size2))
        (sorted)  ||  (sort2 = sortperm(sort2, lt=(i, j) -> (lt2(B, i, j))))
    end
    elapsed_sorting2 = ((Base.time_ns)() - elapsed_sorting2) / 1.e9

    i2a = 1
    match1 = Array{Int}(undef, 0)
    match2 = Array{Int}(undef, 0)
    cm1 = fill(0, size1)
    cm2 = fill(0, size2)

    lastlog = -1.
    progress = false
    for i1 in 1:size1
        for i2 in i2a:size2
            if !progress  &&  !quiet  &&  (((Base.time_ns)() - elapsed) / 1.e9 > 1)
                progress = true
            end
            if progress
                completed = ceil(1000. * ((i1-1) * size2 + i2) / (size1 * size2))
                if completed > lastlog
                    @printf("Completed: %5.1f%%, matched: %d \r", completed/10., length(match1))
                    lastlog = completed
                end
            end

            j1 = sort1[i1]
            j2 = sort2[i2]
            if length(args) > 0  # This improves performances
                dd = Int(sd(A, B, j1, j2, args...))
            else
                dd = Int(sd(A, B, j1, j2))
            end

            if     dd == -1; break
            elseif dd ==  1; i2a += 1
            elseif dd ==  0
                push!(match1, j1)
                push!(match2, j2)
                cm1[j1] += 1
                cm2[j2] += 1
            end
        end
    end
    if progress
        @printf("Completed: %5.1f%%, matched: %d \n", 100., length(match1))
    end

    elapsed = ((Base.time_ns)() - elapsed) / 1.e9
    ret1 = Result(size1, sort1, match1, cm1, elapsed, elapsed_sorting1)
    ret2 = Result(size2, sort2, match2, cm2, elapsed, elapsed_sorting2)
    return (ret1, ret2)
end


countmap(res::Result) = res.countmap
sortperm(res::Result) = res.sortperm

function indices(res::Result, multiplicity::Int=1)
    @assert multiplicity >= 0
    (multiplicity == 1)  &&  (return res.match)
    return findall(res.countmap .== multiplicity)
end

indices(res::NTuple{2, Result}, multiplicity::Int=1; right=false) = indices(res..., multiplicity, right=right)
function indices(res1::Result, res2::Result, multiplicity::Int=1; right=false)
    @assert multiplicity >= 1
    (multiplicity == 1)  &&  (return (res1.match, res2.match))
    if right
        ii = findall(res2.countmap .== multiplicity)
        (q1, q2) = sortmerge(ii, res2.match)
        return (res1.match[q2.match], ii[q1.match])
    end
    ii = findall(res1.countmap .== multiplicity)
    (q1, q2) = sortmerge(ii, res1.match)
    return (ii[q1.match], res2.match[q2.match])
end

end # module
