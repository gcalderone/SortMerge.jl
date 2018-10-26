using SortJoin
using Test

# --------------------------------------------------------------------
a1 = [1,2,4,6,7,10]
a2 = [2,3,5,9,10]
j = sortjoin(a1, a2)
@test length(j.match1) == 2
@test length(j.match2) == 2
@test j.match1[1] == 2
@test j.match1[2] == 6
@test j.match2[1] == 1
@test j.match2[2] == 5

# --------------------------------------------------------------------
nn = 10000
a1 = rand(1:nn, nn)
a2 = rand(1:nn, nn)

j = sortjoin(a1, a2)
@test sum(abs.(a1[j.match1] .- a2[j.match2])) == 0
for i in 1:j.size1; @test j.countmap1[i] == length(findall(a1[i] .== a2)); end
for i in 1:j.size2; @test j.countmap2[i] == length(findall(a2[i] .== a1)); end

sort!(a1)
sort!(a2)
j = sortjoin(a1, a2, skipsort=true)
@test sum(abs.(a1[j.match1] .- a2[j.match2])) == 0
for i in 1:j.size1; @test j.countmap1[i] == length(findall(a1[i] .== a2)); end
for i in 1:j.size2; @test j.countmap2[i] == length(findall(a2[i] .== a1)); end
