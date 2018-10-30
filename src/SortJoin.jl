__precompile__(true)

module SortJoin

using Printf

import Base.show
import Base.sortperm
import Base.indices
import Base.iterate, Base.length, Base.size, Base.getindex,
       Base.firstindex,  Base.lastindex, Base.IndexStyle

export sortjoin, sortperm, indices, countmap

struct Result <: AbstractArray{Int, 1}
    size::Int
    sort::Vector{Int}
    match::Vector{Int}
    countmap::Vector{Int}
    count::Int
    elapsed::Float64
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
    @printf("Len. array  : %-9d  matched indices: %-9d (%5.1f%%)  max multiplicity: %-9d\n", j.size, u1, 100. * u1/float(j.size), maximum(j.countmap))
end

function show(stream::IO, j::NTuple{2,Result})
    @assert length(j[1].match) == length(j[2].match)
    u1 = length(unique(j[1].match))
    u2 = length(unique(j[2].match))
    @printf("Len. array 1: %-9d  matched indices: %-9d (%5.1f%%), max multipl.: %-9d\n", j[1].size, u1, 100. * u1/float(j[1].size), maximum(j[1].countmap))
    @printf("Len. array 2: %-9d  matched indices: %-9d (%5.1f%%), max multipl.: %-9d\n", j[2].size, u2, 100. * u2/float(j[2].size), maximum(j[2].countmap))
    @printf("#comparisons: %-9d  matched pairs  : %-9d (%5.1f%%)\n", j[1].count, length(j[1].match), 100. * length(j[1].match) / float(j[1].count))
    @printf("Elapsed time: %-8.4g s", j[1].elapsed)
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
    cm1 = fill(0, size1)
    cm2 = fill(0, size2)

    lastlog = -1.
    count = 0
    for i1 in 1:size1
        for i2 in i2a:size2
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
            count += 1
            
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
    if verbose
        @printf("Completed: %5.1f%%, matched: %d \n", 100., length(match1))
    end

    elapsed = ((Base.time_ns)() - elapsed) / 1.e9
    ret1 = Result(size1, sort1, match1, cm1, count, elapsed)
    ret2 = Result(size2, sort2, match2, cm2, count, elapsed)
    return (ret1, ret2)
end


countmap(res::Result) = res.countmap
sortperm(res::Result) = res.sort

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
        (q1, q2) = sortjoin(ii, res2.match)
        return (res1.match[q2.match], ii[q1.match])
    end
    ii = findall(res1.countmap .== multiplicity)
    (q1, q2) = sortjoin(ii, res1.match)
    return (ii[q1.match], res2.match[q2.match])
end

end # module
