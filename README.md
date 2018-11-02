# SortMerge

[![Build Status](https://travis-ci.org/gcalderone/SortMerge.jl.svg?branch=master)](https://travis-ci.org/gcalderone/SortMerge.jl)

## A Julia implementation of the Sort-merge algorithm.

The [Sort-merge join](https://en.wikipedia.org/wiki/Sort-merge_join) allows to **quickly** find the matching pairs in two separate arrays or collections.  The best performances are obtained when the input data are already ordered, but the algorithm is able to sort the data if they are not.

The algorithm works out of the box with arrays of numbers, but it can also be used with any data type stored in any type of container.  Also, it can handle customized sorting and matching criteria.


## Installation
```
Pkg.add("SortMerge")
```

## Basic usage

Consider the following vectors:
``` julia
array1 = [2,3,2,5,7,2,9,9,10,12]
array2 = [2,1,7,7,4,6,10,11]
```
The common elements can be found as follows:
``` julia
using SortMerge
j = sortmerge(array1, array2)
```
The `sortmerge` function returns a tuple with two structures of type `SortMerge.Results`, containing the indices of the matching pairs.   The `AbstractArray` interface is implemented for this type hence it can be used as a simple vector.  For instance, the result of the join can be printed as follows:
``` julia
println("Indices of matched pairs:")
display([j[1] j[2]])
println("Matched pairs:")
display([array1[j[1]] array2[j[2]]])
```
or, equivalently
```julia
println("Indices of matched pairs:")
for i in zip(j...)
    println(i[1], "  ", i[2])
end
println("Matched pairs:")
for i in zip(j...)
    println(array1[i[1]], "  ", array2[i[2]])
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
a1 = rand(MersenneTwister(0), 1:nn, nn);
a2 = rand(MersenneTwister(1), 1:nn, nn);
j = sortmerge(a1, a2, verbose=true)
println("Check matching: ", sum(abs.(a1[j[1]] .- a2[j[2]])) == 0)
```
where the purpose of the last line is just to perform a simple check on the matched pairs.  The `verbose=true` keyword is used to print a progress status.

The default `show` method for the tuple returned by `sortmerge` report a few details of the matching process and may help in improving the performances. E.g., for the previous example:
```
Input A:     632487 /   1000000  ( 63.2%) - max mult. 8         #lt1   46093220
Input B:     632502 /   1000000  ( 63.3%) - max mult. 9         #lt2   45496744
Output :    1001113     missed: 0                               #sd     3001111
Elapsed: 1.07 s  (sort: 0.8, match: 0.204, overhead: 0.0621)
```
The lines marked with `Input A` and `Input B` report:
- the number of indices for which a matching pair has been found;
- the total number of elements in input array;
- the fraction of indices for which a matching pair has been found;
- the maximum multiplicity;
- the number of times two numbers have been compared to sort the input array;

The line marked with `Output` reports:
- the number of matched pairs;
- the number of *missed* match (see below).  The smaller this number, the better the performances;
- the number of times two entries have been checked for a possible match.  This number is typically much smaller than the total number of possible pairs in the input arrays (10^12 in the previous example).  This is why the algorithm provides very good performances.
- the total elapsed time, and the amount of time spent while sorting the input arrays, searching for mathing pairs, and for the algorithm overhead.

Typically most of the time is spent sorting the input arrays, hence the algorithm will provide much better performances if the arrays are already sorted.  Since the order is so important, and it is calculated during a call to `sortmerge`, it will not be thrown away but returned in the result.  Hence if we are going to call again `sortmerge` we can take advantage of the previous calculation and rearrange the input arrays in sorted order:
``` julia
sorted1 = a1[sortperm(j[1])];
sorted2 = a2[sortperm(j[2])];
```
Compare the elapsed time in the previous example with the following:
``` julia
j = sortmerge(sorted1, sorted2, sorted=true)
```
(the `sorted=true` keyword tells `sortmerge` that input arrays are already sorted).



## Advanced usage

As anticipated, the **SortMerge** package can handle any data type stored in any type of container, as well as customized sorting and matching criteria, by providing customized functions for sorting and matching elements.

The custom sorting functions must accept three arguments:
- the container;
- the index of the first element to be compared;
- the index of the second element to be compared;
and must return a boolean value, `true` if the first element is smaller than the second, `false` otherwise.  The `sortmerge` accepts these function through the `lt1`, `lt2` keywords, to sort the first and second array respectively.

The custom sorting function must accept at least four arguments:
- the first container;
- the second container;
- the index in the first container of the element to be compared;
- the index in the second container of the element to be compared.

If the function accepts more than 4 arguments they must be passed as further arguments in the main `sortdist` call.  Note that when this function is called the two input containers are already sorted according to the `lt1` and `lt2` functions.

The return value must be an integer with the following meaning:
- **0**: the two elements match, and their index will be added to the final output;
- **-1**: the element in the first container do not match with the element in the second container, and will not match with any of the remaining elements in the second container;
- **1**: the element in the first container do not match with the element in the second container, and will not match with any of the previous elements in the second container;
- any other integer number: none of the above applies.

The **-1** and **1** return values are very important *hints* which allow `sortmerge` to  avoid checking for a match that will never occur, ultimately resulting in very short execution times.  The last case (any integer number different from -1, 0 and 1) allows to easily implement range matching criteria.

The `sortmerge` accept this function through the `sd` (*Sign of the Difference*) keyword.  The name stem from the fact that for array of numbers this function should return the sign of the difference of two numbers.

The following sections will provide a few examples.


### Use with [dataframes](https://github.com/JuliaData/DataFrames.jl)

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
Here we defined two custom `lt1` and `lt2` functions to sort the `numbers` and `prime` vector respectively, and a custom `sd` function which uses the appropriate column names (`:n` and `:p`) for comparison.


### Range matching using complex numbers

The following example shows how to match two arrays of complex numbers, based on the distance if they are closer than a given threshold:

```julia
nn = 1_000_000
a1 = rand(MersenneTwister(0), nn) .+ rand(MersenneTwister(1), nn) .* im;
a2 = rand(MersenneTwister(2), nn) .+ rand(MersenneTwister(3), nn) .* im;

lt = (v, i, j) -> (real(v[i]) < real(v[j]))
function sd(v1, v2, i1, i2, threshold)
    d = (real(v1[i1]) - real(v2[i2])) / threshold
	(abs(d) >= 1)  &&  (return sign(d))
    d = abs(v1[i1] - v2[i2]) / threshold
	(d < 1)  &&  (return 0)
	return 999
end

j = sortmerge(a1, a2, 1.e-5, lt1=lt, lt2=lt, sd=sd)
```
