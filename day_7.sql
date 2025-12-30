-- Define puzzle input 
WITH '...' AS input,

-- Parse input into character grid
parsed_grid AS (
    SELECT arrayMap(
        x -> ngrams(x, 1),
        splitByChar('\n', input)
    ) AS rows
),

-- Find starting position in first row
initial_state AS (
    SELECT
        arrayFirstIndex(x -> x = 'S', rows[1])::UInt8 AS start_position,
        map(
            arrayFirstIndex(x -> x = 'S', rows[1])::UInt8,
            1::UInt64
        )::Map(UInt8, UInt64) AS initial_worlds
    FROM parsed_grid
),

-- Filter to only rows with '^' markers (active rows)
active_rows AS (
    SELECT arrayFilter(
        x -> has(x, '^'),
        rows
    ) AS filtered_rows
    FROM parsed_grid
),

-- Main iteration: propagate world counts through rows
world_propagation AS (
    SELECT
        start_position,
        initial_worlds,
        filtered_rows,
        
        -- Fold through each row, updating state
        arrayFold(
            (accumulator, current_row) -> (
                -- Update left boundary (shrink inward)
                (accumulator.1 - 1)::UInt8,
                
                -- Update right boundary (shrink inward)
                (accumulator.2 + 1)::UInt8,
                
                -- Update world map: propagate counts based on '^' positions
                mapSort(
                    (key, value) -> key,
                    mapUpdate(
                        accumulator.3,
                        arrayReduce(
                            'sumMap',
                            arrayMap(
                                position -> if(
                                    -- Check if position has '^' and exists in current worlds
                                    current_row[position] = '^'
                                    AND mapContains(accumulator.3, position),
                                    
                                    -- Propagate world count to adjacent positions
                                    map(
                                        -- Left neighbor gets count (unless blocked by another '^')
                                        (position - 1)::UInt8,
                                        (
                                            accumulator.3[position] + if(
                                                current_row[greatest(0, position - 2)] = '^',
                                                0,
                                                accumulator.3[position - 1]
                                            )
                                        )::UInt64,
                                        
                                        -- Current position resets to 0
                                        (position)::UInt8,
                                        0::UInt64,
                                        
                                        -- Right neighbor gets count
                                        (position + 1)::UInt8,
                                        (accumulator.3[position + 1] + accumulator.3[position])::UInt64
                                    ),
                                    
                                    -- No propagation if conditions not met
                                    map()::Map(UInt8, UInt64)
                                ),
                                -- Only process positions within current boundaries
                                arraySlice(
                                    arrayEnumerate(current_row),
                                    accumulator.1,
                                    (accumulator.2 - accumulator.1) + 1
                                )
                            )
                        )
                    )
                ),
                
                -- Part 1 counter: count '^' positions with non-zero worlds
                accumulator.4 + arrayCount(
                    position -> 
                        current_row[position] = '^'
                        AND mapContains(accumulator.3, position)
                        AND accumulator.3[position] > 0,
                    arraySlice(
                        arrayEnumerate(current_row),
                        accumulator.1,
                        (accumulator.2 - accumulator.1) + 1
                    )
                )
            ),
            filtered_rows,
            
            -- Initial accumulator state:
            -- (left_boundary, right_boundary, worlds_map, part1_counter)
            (
                start_position,
                start_position,
                initial_worlds,
                0::UInt64
            )
        ) AS final_state
    FROM initial_state, active_rows
),

-- Part 1: Count of '^' positions encountered with non-zero worlds
part1_solution AS (
    SELECT final_state.4 AS solution
    FROM world_propagation
),

-- Part 2: Sum of all world counts across all positions
part2_solution AS (
    SELECT arraySum(mapValues(final_state.3)) AS solution
    FROM world_propagation
)

-- Combine results from both parts
SELECT
    'Part 1' AS part,
    solution -- 1633 with my input
FROM part1_solution

UNION ALL

SELECT
    'Part 2' AS part,
    solution -- 34339203133559 with my input
FROM part2_solution
