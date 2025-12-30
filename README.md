# Advent of Code 2025 Pure ClickHouse SQL Solutions


### The Rules

To ensure we didn't take any shortcuts, we imposed three strict rules on our solutions:

1. **Pure ClickHouse SQL Only**: we allowed absolutely no User Defined Functions (UDFs), and specifically no *executable* UDFs that would allow us to "cheat" by shelling out to Python or Bash. If the query engine couldn't do it natively, we couldn't do it.  
     
2. **Raw Inputs Only:** in Advent of Code, the input is often a messy text file.  Sometimes a list of numbers, sometimes an ASCII art map, or a block of cryptic instructions. We were not allowed to pre-process this data. The solution query must accept the raw puzzle input string exactly as provided by the AoC challenge and parse it within the query.  
     
3. **"Single Query" Constraint:** this is the hardest rule of all. We were not allowed to create tables, materialized views, or temporary tables to store intermediate state. The entire puzzle—from parsing the input, to solving Part 1, to solving the (often substantially more complex) Part 2—must be executed as **a single, atomic query**. This required us to rely heavily on CTEs to chain our logic together in one uninterrupted execution.



### Day 1: The Secret Entrance

**The Puzzle:** The elves have locked their secret entrance with a rotating dial safe. The puzzle involves simulating the movement of a dial labeled 0-99 based on a sequence of instructions like `L68` (turn left 68 clicks) or `R48` (turn right 48 clicks).

- **Part 1** asks for the final position of the dial after all rotations, starting from 50\.  
- **Part 2** requires a more complex simulation: counting exactly how many times the dial points to `0` *during* the entire process, including intermediate clicks as it rotates past zero multiple times.

**How we solved this in ClickHouse SQL:** We treated this simulation as a stream processing problem rather than a procedural loop. Since the state of the dial depends entirely on the history of moves, we can calculate the cumulative position for every single instruction at once. We parsed the directions into positive (Right) and negative (Left) integers, then used a window function to create a running total of steps. For Part 2, where we needed to detect "zero crossings," we compared the current running total with the previous row's total to determine if the dial passed 0\.

**Implementation details:**

1. **[`sum() OVER (...)`](https://clickhouse.com/docs/en/sql-reference/window-functions)**: We used standard SQL window functions to maintain the "running total" of the dial's position. By normalizing the left/right directions into positive/negative values, we tracked the cumulative position for every row in a single pass.

```sql
sum(normalized_steps) OVER (ORDER BY instruction_id) AS raw_position
```

2. **[`lagInFrame`](https://clickhouse.com/docs/en/sql-reference/window-functions)**: To count how many times we passed zero, we needed to know where the dial *started* before the current rotation. We used `lagInFrame` to peek at the `position` from the previous row. This allowed us to compare the start and end points of a rotation and mathematically determine if `0` fell between them.

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_1_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_1.sql)

---

### Day 2: The Gift Shop

**The Puzzle:** You are helping clean up a gift shop database filled with invalid product IDs. The input is a list of ID ranges (e.g., `11-22, 95-115`).

- **Part 1** defines an invalid ID as one composed of a sequence repeated exactly twice (like `1212` or `55`).  
- **Part 2** expands this to any sequence repeated *at least* twice (like `123123123` or `11111`). The goal is to sum up all invalid IDs found within the given ranges.

**How we solved this in ClickHouse SQL:** Instead of writing a loop to iterate through numbers, we leaned on ClickHouse's ability to "explode" data. We took the compact input ranges (like `11-22`) and instantly expanded them into millions of individual rows—one for every integer in the range. Once we had a row for every potential ID, we converted them to strings and applied array functions to check for the repeating patterns in parallel.

**Implementation details:**

1. **[`arrayJoin`](https://clickhouse.com/docs/en/sql-reference/functions/array-functions#arrayjoin)**: This function is our staple for generating rows. We used `range(start, end)` to create an array of integers for each input line, and `arrayJoin` to explode that array into separate rows. This made filtering for invalid IDs a simple `WHERE` clause operation.

```sql
SELECT arrayJoin(range(bounds[1], bounds[2] + 1)) AS number
```

2. **[`arrayExists`](https://clickhouse.com/docs/en/sql-reference/functions/higher-order-functions#arrayexists)**: For Part 2, we had to check if *any* substring length (from 1 up to the string length) formed a repeating pattern. We used `arrayExists` with a lambda function to check every possible substring length. If the lambda returns 1 for any length, the ID is flagged.

```sql
arrayExists(
    x -> (string_length % x = 0) AND (repeat(substring(..., x), ...) = number_string),
    range(1, string_length)
)
```

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_2_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_2.sql)

---

### Day 3: The Lobby

**The Puzzle:** You need to jumpstart an escalator using banks of batteries, where each bank is a string of digits (e.g., `987654321`).

- **Part 1** asks you to pick exactly **two** batteries (digits) to form the largest possible 2-digit number, preserving their original relative order.  
- **Part 2** scales this up: pick exactly **12** batteries to form the largest possible 12-digit number. This becomes a greedy optimization problem—you always want the largest available digit that still leaves enough digits after it to complete the sequence.

**How we solved this in ClickHouse SQL:** Part 1 was a straightforward string manipulation, but Part 2 required us to maintain state while iterating through the digits. We needed to track how many digits we still needed to find and our current position in the string so we wouldn't pick digits out of order. We implemented this greedy algorithm directly in SQL using `arrayFold`, which allowed us to iterate through the digits while carrying an accumulator tuple containing our current constraints.

**Implementation details:**

1. **[`arrayFold`](https://clickhouse.com/docs/en/sql-reference/functions/higher-order-functions#arrayfold)**: We used this higher-order function to implement `reduce()`\-style logic. Our accumulator stored a tuple: `(digits_remaining, current_position, accumulated_value)`. For every step of the fold, we calculated the best valid digit to pick next and updated the state tuple accordingly.

```sql
arrayFold(
    (accumulator, current_element) -> ( ... ), -- Update logic
    digits,
    (num_digits_needed, 0, 0) -- Initial state
)
```

2. **[`ngrams`](https://clickhouse.com/docs/en/sql-reference/functions/string-functions#ngrams)**: To process the string of digits as an array, we used `ngrams(string, 1)`. While typically used for text analysis, here it served as a convenient way to split a string into an array of single characters, which we then cast to integers for the `arrayFold` operation.

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_3_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_3.sql)

---

### Day 4: The Printing Department

**The Puzzle:** The elves need to break through a wall of paper rolls. The puzzle is a variation of Conway's Game of Life. You are given a grid where `@` represents a roll of paper.

- **Part 1** defines a rule: a roll can be "accessed" (removed) if it has fewer than 4 neighbors. You count how many rolls fit this criteria initially.  
- **Part 2** asks to simulate this process recursively. Removing a roll might open up access to others. You need to keep removing accessible rolls until the system stabilizes, then count the total removed.

**How we solved this in ClickHouse SQL:** Since this problem required iterative simulation where each step depended on the previous one, we used a Recursive CTE. We represented the grid as a set of `(x, y)` coordinates. In each recursive step, we performed a self-join to count the neighbors for every point. We filtered the list to keep only the points that "survived" (had \>= 4 neighbors), implicitly removing the others. We continued this recursion until the count of points stopped changing.

**Implementation details:**

1. **[`WITH RECURSIVE`](https://clickhouse.com/docs/en/sql-reference/statements/select/with#recursive-cte)**: We used the standard SQL recursive CTE to handle the graph traversal. The base case selected all initial paper roll positions. The recursive step filtered that set down based on neighbor counts.

```sql
WITH RECURSIVE recursive_convergence AS (
    -- Base case: all points
    UNION ALL
    -- Recursive step: keep points with >= 4 neighbors
    SELECT ... HAVING countIf(...) >= 4
)
```

2. **[`argMin`](https://clickhouse.com/docs/en/sql-reference/aggregate-functions/reference/argmin)**: To find the exact moment the simulation stabilized, we tracked the point count at every depth of the recursion. We used `argMin(point_count, depth)` to retrieve the count of remaining points exactly at the minimum depth where the count stopped changing.

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_4_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_4.sql)

---

### Day 5: The Cafeteria

**The Puzzle:** The elves have an inventory problem involving lists of "fresh" ID ranges (e.g., `3-5`, `10-14`).

- **Part 1** asks how many specific item IDs fall into *any* of the fresh ranges.  
- **Part 2** asks for the total count of unique integers covered by the fresh ranges (the union of all intervals). For example, if you have ranges `1-5` and `3-7`, the union is `1-7` (size 7), not `1-5` \+ `3-7` (size 10).

**How we solved this in ClickHouse SQL:** This is a classic interval intersection problem. While Part 1 was a simple filter, Part 2 required merging overlapping intervals. Merging intervals can be mathematically complex to implement manually, but we utilized a specialized ClickHouse aggregation function designed exactly for this purpose, turning a complex geometric algorithm into a one-liner.

**Implementation details:**

1. **[`intervalLengthSum`](https://clickhouse.com/docs/en/sql-reference/aggregate-functions/reference/intervallengthsum)**: We used this specialized aggregate function to calculate the total length of the union of intervals. It automatically handles overlapping and nested ranges, saving us from writing complex merging logic.

```sql
SELECT intervalLengthSum(range_tuple.1, range_tuple.2) AS solution
```

2. **[`arrayExists`](https://clickhouse.com/docs/en/sql-reference/functions/higher-order-functions#arrayexists)**: For Part 1, we used `arrayExists` to check if a specific ID fell within *any* of the valid ranges in the array. This allowed us to perform the check efficiently without exploding the ranges into billions of individual rows.

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_5_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_5.sql)

---

### Day 6: The Trash Compactor

**The Puzzle:** You find a math worksheet with problems arranged in columns.

- **Part 1** interprets the input as columns of numbers separated by spaces. You need to sum or multiply the numbers in each column based on the operator at the bottom.  
- **Part 2** reveals the input is written "right-to-left" in columns, where digits of a single number are stacked vertically. You must re-parse the grid to reconstruct the numbers, group them by blank columns, and apply the operators.

**How we solved this in ClickHouse SQL:** This puzzle was all about parsing and array manipulation. We treated the input text as a 2D matrix of characters. To switch from the row-based text file to the column-based math problems, we essentially performed a "matrix transposition." We converted the rows of text into arrays of characters, "rotated" them to process columns, and then used array functions to reconstruct the numbers and apply the math operations.

**Implementation details:**

1. **[`splitByWhitespace`](https://clickhouse.com/docs/en/sql-reference/functions/string-functions#splitbywhitespace)**: In Part 1, we used this function to robustly parse the "horizontal" representation. It automatically handled the variable spacing between columns, which would have tripped up simple string splitting.  
     
2. **[`arrayProduct`](https://clickhouse.com/docs/en/sql-reference/functions/array-functions#arrayproduct)**: Since ClickHouse lacks a standard `product()` aggregate function, we mapped our columns to arrays of integers and used `arrayProduct` to calculate the multiplication results.

```sql
toInt64(arrayProduct(
    arrayMap(x -> toInt64(x), arraySlice(column, 1, length(column) - 1))
))
```

3. **[`arraySplit`](https://clickhouse.com/docs/en/sql-reference/functions/array-functions#arraysplit)**: For Part 2, after extracting the raw digits, we needed to group them into valid expressions. We used `arraySplit` to break the large array into chunks whenever we encountered an operator column, effectively separating the mathematical problems.

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_6_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_6.sql)

---

### Day 7: The Teleporter Lab

**The Puzzle:** You are analyzing a tachyon beam in a grid.

- **Part 1** simulates a beam moving downwards. When it hits a splitter `^`, it splits into two beams (left and right). You count the total splits.  
- **Part 2** introduces a "quantum many-worlds" twist: instead of splitting the beam, the universe splits. You need to calculate the total number of active "timelines" (paths) at the bottom of the grid.

**How we solved this in ClickHouse SQL:** Simulating individual paths would have caused an exponential explosion. Instead, we approached this like a wave propagation simulation (similar to calculating Pascal's triangle). We processed the grid row-by-row using `arrayFold`. For each row, we maintained a map of "active world counts" at each column position and calculated how the counts flowed into the next row based on the splitters.

**Implementation details:**

1. **[`arrayFold`](https://clickhouse.com/docs/en/sql-reference/functions/higher-order-functions#arrayfold)**: We used `arrayFold` to implement the row-by-row simulation state machine. We carried a complex state object—`(left_boundary, right_boundary, worlds_map, part1_counter)`—and updated it for each row of the grid.  
     
2. **[`sumMap`](https://clickhouse.com/docs/en/sql-reference/functions/map-functions)**: To handle beams merging (e.g., a left branch and a right branch meeting at the same spot), we used `sumMap`. This allowed us to aggregate values for identical keys in our world map, easily combining the counts of "timelines" converging on a single coordinate.

```sql
arrayReduce('sumMap', arrayMap(position -> map(...), ...))
```

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_7_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_7.sql)

---

### Day 8: The Playground

**The Puzzle:** The elves are connecting 3D electrical junction boxes.

- **Part 1** asks to connect the 1000 closest pairs of points and analyze the resulting circuit sizes (connected components).  
- **Part 2** asks to keep connecting the closest points until *all* boxes form a single giant circuit (a Minimum Spanning Tree problem).

**How we solved this in ClickHouse SQL:** This is a graph theory problem requiring a disjoint-set (union-find) approach. We generated all possible edges between points and sorted them by distance. Then, we used `arrayFold` to iterate through the edges, merging sets of points into connected components whenever an edge bridged two previously separate groups.

**Implementation details:**

1. **[`L2Distance`](https://clickhouse.com/docs/en/sql-reference/functions/distance-functions#l2distance)**: We used ClickHouse's native `L2Distance` function to efficiently calculate the Euclidean distance between 3D coordinates `[x, y, z]`, allowing us to sort the potential connections by length.  
     
2. **[`runningAccumulate`](https://clickhouse.com/docs/en/sql-reference/functions/other-functions#runningaccumulate)**: For Part 2, we needed to know when we had seen enough unique points to form a single circuit. Instead of running a slow `DISTINCT` count on every row, we used `uniqCombinedState` to create a compact sketch of unique elements, and `runningAccumulate` to merge these sketches row-by-row, providing a running count of unique points efficiently.

```sql
runningAccumulate(points_state) AS unique_points_seen
```

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_8_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_8.sql)

---

### Day 9: The Movie Theater

**The Puzzle:** The theater floor is a grid with some red tiles.

- **Part 1** asks for the largest area rectangle formed using two red tiles as opposite corners.  
- **Part 2** adds a constraint: the rectangle must fit entirely inside the loop formed by all the red/green tiles.

**How we solved this in ClickHouse SQL:** We treated this as a geometry problem rather than a grid search. We constructed polygons representing the candidate rectangles and the boundary loop. By converting the bounding boxes into "rings," we could use ClickHouse's native geometry functions to calculate areas and check for containment.

**Implementation details:**

1. **[`polygonAreaCartesian`](https://clickhouse.com/docs/en/sql-reference/functions/geometry-functions#polygonareacartesian)**: We avoided manual width/height calculations by constructing polygon objects for our rectangles and using `polygonAreaCartesian` to compute their area directly.  
     
2. **[`polygonsWithinCartesian`](https://clickhouse.com/docs/en/sql-reference/functions/geometry-functions#polygonswithincartesian)**: To check if a rectangle fit inside the loop, we used this containment function. We applied a clever trick here: because geometric functions can be tricky about points shared exactly on an edge, we constructed a slightly **inset** version of the candidate rectangle (shrunk by 0.01 units). This ensured the containment check strictly validated that the rectangle fit *inside* the boundary polygon without edge alignment errors.

```sql
-- Create slightly inset test bounds (0.01 units inside)
(least(x1, x2) + 0.01, least(y1, y2) + 0.01) AS bottom_left, ...
polygonsWithinCartesian(test_bounds, all_points_ring)
```

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_9_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_9.sql)

---

### Day 10: The Factory

**The Puzzle:** You need to configure factory machines by pressing buttons.

- **Part 1** involves toggling lights (XOR logic) to match a pattern.  
- **Part 2** involves incrementing "joltage" counters to reach large target integers using the fewest button presses.

**How we solved this in ClickHouse SQL:** For Part 1, the search space was small enough that we could use brute-force enumeration. We generated every possible button combination and checked it using bitmasks. Part 2 required a smarter approach. We implemented a custom recursive halving algorithm in SQL. We iteratively subtracted button effects and "halved" the remaining target values, reducing the large target numbers down to zero step-by-step.

**Implementation details:**

1. **[`bitTest`](https://clickhouse.com/docs/en/sql-reference/functions/bit-functions)** and **[`bitCount`](https://clickhouse.com/docs/en/sql-reference/functions/bit-functions)**: We treated button combinations as binary integers. `bitTest` allowed us to check if a specific button was pressed in a combination, and `bitCount` instantly gave us the total number of presses (the cost).  
     
2. **[`ARRAY JOIN`](https://clickhouse.com/docs/en/sql-reference/statements/select/array-join)**: To generate the search space for Part 1, we created a range of integers (0 to `2^N`) and used `ARRAY JOIN` to explode them into rows. This instantly created a row for every possible permutation of button presses.

```sql
ARRAY JOIN range(0, toUInt32(pow(2, num_buttons)))
```

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_10_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_10.sql)

---

### Day 11: The Reactor

**The Puzzle:** You are debugging a reactor control graph.

- **Part 1** asks to count all distinct paths from `you` to `out`.  
- **Part 2** asks to count paths from `svr` to `out` that satisfy a constraint: they must visit *both* intermediate nodes `dac` and `fft`.

**How we solved this in ClickHouse SQL:** We solved this using a Recursive CTE to traverse the graph. To handle the constraint in Part 2, we carried "visited flags" in our recursion state. As we traversed the graph, we updated these boolean flags whenever we hit a checkpoint node. At the end, we simply filtered for paths where both flags were true.

**Implementation details:**

1. **[`cityHash64`](https://clickhouse.com/docs/en/sql-reference/functions/hash-functions#cityhash64)**: String comparisons can be slow in large recursive joins. We converted the node names (like `svr`, `dac`) into deterministic 64-bit integers using `cityHash64`. This made the join operations significantly faster and reduced memory usage.

```sql
cityHash64('svr') AS svr_node
```

2. **State Tracking**: We added boolean columns to our recursive table to track state. This allowed us to solve the "must visit X and Y" constraint in a single pass without needing complex post-processing.

```sql
paths.visited_dac OR (edges.to_node = kn.dac_node) AS visited_dac
```

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_11_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_11.sql)

---

### Day 12: Christmas Tree Farm

**The Puzzle:** Elves need to pack irregular presents (defined by `#` grids) into rectangular regions. This looks like a complex 2D bin-packing problem. However, the puzzle input allows for a heuristic shortcut: checking if the *total area* of the presents is less than or equal to the *total area* of the region is sufficient.

**How we solved this in ClickHouse SQL:** Since we could solve this with a volume check, our solution focused on parsing. We converted the ASCII art shapes into binary grids (arrays of 1s and 0s) and calculated the area (count of 1s) for each. We then multiplied the requested quantity of each present by its area and compared the sum to the region's total size.

**Implementation details:**

1. **[`replaceRegexpAll`](https://clickhouse.com/docs/en/sql-reference/functions/string-replace-functions#replaceregexpall)**: We used regex replacement to turn the visual `#` characters into `1` and `.` into `0`. This transformed the "art" into computable binary strings that we could parse into arrays.  
     
2. **[`arraySum`](https://clickhouse.com/docs/en/sql-reference/functions/array-functions#arraysum)**: We used the lambda version of `arraySum` to perform a "dot product" operation. We multiplied the volume of each present by its area and summed the results in a single, clean expression.

```sql
arraySum(
    (volume, area) -> volume * area,
    requested_shape_volumes,
    areas_per_shape
)
```

[View full puzzle description](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_12_puzzle.txt) | [View full SQL solution](https://github.com/ArctypeZach/ClickHouseAoC2025/blob/master/day_12.sql)