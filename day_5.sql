-- Define puzzle input
WITH '...' AS input,

-- Split input into two sections
input_sections AS (
    SELECT
        splitByString('\n\n', input)[1] AS ranges_section,
        splitByString('\n\n', input)[2] AS ids_section
),

-- Parse ranges from first section (format: "min-max" per line)
parsed_ranges AS (
    SELECT arrayMap(
        x -> (
            toUInt64(splitByChar('-', x)[1]),
            toUInt64(splitByChar('-', x)[2]) + 1 -- Make max half-open
        ),
        splitByChar('\n', ranges_section)
    ) AS ranges
    FROM input_sections
),

-- Parse IDs from second section (one ID per line)
parsed_ids AS (
    SELECT arrayMap(
        x -> toUInt64(x),
        splitByChar('\n', ids_section)
    ) AS ids
    FROM input_sections
),

-- Explode ranges into individual rows for Part 2 interval calculation
exploded_ranges AS (
    SELECT arrayJoin(ranges) AS range_tuple
    FROM parsed_ranges
),

-- Part 1: Count how many IDs fall within any range
part1_solution AS (
    SELECT
        length(
            arrayFilter(
                id -> arrayExists(
                    range -> id BETWEEN range.1 AND range.2,
                    ranges
                ),
                ids
            )
        ) AS solution
    FROM parsed_ranges, parsed_ids
),

-- Part 2: Calculate total interval length (union of all ranges)
part2_solution AS (
    SELECT
        intervalLengthSum(range_tuple.1, range_tuple.2) AS solution
    FROM exploded_ranges
)

-- Combine results from both parts
SELECT
    'Part 1' AS part,
    solution -- Should be 707 with my input
FROM part1_solution

UNION ALL

SELECT
    'Part 2' AS part,
    solution -- Should be 361615643045059 with my input
FROM part2_solution
