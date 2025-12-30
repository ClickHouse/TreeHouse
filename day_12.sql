/*
NOTE: Similar to past years, Advent of Code Day 12 has a deceptively complex puzzle description and sample input.
The actual puzzle inputs provided are more straightforward - all we need to do is determine whether or not:
(squares used by shape) * (requested volume for shape), summed across all shapes, fits within the area of the region.
This can be solved with basic array and string manipulation without complex geometry or packing algorithms.
*/

-- Define puzzle input 
WITH '...' AS input_raw,

-- Split input into sections
input_sections AS (
    SELECT arrayMap(
        section -> splitByChar('\n', section),
        splitByString('\n\n', input_raw)
    ) AS sections
),

-- Extract regions section (last section)
regions_section AS (
    SELECT sections[-1] AS region_lines
    FROM input_sections
),

-- Extract shape sections (all except last)
shapes_sections AS (
    SELECT arrayJoin(
        arraySlice(sections, 1, length(sections) - 1)
    ) AS shape_lines
    FROM input_sections
),

-- Parse shape data
parsed_shapes AS (
    SELECT
        shape_lines,
        
        -- Transform shape lines: first line is name, rest is pattern
        arrayMap(
            line_index -> if(
                line_index = 1,
                -- First line: remove ':' from name
                replaceAll(shape_lines[line_index], ':', ''),
                -- Other lines: convert '#' to 1, '.' to 0
                replaceRegexpAll(
                    replaceRegexpAll(shape_lines[line_index], '#', '1'),
                    '\\.',
                    '0'
                )
            ),
            arrayEnumerate(shape_lines)
        ) AS transformed_lines
    FROM shapes_sections
),

-- Convert shape patterns to binary arrays
shape_patterns AS (
    SELECT
        transformed_lines,
        arrayMap(
            line -> arrayMap(
                char -> toUInt8(char),
                ngrams(line, 1)
            ),
            arraySlice(transformed_lines, 2)
        ) AS shape_grid
    FROM parsed_shapes
),

-- Calculate area needed for each shape
shape_areas AS (
    SELECT groupArray(
        arrayCount(
            cell -> cell = 1,
            arrayFlatten(shape_grid)
        )
    ) AS areas_per_shape
    FROM shape_patterns
),

-- Parse region specifications
parsed_regions AS (
    SELECT
        arrayJoin(
            arrayMap(
                line -> splitByString(': ', line),
                region_lines
            )
        ) AS region_parts
    FROM regions_section
),

-- Calculate region dimensions and requested volumes
region_specifications AS (
    SELECT
        region_parts,
        
        -- Calculate total region area (product of dimensions)
        arrayProduct(
            arrayMap(
                dim -> toUInt32(dim),
                splitByChar('x', region_parts[1])
            )
        ) AS total_region_area,
        
        -- Extract requested volumes for each shape
        arrayMap(
            vol -> toUInt8(vol),
            splitByChar(' ', region_parts[2])
        ) AS requested_shape_volumes
    FROM parsed_regions
),

-- Check if each region can fit the requested shapes
region_fit_analysis AS (
    SELECT
        total_region_area,
        requested_shape_volumes,
        areas_per_shape,
        
        -- Calculate total area needed: sum of (volume * area) for each shape
        arraySum(
            (volume, area) -> volume * area,
            requested_shape_volumes,
            areas_per_shape
        ) AS total_area_needed,
        
        -- Check if shapes fit in region
        total_area_needed <= total_region_area AS shapes_fit
    FROM region_specifications
    CROSS JOIN shape_areas
),

-- Count regions where shapes fit
solution AS (
    SELECT countIf(shapes_fit) AS solution
    FROM region_fit_analysis
)

-- Return final answer
SELECT solution -- 463 with my input
FROM solution