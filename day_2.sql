-- Define puzzle input
WITH '...' AS input,

-- Parse range bounds from input string
range_bounds AS (
    SELECT arrayMap(
        x -> x::UInt64,
        splitByChar('-', arrayJoin(splitByChar(',', input)))
    ) AS bounds
),

-- Expand ranges into individual numbers
expanded_numbers AS (
    SELECT
        arrayJoin(range(bounds[1], bounds[2] + 1)) AS number,
        toString(number) AS number_string,
        length(number_string) AS string_length
    FROM range_bounds
),

-- Analyze each number for repeating patterns
repeating_analysis AS (
    SELECT
        number_string,
        toUInt64(number_string) AS number,
        
        -- Part 2: Check if string is made of any repeating pattern
        -- (e.g., "123123" = "123" repeated, "1111" = "1" repeated)
        arrayExists(
            x -> (string_length % x = 0)
                AND (
                    repeat(
                        substring(number_string, 1, x),
                        (string_length / x)::UInt32
                    ) = number_string
                ),
            range(1, string_length)
        ) AS has_pattern_repeat,
        
        -- Part 1: Check if second half equals first half
        -- (e.g., "1212" -> "12" = "12", "123123" -> "123" = "123")
        if(
            string_length % 2 = 0 
            AND substring(number_string, (string_length / 2) + 1, string_length / 2) 
                = substring(number_string, 1, string_length / 2),
            1,
            0
        ) AS has_half_repeat
    FROM expanded_numbers
    WHERE
        has_pattern_repeat != 0 
        OR has_half_repeat != 0
    ORDER BY number ASC
)

-- Calculate final solutions
SELECT 
    sumIf(number, has_half_repeat = 1) AS part_1_solution, -- Should be 24043483400 with my input
    sumIf(number, has_pattern_repeat = 1) AS part_2_solution -- Should be 38262920235 with my input
FROM repeating_analysis