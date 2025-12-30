-- Define puzzle input
WITH '...' AS input,

-- Part 1: Parse input into columns and apply operations
part1_parsed_rows AS (
    SELECT arrayMap(
        x -> splitByWhitespace(x),
        splitByChar('\n', input)
    ) AS rows
),

part1_columns AS (
    SELECT arrayMap(
        column_index -> arrayMap(
            row -> row[column_index],
            rows
        ),
        range(1, length(rows[1]) + 1)
    ) AS columns
    FROM part1_parsed_rows
),

part1_solution AS (
    SELECT arraySum(
        arrayMap(
            column -> if(
                -- Check if last element is multiplication operator
                arrayLast(x -> 1, column) = '*',
                
                -- Multiply all numbers in column
                toInt64(arrayProduct(
                    arrayMap(
                        x -> toInt64(x),
                        arraySlice(column, 1, length(column) - 1)
                    )
                )),
                
                -- Otherwise, add all numbers in column
                toInt64(arraySum(
                    arrayMap(
                        x -> toInt64(x),
                        arraySlice(column, 1, length(column) - 1)
                    )
                ))
            ),
            columns
        )
    ) AS solution
    FROM part1_columns
),

-- Part 2: Parse with character-level precision to handle multi-digit numbers
part2_parsed_chars AS (
    SELECT arrayMap(
        x -> ngrams(x, 1),
        splitByChar('\n', input)
    ) AS char_rows
),

part2_columns_raw AS (
    SELECT arrayMap(
        column_index -> arrayMap(
            row -> row[column_index],
            char_rows
        ),
        range(1, length(char_rows[1]) + 1)
    ) AS columns
    FROM part2_parsed_chars
),

part2_columns_filtered AS (
    SELECT arrayFilter(
        x -> NOT arrayAll(y -> y = ' ', x),
        columns
    ) AS non_empty_columns
    FROM part2_columns_raw
),

part2_numbers_extracted AS (
    SELECT arrayMap(
        column -> replaceAll(
            arrayStringConcat(
                arraySlice(column, 1, length(column) - 1)
            ),
            ' ',
            ''
        ),
        non_empty_columns
    ) AS number_strings
    FROM part2_columns_filtered
),

part2_numbers_grouped AS (
    SELECT
        number_strings,
        non_empty_columns,
        
        -- Split numbers by operator positions
        arraySplit(
            (number_str, has_operator) -> has_operator,
            number_strings,
            arrayMap(
                column -> hasAny(column, ['+', '*']),
                non_empty_columns
            )
        ) AS number_groups
    FROM part2_numbers_extracted, part2_columns_filtered
),

part2_operations AS (
    SELECT arrayZip(
        -- Extract operators from columns
        arrayFilter(
            x -> has(['+', '*'], x),
            arrayFlatten(non_empty_columns)
        ),
        -- Pair with corresponding number groups
        number_groups
    ) AS operations_with_numbers
    FROM part2_numbers_grouped
),

part2_solution AS (
    SELECT arraySum(
        arrayMap(
            operation -> if(
                -- Check operator type
                operation.1 = '*',
                
                -- Multiply all numbers in group
                toInt64(arrayProduct(
                    arrayMap(
                        x -> toInt64(x),
                        operation.2
                    )
                )),
                
                -- Otherwise, add all numbers in group
                toInt64(arraySum(
                    arrayMap(
                        x -> toInt64(x),
                        operation.2
                    )
                ))
            ),
            operations_with_numbers
        )
    ) AS solution
    FROM part2_operations
)

-- Combine results from both parts
SELECT
    'Part 1' AS part,
    solution -- 5782351442566 with my input
FROM part1_solution

UNION ALL

SELECT
    'Part 2' AS part,
    solution -- 10194584711842 with my input
FROM part2_solution
