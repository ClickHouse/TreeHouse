-- Define puzzle input (replace '...' with actual input string)
WITH '...' as input,
-- Parse the input string into individual instructions
parsed_instructions AS (
    -- Initial placeholder row
    SELECT
        0 AS instruction_id,
        'R50' AS raw_instruction,
        'R' AS direction,
        50::Int16 AS steps
    
    UNION ALL
    
    -- Parse each line from input
    SELECT
        rowNumberInAllBlocks() + 1 AS instruction_id,
        raw AS raw_instruction,
        substring(raw, 1, 1) AS direction,
        substring(raw, 2)::Int16 AS steps
    FROM format(TSV, 'raw String', input)
), 

-- Part 1: Calculate positions with simple modulo wrapping
part1_positions AS (
    SELECT
        instruction_id,
        raw_instruction,
        direction,
        steps,
        
        -- Normalize direction: positive for R, negative for L
        if(direction = 'R', steps % 100, -1 * (steps % 100)) AS normalized_steps,
        
        -- Calculate cumulative position
        sum(normalized_steps) OVER (
            ORDER BY instruction_id
        ) AS raw_position,
        
        -- Wrap position to 0-99 range
        ((raw_position % 100) + 100) % 100 AS position
    FROM parsed_instructions
),

-- Part 2: Calculate positions with full movement tracking
position_calculations AS (
    SELECT
        instruction_id,
        raw_instruction,
        direction,
        steps,
        
        -- Normalize direction (no modulo yet)
        if(direction = 'R', steps, -1 * steps) AS normalized_steps,
        
        -- Calculate cumulative raw position
        sum(normalized_steps) OVER (
            ORDER BY instruction_id ASC
        ) AS raw_position,
        
        -- Wrap to 0-99 range
        ((raw_position % 100) + 100) % 100 AS position
    FROM parsed_instructions
),

-- Track turn counts based on position changes
turn_tracking AS (
    SELECT
        *,
        
        -- Get previous position for comparison
        lagInFrame(position) OVER (
            ORDER BY instruction_id ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS previous_position,
        
        -- Calculate turns for this instruction
        if(
            instruction_id = 0,
            0,
            
            -- Base turns from full rotations
            floor(steps / 100) + 
            
            -- Additional turn if we wrapped around
            if(
                direction = 'R',
                (position != 0 AND previous_position != 0 AND position < previous_position) ? 1 : 0,
                (position != 0 AND previous_position != 0 AND position > previous_position) ? 1 : 0
            )
        ) + 
        
        -- Extra turn if we land exactly on position 0
        if(instruction_id != 0 AND position = 0, 1, 0) AS turn_count
    FROM position_calculations
),

-- Calculate cumulative turn counts
part2_turn_counts AS (
    SELECT
        instruction_id,
        raw_instruction,
        direction,
        steps,
        position,
        turn_count,
        
        -- Running sum of turns
        sum(turn_count) OVER (
            ORDER BY instruction_id ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_turns
    FROM turn_tracking
)

-- Final results for both parts
SELECT 
    'Part 1' AS part,
    countIf(position = 0) AS solution -- Should be 1100 with my input
FROM part1_positions

UNION ALL

SELECT 
    'Part 2' AS part,
    max(cumulative_turns)::UInt64 AS solution -- Should be 6358 with my input
FROM part2_turn_counts;