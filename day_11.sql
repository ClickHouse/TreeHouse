WITH RECURSIVE

-- Define puzzle input 
'...' AS input_raw,

-- Define key node identifiers
key_nodes AS (
    SELECT
        cityHash64('svr') AS svr_node,
        cityHash64('you') AS you_node,
        cityHash64('dac') AS dac_node,
        cityHash64('fft') AS fft_node,
        cityHash64('out') AS out_node
),

-- Parse input connections
raw_connections AS (
    SELECT splitByString(': ', raw) AS parsed_parts
    FROM format('TSV', 'raw String', input_raw)
),

parsed_connections AS (
    SELECT
        parsed_parts[1] AS input_node,
        splitByWhitespace(parsed_parts[2]) AS output_nodes
    FROM raw_connections
),

-- Create graph edges with hashed node IDs
graph_edges AS (
    SELECT
        cityHash64(input_node) AS from_node,
        cityHash64(arrayJoin(output_nodes)) AS to_node
    FROM parsed_connections
),

-- Part 2: Count paths from 'svr' to 'out' that visit both 'dac' and 'fft'
paths_from_svr AS (
    -- Base case: start at 'svr' node
    SELECT
        0 AS generation,
        svr_node AS current_node,
        0::UInt8 AS visited_dac,
        0::UInt8 AS visited_fft,
        1::UInt64 AS paths_count
    FROM key_nodes
    
    UNION ALL
    
    -- Recursive case: traverse edges and track checkpoint visits
    SELECT
        generation,
        current_node,
        visited_dac,
        visited_fft,
        sum(paths_count) AS paths_count
    FROM (
        SELECT
            paths.generation + 1 AS generation,
            edges.to_node AS current_node,
            paths.visited_dac OR (edges.to_node = kn.dac_node) AS visited_dac,
            paths.visited_fft OR (edges.to_node = kn.fft_node) AS visited_fft,
            paths.paths_count AS paths_count
        FROM paths_from_svr paths
        JOIN graph_edges edges ON edges.from_node = paths.current_node
        CROSS JOIN key_nodes kn
        WHERE
            edges.to_node != kn.out_node
            AND paths.generation < 628
    )
    GROUP BY generation, current_node, visited_dac, visited_fft
),

-- Part 1: Count all paths from 'you' to 'out'
paths_from_you AS (
    -- Base case: start at 'you' node
    SELECT
        0 AS generation,
        you_node AS current_node,
        1::UInt64 AS paths_count
    FROM key_nodes
    
    UNION ALL
    
    -- Recursive case: traverse edges
    SELECT
        generation,
        current_node,
        sum(paths_count) AS paths_count
    FROM (
        SELECT
            paths.generation + 1 AS generation,
            edges.to_node AS current_node,
            paths.paths_count AS paths_count
        FROM paths_from_you paths
        JOIN graph_edges edges ON edges.from_node = paths.current_node
        CROSS JOIN key_nodes kn
        WHERE
            edges.to_node != kn.out_node
            AND paths.generation < 628
    )
    GROUP BY generation, current_node
),

-- Part 1 solution: paths from 'you' to 'out'
part1_solution AS (
    SELECT sum(paths.paths_count) AS solution
    FROM paths_from_you paths
    JOIN graph_edges edges ON edges.from_node = paths.current_node
    CROSS JOIN key_nodes kn
    WHERE edges.to_node = kn.out_node
),

-- Part 2 solution: paths from 'svr' to 'out' visiting both checkpoints
part2_solution AS (
    SELECT sum(paths.paths_count) AS solution
    FROM paths_from_svr paths
    JOIN graph_edges edges ON edges.from_node = paths.current_node
    CROSS JOIN key_nodes kn
    WHERE
        edges.to_node = kn.out_node
        AND paths.visited_dac = 1
        AND paths.visited_fft = 1
),

solutions_combined as (
SELECT 
    'Part 1' AS part,
    (SELECT solution FROM part1_solution) AS solution -- 724 with my input

UNION ALL

SELECT 
    'Part 2' AS part,
    (SELECT solution FROM part2_solution) AS solution -- 473930047491888 with my input
)

SELECT * FROM solutions_combined;