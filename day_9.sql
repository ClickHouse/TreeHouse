-- Define puzzle input 
WITH '...' AS input,

-- Parse 2D coordinate points
parsed_points AS (
    SELECT *
    FROM format('CSV', 'x Float64, y Float64', input)
),

-- Generate all unique pairs of points
point_pairs AS (
    SELECT
        c1.x AS x1,
        c1.y AS y1,
        c2.x AS x2,
        c2.y AS y2
    FROM parsed_points AS c1
    CROSS JOIN parsed_points AS c2
    WHERE (c1.x, c1.y) < (c2.x, c2.y)
),

-- Create bounding box polygons for each pair
bounding_boxes AS (
    SELECT
        x1,
        y1,
        x2,
        y2,
        
        -- Exact bounding box (corners at point coordinates)
        [
            (least(x1, x2), least(y1, y2)),        -- bottom-left
            (least(x1, x2), greatest(y1, y2)),     -- top-left
            (greatest(x1, x2), greatest(y1, y2)),  -- top-right
            (greatest(x1, x2), least(y1, y2)),     -- bottom-right
            (least(x1, x2), least(y1, y2))         -- close the ring
        ]::Ring AS exact_bounds,
        
        -- Expanded bounding box (extends 0.5 units beyond points)
        [
            (least(x1, x2) - 0.5, least(y1, y2) - 0.5),        -- bottom-left
            (least(x1, x2) - 0.5, greatest(y1, y2) + 0.5),     -- top-left
            (greatest(x1, x2) + 0.5, greatest(y1, y2) + 0.5),  -- top-right
            (greatest(x1, x2) + 0.5, least(y1, y2) - 0.5),     -- bottom-right
            (least(x1, x2) - 0.5, least(y1, y2) - 0.5)         -- close the ring
        ]::Ring AS expanded_bounds
    FROM point_pairs
),

-- Create polygon containing all points (for Part 2 containment test)
all_points_array AS (
    SELECT groupArray((x, y)) AS points_array
    FROM parsed_points
),

all_points_polygon AS (
    SELECT arrayPushBack(points_array, points_array[1])::Ring AS ring
    FROM all_points_array
),

-- Part 1: Find largest bounding box by area
part1_candidates AS (
    SELECT
        x1,
        y1,
        x2,
        y2,
        exact_bounds,
        expanded_bounds,
        polygonAreaCartesian(expanded_bounds) AS area
    FROM bounding_boxes
    ORDER BY area DESC
    LIMIT 1
),

part1_solution AS (
    SELECT area AS solution
    FROM part1_candidates
),

-- Part 2: Find largest bounding box that contains all points
part2_candidates AS (
    SELECT
        bb.x1,
        bb.y1,
        bb.x2,
        bb.y2,
        
        -- Create slightly inset test bounds (0.01 units inside)
        (least(x1, x2) + 0.01, least(y1, y2) + 0.01) AS bottom_left,
        (least(x1, x2) + 0.01, greatest(y1, y2) - 0.01) AS top_left,
        (greatest(x1, x2) - 0.01, greatest(y1, y2) - 0.01) AS top_right,
        (greatest(x1, x2) - 0.01, least(y1, y2) + 0.01) AS bottom_right,
        
        -- Create test bounds polygon
        [
            bottom_left,
            top_left,
            top_right,
            bottom_right,
            bottom_left
        ]::Ring AS test_bounds,
        
        -- Check if all points are within test bounds
        polygonsWithinCartesian(test_bounds, app.ring) AS all_points_contained,
        
        polygonAreaCartesian(bb.expanded_bounds) AS area
    FROM bounding_boxes AS bb
    CROSS JOIN all_points_polygon AS app
    WHERE all_points_contained != 0
    ORDER BY area DESC
    LIMIT 1
),

part2_solution AS (
    SELECT area AS solution
    FROM part2_candidates
)

-- Combine results from both parts
SELECT
    'Part 1' AS part,
    solution AS area -- 4739623064 with my input
FROM part1_solution

UNION ALL

SELECT
    'Part 2' AS part,
    solution AS area -- 1654141440 with my input
FROM part2_solution
