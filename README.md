# SortJoin

[![Build Status](https://travis-ci.org/gcalderone/SortJoin.jl.svg?branch=master)](https://travis-ci.org/gcalderone/SortJoin.jl)

## A Julia implementation of the Sort-merge join algorithm.

The [Sort-merge join](https://en.wikipedia.org/wiki/Sort-merge_join) allows to **quickly** find the matching elements in two separate arrays or collections.  The algorithm works out of the box with arrays of numbers, but can be used with any data type stored in any type of container.

The best performances are obtained when the input data are already ordered, but the algorithm is able to sort the data if they are not.


### Installation
```
Pkg.add("SortJoin")
```

### Basic usage

Consider the following vectors:
``` julia
array1 = [2,3,2,5,7,2,9,9,10,12]
array2 = [2,1,7,7,4,6,10,11]
```
The common elements can be found as follows:
``` julia
using SortJoin
j = sortjoin(array1, array2)
```
The `sortjoin` function returns a tuple with two structures, whose type is `SortJoin.Results`, containing the indices of the matching entries.   The `AbstractArray` is implemented for this type hence it can be used as a simple vector.  For instance, the result of the join can be printed as follows:
``` julia
println("Indices of matched entries:")
display([j[1] j[2]])
println("Matched entries:")
display([array1[j[1]] array2[j[2]]])
```
or, equivalently
```julia
println("Indices of matched entries:")
for i in zip(j...)
    println(i[1], "  ", i[2])
end
println("Matched entries:")
for i in zip(j...)
    println(array1[i[1]], "  ", array2[i[2]])
end
```
To obtain the plain `Vector{Int}` objects use the `indices` function, i.e.:
``` julia
for i in zip(indices(j)...)
    println(i[1], "  ", i[2])
end
```
The `indices` function (by default) returns all the indices of the matching pairs.  But it can also be used to return just the indices of entries matched with a given multiplicity.  For instance, the matched pairs whose index in the first array occur twice (multiplicity = 2) can be retrieved as follows:
``` julia
for i in zip(indices(j, 2)...)
    println(i[1], "  ", i[2])
end
```
The matched pairs whose index in the **second** array (rather than **first**) occur three times (multiplicity = 3) is obtained as follows:
``` julia
for i in zip(indices(j, 3, right=true)...)
    println(i[1], "  ", i[2])
end
```
Finally, the indices of the unmatched entries (multiplicity = 0) can be retrieved as follows:
``` julia
println("Unmatched entries in array 1:")
println(array1[indices(j[1], 0)])
println("Unmatched entries in array 2:")
println(array2[indices(j[2], 0)])
```
The number of times each element in the first array has been matched can be retrieved using the `countmap` function, returning a `Vector{Int}` whose length is the same as the input array and whose elements are the multiplicity of the matched entries:
``` julia
cm = countmap(j[1])
for i in 1:length(array1)
    println("Element at index $i ($(array1[i])) has been matched $(cm[i]) times")
end	
```
Analogously, for the second array:
``` julia
cm = countmap(j[2])
for i in 1:length(array2)
    println("Element at index $i ($(array2[i])) has been matched $(cm[i]) times")
end	
```

A more computationally demanding example is as follows:
``` julia
nn = 1_000_000
a1 = rand(1:nn, nn);
a2 = rand(1:nn, nn);
j = sortjoin(a1, a2)
println("Check matching: ", sum(abs.(a1[j[1]] .- a2[j[2]])) == 0)
```
where the purpose of the last line is just to perform a simple check on the matched pairs.

The default `show` method for the tuple returned by `sortjoin` report a few details of the matching process.  Among these:
- the number of elements in both input arrays;
- the number of indices in both input arrays for which a matching pair has been found;
- the maximum multiplicity in both input arrays;
- the number of times the algorithm compared two entries.  This number is typically much smaller than the total number of possible pairs in the input arrays (10^12 in the previous example).  The smaller this number the better the performance of the algorithm;
- the number of matched pairs;
- the elapsed time.

The `sortjoin` procedure also returns the appropriate permutation of input array to rearrange them in sorted order, e.g.:
``` julia
sorted1 = a1[sortperm(j[1])];
sorted2 = a2[sortperm(j[2])];
```
This is very important when `sortjoin` is used several times on the same input data since the performance can be significantly boosted if the input arrays are already sorted.  For instance, compare the elapsed time in the previous example with the following:
``` julia
j = sortjoin(sorted1, sorted2, skipsort=true)
```
(the `skipsort` keyword tells `sortjoin` that input arrays are already sorted).





