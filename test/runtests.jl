using SortJoin
@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

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
for i1 in j.unmatch1
	for i2 in j.unmatch2
		@test a1[i1] != a2[i2]
	end
end

sort!(a1)
sort!(a2)
j = sortjoin(a1, a2, skipsort=true)
@test sum(abs.(a1[j.match1] .- a2[j.match2])) == 0
for i1 in j.unmatch1
	for i2 in j.unmatch2
		@test a1[i1] != a2[i2]
	end
end
