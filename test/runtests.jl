using SortJoin, Random
using Test

# --------------------------------------------------------------------
a1 = [1,2,4,6,7,10]
a2 = [2,3,5,9,10]
j = sortjoin(a1, a2)
@test length(j[1]) == 2
@test length(j[2]) == 2
@test j[1][1] == 2
@test j[1][2] == 6
@test j[2][1] == 1
@test j[2][2] == 5
@test a1[indices(j[1], 0)] == [1, 4, 6, 7]
@test a2[indices(j[2], 0)] == [3, 5, 9]

# --------------------------------------------------------------------
nn = 1_0_000
a1 = rand(MersenneTwister(0), 1.:nn,   nn)
a2 = rand(MersenneTwister(1), 1.:nn, 2*nn)
a1 = unique(a1)

j = sortjoin(a1, a2)
@test sum(abs.(a1[j[1]] .- a2[j[2]])) == 0
cm = countmap(j[1]); for i in 1:length(cm); @test cm[i] == length(findall(a1[i] .== a2)); end
cm = countmap(j[2]); for i in 1:length(cm); @test cm[i] == length(findall(a2[i] .== a1)); end

println(a1[indices(j[1], 8)])
(k1, k2) = indices(j, 8);
println(a1[k1])
println(a2[k2])
@test sum(abs.(a1[k1] .- a2[k2])) == 0

k1 = indices(j[1], 0);
k2 = indices(j[2], 0);
for i in k1; @test length(findall(a1[i] .== a2)) == 0; end
for i in k2; @test length(findall(a2[i] .== a1)) == 0; end


sort!(a1)
sort!(a2)
(j1, j2) = sortjoin(a1, a2, skipsort=true)
@test sum(abs.(a1[j1] .- a2[j2])) == 0
cm = countmap(j1); for i in 1:length(cm); @test cm[i] == length(findall(a1[i] .== a2)); end
cm = countmap(j2); for i in 1:length(cm); @test cm[i] == length(findall(a2[i] .== a1)); end
