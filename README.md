# SortJoin

[![Build Status](https://travis-ci.org/gcalderone/SortJoin.jl.svg?branch=master)](https://travis-ci.org/gcalderone/SortJoin.jl)

## A Julia implementation of the Sort-merge join algorithm.

The [Sort-merge join](https://en.wikipedia.org/wiki/Sort-merge_join) allows to **quickly** find the matching elements in two separate arrays or collections, regardless of the type of the container.

### Installation
```
Pkg.add("SortJoin")
```

### Usage

Consider the following arrays:
``` julia
array1 = [1,2,4,6,7,10]
array2 = [2,3,5,9,10]
```
The common elements can be found as follows:
``` julia
using SortJoin
join = sortjoin(array1, array2)
```
The `sortjoin` function returns a structure with several informations on the join operation.  The most important fields are `match1` and `match2`, containing all the index (in `array1` and `array2` respectively) with matching elements.  The latter can be printed as follows:
``` julia
println("Matched elements:")
display([array1[join.match1] array2[join.match2]])
```
The index for the unmatched elements in both arrays are stored in the `unmatch1` and `unmatch2` fields:
``` julia
println("Unmatched elements in array 1:")
println(array1[findall(join.countmap1 .== 0)])
println("Unmatched elements in array 2:")
println(array2[findall(join.countmap2 .== 0)])
```

A more computational intensive example is as follows:
``` julia
nn = 100000
a1 = rand(1:nn, nn);
a2 = rand(1:nn, nn);

join = sortjoin(a1, a2)
println("Check matching: ", sum(abs.(a1[join.match1] .- a2[join.match2])) == 0)
```
where we also added a simple check of the matched elements.

The `sortjoin` function works by pre-sorting the two input arrays, and scanning them simultaneously to find the matching elements.  This approach is the **fastest** way to join two arrays since it minimizes the number of comparisons (provided the pre-sorting step has negligible overhead).


If the two input arrays are already sorted you can tell `sortjoin` to skip the pre-sorting step to improve the performances using the `skipsort` keyword:
``` julia
sort!(a1);
sort!(a2);
join = sortjoin(a1, a2, skipsort=true)
println("Check matching: ", sum(abs.(a1[join.match1] .- a2[join.match2])) == 0)
```



## The `lt` and `signdiff` function

The sort order of input arrays and the hints to optimize the join are provided by the `signdiff` function, which in the default implementation is simply:
```
function signdiff(vec1, vec2, i1, i2)
    return sign(vec1[i1] - vec2[i2])
end
```
i.e. it returns the *sign* of the *difference* between the `i1`-th element in the `vec1` vector and the the `i2`-th element in the `vec2` vector.  This function works perfectly when the data to be matched are numbers stored in unidimensional arrays.  However, the user may provide customized version of the `signdiff` function, to handle **any** type of data, including multidimensional arrays, [dataframes](https://github.com/JuliaData/DataFrames.jl), user defined types etc.  In the following sections we will show two examples.


The `signdiff` function, both the default one or the customized ones, must accept at least four arguments:
- the first *container*;
- the second *container*;
- the index in the first container of the element to be compared;
- the index in the second container of the element to be compared;

If the `signdiff` function accepts more than 4 arguments, they must be passed as arguments to the main `sortdist` function.

The return value must be as follows:
- **0**: the two elements match, and their index will be added to the output `match1` and `match2` vectors;
- **-1**: the element in the first container is *smaller* than the element in the second container;
- **1**: the element in the first container is *greater* than the element in the second container;
- any other integer number: there is no order relation between the two elements.

The last case allows to join data also when there is no clear order relations between the elements.  In the most general case the user provided `signdiff` function will returns only **0** (matching elements) and a number different from **-1** and **1** (non-matching elements).  In this case the `sortjoin` function will actually perform a cross-join, i.e. it will compare all elements from the first container with all the elements from the second, resulting in very poor performances.





## Using 2D arrays as input
Suppose we want to join arrays containing geographical coordinates, latitude and longitude.  We will use the `gcirc` function in the [Astrolib](https://github.com/JuliaAstro/AstroLib.jl) package to calculate the great circle arc distances between two points.

``` julia
# Prepare input arrays
nn = 1_000_000
lat1  = rand(-90:0.01:90 , nn);
long1 = rand(  0:0.01:360, nn);
lat2  = rand(-90:0.01:90 , nn);
long2 = rand(  0:0.01:360, nn);

# Define a customized `signdiff` function.  Note that this function accepts a 5th argument, namely the distance threshold in arcsec below which two coordinates match.
using AstroLib
aa(c1, c2, i1, i2) = ((c1[i1, 2] - c2[i2, 2]) < 0)
function signdiff(c1, c2, i1, i2, thresh_asec)
    thresh_deg = thresh_asec / 3600. # [deg]
    dd = c1[i1, 2] - c2[i2, 2]
    (dd < -thresh_deg)  &&  (return -1)
    (dd >  thresh_deg)  &&  (return  1)
    dd = gcirc(2, c1[i1, 1], c1[i1, 2], c2[i2, 1], c2[i2, 2])
    (dd < thresh_asec)  &&  (return 0)
    return 999
end
 
# Join the arrays.  Note that we passed the customized  `signdiff` function as 3rd argument and the matching threshold as 4th argument.
jj = sortjoin([lat1 long1], [lat2 long2], lt=aa, signdiff=signdiff, 1.)

# Print the maximum arc distance in arcsec between all matched coordinates.  This must be smaller than 1.
println(maximum(gcirc.(2, long1[join.match1], lat1[join.match1], long2[join.match2], lat2[join.match2])))
```

If we are going to repeat the join operation with the same input arrays we may use the pre-sorting data calculated during the first `sortjoin` call to pre-order the arrays and improve the performances.
``` julia
# Pre-sort input arrays
lat1  = lat1[ join.sort1]
long1 = long1[join.sort1]
lat2  = lat2[ join.sort2]
long2 = long2[join.sort2]

# Join arrays skipping the pre-sort step (`skipsort=true`)
join = sortjoin([lat1 long1], [lat2 long2], signdiff, 1., skipsort=true)
println(maximum(gcirc.(2, long1[join.match1], lat1[join.match1], long2[join.match2], lat2[join.match2])))
```
Note that using the `skipsort=true` keyword on non-sorted input arrays may result in non-complete matching results.  However, no sorting check is performed (to avoid performance degradation), hence the user should use `skipsort=true` only when the input data are sorted beyond any doubt.


## Using DataFrames
We may perform the join described above also if the data are stored in a [dataframe](https://github.com/JuliaData/DataFrames.jl), by providing a suitable `signdiff` function:

``` julia
using DataFrames
function signdiff(coord1, coord2, i1, i2, thresh_arcsec)
    thresh_deg = thresh_arcsec / 3600. # [deg]
    δ = coord1[i1, :lat] - coord2[i2, :lat]
    (δ < -thresh_deg)  &&  (return -1)
    (δ >  thresh_deg)  &&  (return  1)
    (gcirc(2, coord1[i1, :long], coord1[i1, :lat], coord2[i2, :long], coord2[i2, :lat]) < thresh_arcsec)  &&  (return 0)
    return 999
end

# Create the two DataFrame object
coord1 = DataFrame(:lat => lat1, :long => long1)
coord2 = DataFrame(:lat => lat2, :long => long2)

# Join using the customized `signdiff` function.  Note that the data were already sorted, hence we use `skipsort=true`
join = sortjoin(coord1, coord2, signdiff, 1., skipsort=true)
println(maximum(gcirc.(2, coord1[join.match1, :long], coord1[join.match1, :lat], coord2[join.match2, :long], coord2[join.match2, :lat])))
```
