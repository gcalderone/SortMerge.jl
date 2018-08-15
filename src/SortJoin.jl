__precompile__(true)

module SortJoin

using Printf

import Base.show
export sortjoin

struct sortjoinResult 
    size1::Int
    size2::Int
    sort1::Vector{Int}
    sort2::Vector{Int}
    match1::Vector{Int}
    match2::Vector{Int}
    unique1::Int
    unique2::Int
    unmatch1::Vector{Int}
    unmatch2::Vector{Int}
    elapsed::Float64
end


function show(stream::IO, j::sortjoinResult)
    @printf("Len. array 1 : %-12d  matched: %-12d (%5.1f%%)\n", j.size1, j.unique1, 100. * j.unique1/float(j.size1))
    @printf("Len. array 2 : %-12d  matched: %-12d (%5.1f%%)\n", j.size2, j.unique2, 100. * j.unique2/float(j.size2))
    @printf("Matched items: %-12d\n", length(j.match1))
    @printf("Elapsed time : %-8.4g s", j.elapsed)
end


# Default signdiff function
function signdiff(sorting, vec1, vec2, i1, i2)
    return sign(vec1[i1] - vec2[i2])
end


function sortjoin(vec1, vec2, signdiff=signdiff, args...; skipsort=false, verbose=false)
    elapsed = (Base.time_ns)()
    size1 = size(vec1)[1]
    size2 = size(vec2)[1]

    sort1 = Int.(range(1, stop=size1, length=size1))
    sort2 = Int.(range(1, stop=size2, length=size2))
    if !skipsort
        sort1 = sortperm(sort1, lt=(i, j) -> (signdiff(true, vec1, vec1, i, j, args...)::Int == -1))
        sort2 = sortperm(sort2, lt=(i, j) -> (signdiff(true, vec2, vec2, i, j, args...)::Int == -1))
    end

    i2a = 1
    match1 = Array{Int}(undef, 0)
    match2 = Array{Int}(undef, 0)
    completed = 0.
    lastlog = -1.
    for i1 in 1:size1
        for i2 in i2a:size2
            # Logging
            completed = ceil(1000. * ((i1-1) * size2 + i2) / (size1 * size2))
            if verbose
                if completed > lastlog
                    @printf("Completed: %5.1f%%, matched: %d \r", completed/10., length(match1))
                    lastlog = completed
                end
            end

            sign::Int = signdiff(false, vec1, vec2, sort1[i1], sort2[i2], args...) # sign(vec1 - vec2)
            if sign == 0
                push!(match1, i1)
                push!(match2, i2)
                continue
            elseif sign ==  1
                i2a += 1
            elseif sign == -1
                break
            end
        end
    end
    if verbose
        @printf("Completed: %5.1f%%, matched: %d \n", 100., length(match1))
    end
    match1 = sort1[match1]
    match2 = sort2[match2]

    unmatch1 = fill(true, size1)
    unmatch2 = fill(true, size2)
    u1 = unique(match1)
    u2 = unique(match2)
    unmatch1[u1] .= false
    unmatch2[u2] .= false
    unmatch1 = findall(unmatch1)
    unmatch2 = findall(unmatch2)
    elapsed = (Base.time_ns)() - elapsed

    return sortjoinResult(size1, size2, sort1, sort2, match1, match2, length(u1), length(u2), 
                          unmatch1, unmatch2, elapsed / 1.e9)
end

end # module
