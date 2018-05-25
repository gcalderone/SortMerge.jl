module SortJoin

import Base.show
export sortjoin

struct sortjoinResult 
    size1::Int
    size2::Int
    sort1::Vector{Int}
    sort2::Vector{Int}
    match1::Vector{Int}
    match2::Vector{Int}
    unmatch1::Vector{Int}
    unmatch2::Vector{Int}
    elapsed::Float64
end


function show(stream::IO, j::sortjoinResult)
    println(stream, "Len. array 1 : ", j.size1)
    println(stream, "Len. array 2 : ", j.size2)
    println(stream, "Matched items: ", length(j.match1))
    println(stream, "Elapsed time : ", j.elapsed, " s")   
end


# Default signdiff function
function signdiff(vec1, vec2, i1, i2)
    return sign(vec1[i1] - vec2[i2])
end


function sortjoin(vec1, vec2, signdiff=signdiff, args...; skipsort=false)
    elapsed = (Base.time_ns)()
    size1 = size(vec1)[1]
    size2 = size(vec2)[1]

    sort1 = Int.(linspace(1, size1, size1))
    sort2 = Int.(linspace(1, size2, size2))
    if !skipsort
        sort1 = sortperm(sort1, lt=(i, j) -> (signdiff(vec1, vec1, i, j, args...) == -1))
        sort2 = sortperm(sort2, lt=(i, j) -> (signdiff(vec2, vec2, i, j, args...) == -1))
    end

    i2a = 1
    count = 0
    match1 = Array{Int}(0)
    match2 = Array{Int}(0)
    for i1 in 1:size1
        for i2 in i2a:size2
            count += 1
            sign::Int = signdiff(vec1, vec2, sort1[i1], sort2[i2], args...) # sign(vec1 - vec2)
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
    match1 = sort1[match1]
    match2 = sort2[match2]

    unmatch1 = fill(true, size1)
    unmatch2 = fill(true, size2)
    unmatch1[unique(match1)] = false
    unmatch2[unique(match2)] = false
    unmatch1 = find(unmatch1)
    unmatch2 = find(unmatch2)
    elapsed = (Base.time_ns)() - elapsed

    return sortjoinResult(size1, size2, sort1, sort2, match1, match2, unmatch1, unmatch2, elapsed / 1.e9)
end

end # module
