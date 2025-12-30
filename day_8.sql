-- Define puzzle input 
WITH '...' AS input,

-- Parse 3D coordinate points
parsed_points AS (
    SELECT (x, y, z) AS point
    FROM format('CSV', 'x UInt32, y UInt32, z UInt32', input)
),

-- Generate all point pairs with L2 distances, sorted by distance
point_pairs_by_distance AS (
    SELECT
        t1.point AS point1,
        t2.point AS point2,
        L2Distance(
            [point1.1, point1.2, point1.3],
            [point2.1, point2.2, point2.3]
        ) AS distance
    FROM parsed_points AS t1
    CROSS JOIN parsed_points AS t2
    WHERE point1 < point2
    ORDER BY distance ASC
),

-- Take the 1000 closest pairs
closest_pairs AS (
    SELECT groupArray([point1, point2]) AS pairs
    FROM (
        SELECT point1, point2
        FROM point_pairs_by_distance
        ORDER BY distance ASC
        LIMIT 1000
    )
),

-- Part 1: Build connected components from closest pairs
connected_components AS (
    SELECT
        pairs,
        
        -- Fold through pairs to merge into connected components
        arrayFold(
            (accumulator, pair) -> if(
                -- Check if any existing components contain points from current pair
                length(
                    arrayFilter(
                        component -> hasAny(component, pair),
                        accumulator
                    )
                ) > 0,
                
                -- Merge matching components with current pair
                arrayConcat(
                    -- Keep non-matching components unchanged
                    arrayFilter(
                        component -> NOT hasAny(component, pair),
                        accumulator
                    ),
                    -- Add merged component
                    [
                        arrayDistinct(
                            arrayFlatten(
                                arrayConcat(
                                    arrayFilter(
                                        component -> hasAny(component, pair),
                                        accumulator
                                    ),
                                    [pair]
                                )
                            )
                        )
                    ]
                ),
                
                -- No matches found, add pair as new component
                arrayConcat(accumulator, [pair])
            ),
            pairs,
            []::Array(Array(Tuple(UInt32, UInt32, UInt32)))
        ) AS components
    FROM closest_pairs
),

component_analysis AS (
    SELECT
        components,
        arrayMap(x -> length(x), components) AS component_sizes
    FROM connected_components
),

part1_solution AS (
    SELECT arrayProduct(
        arraySlice(
            arrayReverseSort(component_sizes),
            1,
            3
        )
    ) AS solution
    FROM component_analysis
),

-- Part 2: Find first pair where 1000 unique points have been seen
point_pair_states AS (
    SELECT
        point1,
        point2,
        distance,
        arrayReduce('uniqCombinedState', [point1, point2]) AS points_state
    FROM point_pairs_by_distance
),

part2_solution AS (
    SELECT
        point1,
        point2,
        distance,
        runningAccumulate(points_state) AS unique_points_seen,
        point1.1 * point2.1 AS solution
    FROM point_pair_states
    WHERE unique_points_seen >= 1000
    ORDER BY distance ASC
    LIMIT 1
)

-- Combine results from both parts
SELECT
    'Part 1' AS part,
    solution::UInt64 -- 135169920 with my input
FROM part1_solution

UNION ALL

SELECT
    'Part 2' AS part,
    solution::UInt64 -- 302133440 with my input
FROM part2_solution

SETTINGS allow_deprecated_error_prone_window_functions = 1
