using Test
using SortMerge

# ...existing tests if any...

@testset "Progress control" begin
    # Create test data
    v1 = rand(100)
    v2 = rand(200)
    
    # Test with progress enabled (default)
    result1 = sortmerge(v1, v2)
    @test result1 isa Matched
    
    # Test with progress explicitly disabled
    result2 = sortmerge(v1, v2, show_progress=false)
    @test result2 isa Matched
    
    # Verify results are identical
    @test length(result1.matched[1]) == length(result2.matched[1])
end