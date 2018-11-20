# SortMerge

[![Build Status](https://travis-ci.org/gcalderone/SortMerge.jl.svg?branch=master)](https://travis-ci.org/gcalderone/SortMerge.jl)

## A Julia implementation of the Sort-merge algorithm.

The [Sort-merge join](https://en.wikipedia.org/wiki/Sort-merge_join) algorithm allows to **quickly** find the matching pairs in two separate arrays or collections.  The best performances are obtained when the input data are already sorted, but the package is able to sort the data if they are not.

The algorithm works out of the box with arrays of real numbers, but it can also be used with any data type stored in any type of container.  Also, it can handle customized sorting and matching criteria.


## Installation
```julia
Pkg.add("SortMerge")
```

## Basic usage

Consider the following vectors:
``` julia
A = [2,3,2,5,7,2,9,9,10,12]
B = [2,1,7,7,4,6,10,11]
```
The common elements can be found as follows:
``` julia
using SortMerge
j = sortmerge(A, B)
```
The `sortmerge` function returns a tuple with two structures of type `SortMerge.Results`, containing the indices of the matching pairs.   The `AbstractArray` interface is implemented for this type hence it can be used as a simple vector.  For instance, the result of the join can be printed as follows:
``` julia
println("Indices of matched pairs:")
display([j[1] j[2]])
println("Matched pairs:")
display([A[j[1]] B[j[2]]])
```
or, equivalently
```julia
println("Indices of matched pairs:")
for i in zip(j...)
    println(i[1], "  ", i[2])
end
println("Matched pairs:")
for i in zip(j...)
    println(A[i[1]], "  ", B[i[2]])
end
```
To obtain the plain `Vector{Int}` objects use the `indices` function:
``` julia
for i in zip(indices(j)...)
    println(i[1], "  ", i[2])
end
```
The `indices` function (by default) returns all the indices of the matching pairs, but it can also be used to return just the indices of entries matched with a given multiplicity.  For instance, the matched pairs whose index in the first array occur twice (multiplicity = 2) can be retrieved as follows:
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
println(A[indices(j[1], 0)])
println("Unmatched entries in array 2:")
println(B[indices(j[2], 0)])
```
The number of times each element in the first array has been matched can be retrieved using the `countmap` function, returning a `Vector{Int}` whose length is the same as the input array and whose elements are the multiplicity of the matched entries:
``` julia
cm = countmap(j[1])
for i in 1:length(A)
    println("Element at index $i ($(A[i])) has been matched $(cm[i]) times")
end
```
Analogously, for the second array:
``` julia
cm = countmap(j[2])
for i in 1:length(B)
    println("Element at index $i ($(B[i])) has been matched $(cm[i]) times")
end
```

A more computationally demanding example is as follows:
``` julia
nn = 1_000_000
A = rand(1:nn, nn);
B = rand(1:nn, nn);
j = sortmerge(A, B)
println("Check matching: ", sum(abs.(A[j[1]] .- B[j[2]])) == 0)
```
where the purpose of the last line is just to perform a simple check on the matched pairs.

The default `show` method for the tuple returned by `sortmerge` reports a few details of the matching process and may help in finding performance bottlenecks. E.g., for the previous example:
```
Input A:     631694 /    1000000  ( 63.17%) - max mult. 9 | sort : 0.251s
Input B:     631479 /    1000000  ( 63.15%) - max mult. 9 | sort : 0.251s
Output :     999161.                                      | total: 0.878s
```
The lines marked with `Input A` and `Input B` report:
- the number of indices for which a matching pair has been found;
- the total number of elements in input array;
- the fraction of indices for which a matching pair has been found;
- the maximum multiplicity;
- the time spent sorting the array (in seconds).

The last line reports:
- the number of matched pairs in the output;
- the total elapsed time (in seconds).

Typically most of the time is spent sorting the input arrays, hence the algorithm will provide much better performances if the arrays are already sorted.  Since the order is so important, and it is calculated during a call to `sortmerge`, it will not be thrown away but returned in the result.  Hence if we are going to call again `sortmerge` we can take advantage of the previous calculation to speed up calculations:
``` julia
j = sortmerge(j, A, B)
```
The permutation vector that puts `A` and `B` in sorted order can be retrieved with the `sortperm` function, e.g.:
``` julia
A[sortperm(j[1])];
B[sortperm(j[2])];
```
Also, a custom permutation vector can be provided via the `sort1` and `sort2` keywords.  Actually, the following calls are equivalent:
``` julia
j = sortmerge(j, A, B)
# and
j = sortmerge(A, B, sort1=sortperm(j[1]), sort2=sortperm(j[2]))
```
Finally, you will get an extra boost performance (at the expense of memory allocation) if the input arrays are already sorted, i.e.
``` julia
sortedA = A[sortperm(j[1])]
sortedB = B[sortperm(j[2])]
j = sortmerge(sortedA, sortedB, sorted=true)
```
(the `sorted=true` keyword tells `sortmerge` that input arrays are already sorted).



## Advanced usage

As anticipated, the **SortMerge** package can handle any data type stored in any type of container, as well as customized sorting and matching criteria, by providing customized functions for sorting and matching elements.

The following sections will provide a few examples.

### Custom sorting function

The custom sorting functions must accept three arguments:
- the container;
- the index of the first element to be compared;
- the index of the second element to be compared;

and must return a boolean value: `true` if the first element is smaller than the second, `false` otherwise.  The `sortmerge` accepts these functions through the `lt1`, `lt2` keywords, to sort the first and second container respectively.

### Custom matching function

The custom matching function must accept at least four arguments:
- the first container;
- the second container;
- the index in the first container of the element to be compared;
- the index in the second container of the element to be compared.

If the function accepts more than 4 arguments they must be passed as further arguments in the main `sortmerge` call.  Note that when this function is called the two input containers are already sorted according to the `lt1` and `lt2` functions.

The return value must be an integer with the following meaning:
- **0**: the two elements match;
- **-1**: the element in the first container do not match with the element in the second container, and will not match with any of the remaining elements in the second container;
- **1**: the element in the first container do not match with the element in the second container, and will not match with any of the previous elements in the second container;
- any other integer number: none of the above applies (*missed match* case).

The **-1** and **1** return values are important *hints* which allows `sortmerge` to  avoid checking for a match that will never occur, ultimately resulting in very short execution times.  The *missed match* case (any integer number different from -1, 0 and 1) allows to deal with partial order relations and complex matching criteria.

The `sortmerge` accept this function through the `sd` (*Sign of the Difference*) keyword.  The name stem from the fact that for array of numbers this function should simply return the sign of the difference of two numbers.



### Use with [data frames](https://github.com/JuliaData/DataFrames.jl)

The following example shows how to match two data frames objects, according to the numbers in a specific column:
```julia
using DataFrames

# Create a data frame with prime numbers
primes = DataFrame(:p => [1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37,
                          41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97])

# ...and another one with random numbers.
nn = 100
numbers = DataFrame(:n => rand(1:100, nn))

# Search for matching elements in the two dataframes, and print the
# multiplicity of matching prime numbers
j = sortmerge(numbers, primes,
             lt1=(v, i, j) -> (v[i,:n] < v[j,:n]),
             lt2=(v, i, j) -> (v[i,:p] < v[j,:p]),
             sd=(v1, v2, i1, i2) -> (sign(v1[i1,:n] - v2[i2,:p])))

cm = countmap(j[2]);
for i in 1:nrow(primes)
    println("Prime number $(primes[i,:p]) has been matched $(cm[i]) times")
end
```
Here we defined two custom `lt1` and `lt2` functions to sort the `numbers` and `prime` DataFrame respectively, and a custom `sd` function which uses the appropriate column names (`:n` and `:p`) for comparisons.


### Match arrays of complex numbers

The following example shows how to match two arrays of complex numbers, according to their distance in the complex plane.  Unlike real numbers, there is no complete order relation for the complex number, hence we must provide a custom sorting criteria.  Among the many possible ones, here we will simply sort the arrays according to their real part.  Also, we will define a custom `sd` function accepting a fifth argument, namely the `threshold` distance below which two numbers match.

The code is:
```julia
nn = 1_000_000
a1 = rand(nn) .+ rand(nn) .* im;
a2 = rand(nn) .+ rand(nn) .* im;

lt(v, i, j) = (real(v[i]) < real(v[j]))
function sd(v1, v2, i1, i2, threshold)
    d = (real(v1[i1]) - real(v2[i2])) / threshold
	(abs(d) >= 1)  &&  (return sign(d))
    d = abs(v1[i1] - v2[i2]) / threshold
	(d < 1)  &&  (return 0)
	return 999 # missed match
end
j = sortmerge(a1, a2, 10. / nn, lt1=lt, lt2=lt, sd=sd)
```
Note that since the order relation is partial the `sd` function will sometimes return a number different from -1, 0 and 1, resulting in the so called *missed match* condition (return value is 999).

You may check that the results actually consider all matching pairs by disabling all optimization hints (i.e. the -1 and 1 return values) altoghether, and compare **each** element in first array with **each** element in the second:
```julia
function sd(v1, v2, i1, i2, threshold)
    d = abs(v1[i1] - v2[i2]) / threshold
	(d < 1)  &&  (return 0)
	return 999 # missed match
end
j = sortmerge(a1, a2, 10. / nn, sorted=true, sd=sd)
```
but be prepared that the execution time will be really long!

Another possible approach is to sort the numbers by their distance from the origin, i.e.
```julia
lt(v, i, j) = (abs2(v[i]) < abs2(v[j]))
function sd(v1, v2, i1, i2, threshold)
    d = (abs(v1[i1]) - abs(v2[i2])) / threshold
	(abs(d) >= 1)  &&  (return sign(d))
    d = abs(v1[i1] - v2[i2]) / threshold
	(d < 1)  &&  (return 0)
	return 999 # missed match
end
j = sortmerge(a1, a2, 10. / nn, lt1=lt, lt2=lt, sd=sd)
```
but the performance worsen since `abs` is slower than `real`.


### Match arrays of geographical coordinates

The following example shows how to match 2D arrays containing geographical coordinates (latitude and longitude).  We will use the `gcirc` function in the [Astrolib](https://github.com/JuliaAstro/AstroLib.jl) package to calculate the great circle arc distances between two points:

``` julia
nn = 1_000_000
lat1  = rand(nn) .* 180 .- 90.;
long1 = rand(nn) .*360;
lat2  = rand(nn) .* 180 .- 90.;
long2 = rand(nn) .* 360;

using AstroLib
lt(v, i, j) = (v[i, 2] < v[j, 2])
function sd(v1, v2, i1, i2, threshold_arcsec)
    threshold_deg = threshold_arcsec / 3600. # [deg]
    d = (v1[i1, 2] - v2[i2, 2]) / threshold_deg
    (abs(d) >= 1)  &&  (return sign(d))
    dd = gcirc(2, v1[i1, 1], v1[i1, 2], v2[i2, 1], v2[i2, 2])
    (dd < threshold_arcsec)  &&  (return 0)
    return 999
end
j = sortmerge([lat1 long1], [lat2 long2], lt1=lt, lt2=lt, sd=sd, 1.)
```
