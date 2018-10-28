__precompile__(true)

module SortJoin

using Printf, StatsBase

import Base.show
export sortjoin

struct SortJoinResult
    size1::Int
    size2::Int
    sort1::Vector{Int}
    sort2::Vector{Int}
    match1::Vector{Int}
    match2::Vector{Int}
    countmap1::Vector{Int}
    countmap2::Vector{Int}
    count_unmatch1::Int
    count_unmatch2::Int
    count_unique1::Int
    count_unique2::Int
    count_multi1::Int
    count_multi2::Int
    elapsed::Float64
end


function show(stream::IO, j::SortJoinResult)
    @printf("Len. array 1 : %-12d  matched: %-12d (%5.1f%%)\n", j.size1, j.count_unique1, 100. * j.count_unique1/float(j.size1))
    @printf("Len. array 2 : %-12d  matched: %-12d (%5.1f%%)\n", j.size2, j.count_unique2, 100. * j.count_unique2/float(j.size2))
    @printf("Matched items: %-12d\n", length(j.match1))
    @printf("Elapsed time : %-8.4g s", j.elapsed)
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

    dcm1 = Dict{Int,Int}(); (length(match1) > 0)  &&  (dcm1 = countmap(match1))
    dcm2 = Dict{Int,Int}(); (length(match2) > 0)  &&  (dcm2 = countmap(match2))
    cm1 = fill(0, size1)
    cm2 = fill(0, size2)
    for (key, val) in dcm1; cm1[key] = val; end
    for (key, val) in dcm2; cm2[key] = val; end
    ret = SortJoinResult(size1, size2, sort1, sort2, match1, match2, cm1, cm2,
                         length(findall(cm1 .== 0)), length(findall(cm2 .== 0)),
                         length(findall(cm1 .== 1)), length(findall(cm2 .== 1)),
                         length(findall(cm1 .>= 2)), length(findall(cm2 .>= 2)),
                         ((Base.time_ns)() - elapsed) / 1.e9)
    return ret
end

end # module
