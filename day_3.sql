-- Define puzzle input
WITH '...' AS input,

-- Convert input to array of digit values for Part 2
digit_array AS (
    SELECT
        arrayMap(
            x -> toUInt8(x),
            ngrams(arrayJoin(splitByChar('\n', input)), 1)
        ) AS digits,
        length(digits) AS total_digits
),

-- Constants
12 AS num_digits_needed,

-- Part 1: Find largest two-digit number from each line
part1_largest_pairs AS (
    SELECT
        ngrams(arrayJoin(splitByChar('\n', input)), 1) AS chars,
        arraySlice(chars, 1, length(chars) - 1) AS chars_without_last,
        
        -- Find first max digit, then find max digit after it
        concat(
            arrayMax(chars_without_last),
            arrayMax(
                arraySlice(
                    chars,
                    arrayFirstIndex(
                        x -> x = arrayMax(chars_without_last),
                        chars
                    ) + 1
                )
            )
        )::Int16 AS largest_two_digit
),

-- Part 2: Build largest N-digit number by greedily selecting max digits
part2_greedy_selection AS (
    SELECT
        digits,
        
        -- Iteratively build number by selecting maximum available digit
        arrayFold(
            (accumulator, current_element) -> (
                -- Decrement remaining digits counter
                greatest(accumulator.1 - 1, 0)::Int64,
                
                -- Update position: find where max digit is in remaining slice
                accumulator.2 + (
                    arrayFirstIndex(
                        x -> x = arrayMax(
                            arraySlice(
                                digits,
                                accumulator.2 + 1,
                                total_digits - accumulator.1 - accumulator.2 + 1
                            )
                        ),
                        arraySlice(
                            digits,
                            accumulator.2 + 1,
                            total_digits - accumulator.1 - accumulator.2 + 1
                        )
                    )
                )::UInt64,
                
                -- Accumulate joltage: add max digit * 10^(remaining-1)
                accumulator.3 + if(
                    accumulator.1 = 0,
                    0::UInt64,
                    arrayMax(
                        arraySlice(
                            digits,
                            accumulator.2 + 1,
                            total_digits - accumulator.1 - accumulator.2 + 1
                        )
                    ) * intExp10(greatest(0, accumulator.1 - 1))
                )
            ),
            digits,
            
            -- Initial accumulator state:
            -- (digits_remaining, current_position, accumulated_value)
            (num_digits_needed::Int64, 0::UInt64, 0::UInt64)
        ).3 AS joltage  -- Extract the accumulated value (3rd element)
    
    FROM digit_array
)

-- Combine results from both parts
SELECT
    'Part 1' AS part,
    sum(largest_two_digit)::UInt64 AS solution -- Should be 17263 with my input
FROM part1_largest_pairs

UNION ALL

SELECT
    'Part 2' AS part,
    sum(joltage) AS solution -- Should be 170731717900423 with my input
FROM part2_greedy_selection