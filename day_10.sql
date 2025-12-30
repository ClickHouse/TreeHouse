WITH RECURSIVE
-- Define puzzle input 
    '...' AS input,

-- Parse raw input into structured format
raw_split AS (
    SELECT
        row_number() OVER () AS puzzle_id,
        splitByChar(' ', raw) AS components
    FROM format('TSVRaw', 'raw String', input)
),

parsed_puzzles AS (
    SELECT
        puzzle_id,
        
        -- Parse diagram: '#' becomes 1, '.' becomes 0
        arrayMap(
            x -> if(x = '#', 1, 0),
            ngrams(replaceRegexpAll(components[1], '[\\[\\]]', ''), 1)
        ) AS target_diagram,
        
        -- Parse buttons: each button affects specific positions
        arrayMap(
            button_str -> arrayMap(
                pos_str -> (toUInt16(pos_str) + 1),
                splitByChar(',', replaceRegexpAll(button_str, '[\\(\\)]', ''))
            ),
            arraySlice(components, 2, length(components) - 2)
        ) AS button_effects,
        
        -- Parse joltages: target values for Part 2
        arrayMap(
            x -> toUInt32(x),
            splitByChar(',', replaceRegexpAll(components[-1], '[\\{\\}]', ''))
        ) AS target_joltages
    FROM raw_split
),

puzzle_metadata AS (
    SELECT
        puzzle_id,
        target_diagram,
        button_effects,
        target_joltages,
        length(button_effects) AS num_buttons,
        length(target_joltages) AS num_positions
    FROM parsed_puzzles
),

-- PART 1: Brute force - enumerate all button combinations
part1_button_combinations AS (
    SELECT
        p.puzzle_id,
        p.target_diagram,
        p.button_effects,
        p.num_buttons,
        p.num_positions,
        combination_id,
        toUInt32(bitCount(combination_id)) AS button_presses,
        
        -- Calculate resulting diagram from this combination
        arrayMap(
            position -> toUInt8(
                modulo(
                    arrayReduce(
                        'sum',
                        arrayMap(
                            button_index -> if(
                                bitTest(combination_id, button_index)
                                AND has(button_effects[button_index + 1], position),
                                1,
                                0
                            ),
                            range(0, num_buttons)
                        )
                    ),
                    2
                )
            ),
            range(1, num_positions + 1)
        ) AS resulting_diagram
    FROM puzzle_metadata p
    ARRAY JOIN range(0, toUInt32(pow(2, num_buttons))) AS combination_id
),

part1_minimum_solutions AS (
    SELECT
        puzzle_id,
        min(button_presses) AS minimum_presses
    FROM part1_button_combinations
    WHERE target_diagram = resulting_diagram
    GROUP BY puzzle_id
),

-- PART 2: Pre-compute button combination patterns for recursive algorithm
button_combination_patterns AS (
    SELECT
        p.puzzle_id,
        p.button_effects,
        p.num_buttons,
        p.num_positions,
        combination_id,
        toUInt32(bitCount(combination_id)) AS pattern_cost,
        
        -- Pattern: numeric effect on each position
        arrayMap(
            position -> toUInt32(
                arrayReduce(
                    'sum',
                    arrayMap(
                        button_index -> if(
                            bitTest(combination_id, button_index)
                            AND has(button_effects[button_index + 1], position),
                            1,
                            0
                        ),
                        range(0, num_buttons)
                    )
                )
            ),
            range(1, num_positions + 1)
        ) AS effect_pattern,
        
        -- Parity pattern: XOR constraint (mod 2)
        arrayMap(
            position -> toUInt8(
                modulo(
                    arrayReduce(
                        'sum',
                        arrayMap(
                            button_index -> if(
                                bitTest(combination_id, button_index)
                                AND has(button_effects[button_index + 1], position),
                                1,
                                0
                            ),
                            range(0, num_buttons)
                        )
                    ),
                    2
                )
            ),
            range(1, num_positions + 1)
        ) AS parity_pattern
    FROM puzzle_metadata p
    ARRAY JOIN range(0, toUInt32(pow(2, num_buttons))) AS combination_id
),

-- Group patterns by parity for efficient lookup
patterns_grouped_by_parity AS (
    SELECT
        puzzle_id,
        button_effects,
        num_buttons,
        num_positions,
        parity_pattern,
        groupArray(tuple(effect_pattern, pattern_cost)) AS available_patterns
    FROM button_combination_patterns
    GROUP BY puzzle_id, button_effects, num_buttons, num_positions, parity_pattern
),

-- Recursive halving algorithm: iteratively reduce joltages to zero
recursive_halving_solver AS (
    -- Base case: start with target joltages
    SELECT
        puzzle_id,
        button_effects,
        num_buttons,
        num_positions,
        target_joltages AS current_goal,
        toUInt64(0) AS accumulated_cost,
        0 AS recursion_depth
    FROM puzzle_metadata
    
    UNION ALL
    
    -- Recursive case: apply pattern, subtract, halve, and continue
    SELECT
        puzzle_id,
        button_effects,
        num_buttons,
        num_positions,
        current_goal,
        min(accumulated_cost) AS accumulated_cost,
        min(recursion_depth) AS recursion_depth
    FROM (
        SELECT
            solver.puzzle_id,
            solver.button_effects,
            solver.num_buttons,
            solver.num_positions,
            
            -- New goal: (current - pattern) / 2
            arrayMap(
                i -> intDiv(
                    solver.current_goal[i] - pattern_tuple.1[i],
                    2
                ),
                range(1, solver.num_positions + 1)
            ) AS current_goal,
            
            -- Accumulate cost: pattern_cost * 2^depth
            solver.accumulated_cost + 
                toUInt64(pattern_tuple.2) * toUInt64(pow(2, solver.recursion_depth)) AS accumulated_cost,
            
            solver.recursion_depth + 1 AS recursion_depth
        FROM recursive_halving_solver solver
        INNER JOIN patterns_grouped_by_parity patterns
            ON patterns.puzzle_id = solver.puzzle_id
            AND patterns.parity_pattern = arrayMap(
                x -> if(x % 2 = 0, toUInt8(0), toUInt8(1)),
                solver.current_goal
            )
        ARRAY JOIN patterns.available_patterns AS pattern_tuple
        WHERE
            solver.recursion_depth < 100
            AND NOT arrayAll(x -> x = 0, solver.current_goal)
            -- Ensure pattern doesn't overshoot (feasibility constraint)
            AND arrayAll(
                i -> pattern_tuple.1[i] <= solver.current_goal[i],
                range(1, solver.num_positions + 1)
            )
    )
    GROUP BY puzzle_id, button_effects, num_buttons, num_positions, current_goal
),

part2_minimum_solutions AS (
    SELECT
        puzzle_id,
        min(accumulated_cost) AS minimum_cost
    FROM recursive_halving_solver
    WHERE arrayAll(x -> x = 0, current_goal)
    GROUP BY puzzle_id
),

-- Aggregate final solutions
combined_solutions AS (
    SELECT 'Part 1' AS part, sum(minimum_presses) AS solution -- 527 with my input
    FROM part1_minimum_solutions
    
    UNION ALL

    SELECT 'Part 2' AS part, sum(minimum_cost) AS solution -- 19810 with my input
    FROM part2_minimum_solutions
)

-- Combine results from both parts
SELECT * FROM combined_solutions;