__precompile__(true)

module SortJoin

using Printf, StatsBase

import Base.show
import Base.sortperm
import StatsBase.countmap

export sortjoin, sortperm, matched, countmap

struct SortJoinResult
    size::Int
    sort::Vector{Int}
    match::Vector{Int}
    elapsed::Float64
end


function show(stream::IO, j::SortJoinResult)
    u1 = length(unique(j.match))
    @printf("Len. array   : %-12d  matched: %-12d (%5.1f%%)\n", j.size, u1, 100. * u1/float(j.size))
    @printf("Matched items: %-12d\n", length(j.match))
    @printf("Elapsed time : %-8.4g s", j.elapsed)
end

function show(stream::IO, j::NTuple{2,SortJoinResult})
    @assert length(j[1].match) == length(j[2].match)
    u1 = length(unique(j[1].match))
    u2 = length(unique(j[2].match))
    @printf("Len. array 1 : %-12d  matched: %-12d (%5.1f%%)\n", j[1].size, u1, 100. * u1/float(j[1].size))
    @printf("Len. array 2 : %-12d  matched: %-12d (%5.1f%%)\n", j[2].size, u2, 100. * u2/float(j[2].size))
    @printf("Matched items: %-12d\n", length(j[1].match))
    @printf("Elapsed time : %-8.4g s", j[1].elapsed)
end

function sortjoin(vec1, vec2, args...;
                  lt=(v1, v2, i1, i2) -> (v1[i1] < v2[i2]),
                  signdiff=(v1, v2, i1, i2) -> (sign(v1[i1] - v2[i2])),
                  skipsort=false, verbose=false)

    elapsed = (Base.time_ns)()
    size1 = size(vec1)[1]
    size2 = size(vec2)[1]

    sort1 = Int.(range(1, stop=size1, length=size1))
    sort2 = Int.(range(1, stop=size2, length=size2))
    if !skipsort
        sort1 = sortperm(sort1, lt=(i, j) -> lt(vec1, vec1, i, j))
        sort2 = sortperm(sort2, lt=(i, j) -> lt(vec2, vec2, i, j))
    end

    i2a = 1
    match1 = Array{Int}(undef, 0)
    match2 = Array{Int}(undef, 0)
    completed = 0.
    lastlog = -1.
    for i1 in 1:size1
        for i2 in i2a:size2
            # Logging
            if verbose
                completed = ceil(1000. * ((i1-1) * size2 + i2) / (size1 * size2))
                if completed > lastlog
                    @printf("Completed: %5.1f%%, matched: %d \r", completed/10., length(match1))
                    lastlog = completed
                end
            end

            j1 = sort1[i1]
            j2 = sort2[i2]
            if length(args) > 0  # This improves performances
                dd = Int(signdiff(vec1, vec2, j1, j2, args...))
            else
                dd = Int(signdiff(vec1, vec2, j1, j2))
            end
            
            if     dd == -1; break
            elseif dd ==  1; i2a += 1
            elseif dd ==  0
                push!(match1, j1)
                push!(match2, j2)
            end
        end
    end
    if verbose
        @printf("Completed: %5.1f%%, matched: %d \n", 100., length(match1))
    end

    elapsed = ((Base.time_ns)() - elapsed) / 1.e9
    ret1 = SortJoinResult(size1, sort1, match1, elapsed)
    ret2 = SortJoinResult(size2, sort2, match2, elapsed)
    return (ret1, ret2)
end


function countmap(res::SortJoinResult)
    dcm = Dict{Int,Int}()
    (length(res.match) > 0)  &&  (dcm = countmap(res.match))
    cm = fill(0, res.size)
    for i in 1:res.size
        haskey(dcm, i)  &&  (cm[i] = dcm[i])
    end
    return cm
end

sortperm(res::SortJoinResult) = res.sort
function matched(res::SortJoinResult, times::Int=1)
    @assert times >= 0
    (times == 1)  &&  (return res.match)
    return findall(countmap(res) .== times)
end

function matched(res1::SortJoinResult, res2::SortJoinResult, times::Int=1)
    @assert times >= 0
    if times == 0
        return (findall(countmap(res1) .== 0), findall(countmap(res2) .== 0))
    end
    if times == 1
        return (res1.match, res2.match)
    end
    ii = findall(countmap(res1) .== times)
    (q1, q2) = sortjoin(ii, res1.match)
    return (ii[q1.match], res2.match[q2.match])
end

end # module
