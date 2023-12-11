DECLARE @input varchar(max)='.......................................................................................#........................................#..........#
..........#.....#.........................#..................................#..............#...............................................
.......................#.........................#.....#......#....................................#.......................#................
............................................................................................................................................
........................................................................#...................................................................
.................................#...............................................#.............#...............#.......................#....
..#.............................................................#...........................................................................
..........................................#.......#........................................................#................................
....................................................................#...............................#....................#..................
......#......................#..............................................................................................................
...........................................................#....................................................................#...........
#................#...........................................................#......#.....#.....#....................#......................
.......................#.............#...............#..................#...................................................................
..........#....................#..............................................................................#............#............#...
.............................................#.....................................................................................#........
......#............................................................................................................#........................
...................................#................................#......................#................................................
..#..........#......#.......................................................................................................................
.......................................................#.....#..................................#....................................#......
.................................................#......................................#.............#.........................#...........
.......................................#...................................#...................................#............................
....#...............................................................................................................#......#...............#
...........#.........................................#.............................#........................................................
................................#...........................................................................#...............................
.......#.............................#........................#...............................#.........................................#...
..............#..........#.................#............#.....................#.............................................................
...#..............................................................#.....................................................#...................
............................................................................................................................................
................................................#................................#............................................#.............
..........#.....................................................................................................#...........................
......................#.................................................#................................#.........................#........
......#..........................#......................................................................................................#...
..........................#...............#..........#.....................................#................................................
..............................................................................#.................#...........................................
....................#................#.......................#.......#....................................................#................#
....#.............................................................................#.................................#.......................
................#.......................................#.............................................#......#..............................
........#...................................................................#...............................................................
..........................................#.......#.........................................................................#...............
....................................................................#...........................#.....................#.....................
.#.................#.....#............#........................#.................................................................#......#...
.............................................#........#...................#........#........................................................
...............#........................................................................#...................................................
....#............................................#......................................................#...........................#.......
...........#.........#............#..........................#.................#................................#.........#.................
.............................#.............#......................#.........................#...................................#...........
#.....................................#.....................................................................................................
...................................................................................#..............#....................#..................#.
..........................#...........................................#...................................#.................................
............................................................................................................................................
......................................................#.......................#.......#.....................................................
....................................#.......#....................#..........................................................................
...#................#.......................................................................#................#.................#............
.............................#........................................................................#...................#............#....
..........#..............................#.......#.....................#........#...............#...........................................
..............................................................#...................................................................#.........
...........................................................................................................#.................#..............
.................#......#...........#.................#............#..................#............................#........................
.....#...............................................................................................#......................................
............#..................................................................................................#.......#...............#....
................................#.........#.................................#...............................................................
................................................#..........#.......................#........................................................
.#.................#.............................................................................#..................#.............#.........
........................#............#..................................#................#..................................................
......#...............................................................................................#......#...........................#..
.....................................................................................#..................................#...................
..........#..........................................#...........#............................................................#.............
.............................................................................................#....................#.........................
.......................................................................................................................................#....
....#................#.................#........#...........................................................#..............#................
............................................................................................................................................
............................................................................................................................................
..............#.........#............................................................#.................................#....................
.............................#................................#....................................#........................................
.......................................................#...................................#.................#..............................
.....................#..................................................................................................................#...
...#.................................#.............#................................................................#........#..............
............................................................#...............................................................................
.......#....................................................................................................................................
.............................#.........................................................................................#..........#.......#.
.....................................................#...........................................#..........................................
..........................................#...........................#.........#...........................................................
..................#...................................................................#......................#..............................
.......................#.......................#...................................................................#......#.................
#............#..................#...........................................#........................#......................................
.....................................#............................#.........................................................................
............................................................................................#............#.....#..................#.........
..........................................#...................#....................#........................................#...............
..................................................#.........................................................................................
.....#............#...............................................................................................#....................#....
......................................................#.......................................#.............................................
..............................#..............#..............................................................................................
......................................#................................#.................................#............#........#...........#
...#..........#.....#...........................................................#...........................................................
.....................................................................................#.....#......#........................#................
.......................................................#...........#..............................................................#.........
............................................#..............................#.............................................................#..
................#..........#.................................................................................#..............................
......................................#..............................................................#......................................
#.......#...............................................................#.............................................#...............#.....
..........................................#....................................................#............................................
....#.................#................................................................#....................................................
...............#.............#..................................................................................#.........#..............#..
....................................#..............................................................#...............................#........
............................................................................................................................................
......#.............#.............................................#.............#...........................................................
...........................#............................................................................#.........#.........................
#......................................#....................................................#...........................#..............#....
...............................................#.....#......................................................................................
.............#.........#......#....................................................................................................#........
..............................................................#.....#............#..........................................................
.........#...............................................................................................................................#..
......................................#.....#...............................#...........#....................#..............................
.....................................................................................................#..............#.......................
....#.......................#.....#.................................................#.......................................................
...........................................................................................................................#.....#..........
.................#........................#......................................................................#..........................
.#.................................................................#..........#..........#..............#...................................
.......................................................#.....#..............................................................................
.........#.....................................#...................................................#.........#..............................
.................................#...............................................#.....................................#.............#.....#
.........................#..................................................................................................................
....................#.................................................#.....#...................................#...............#...........
...................................................#...........#.............................#..............................................
....................................................................................#..................#....................................
....#...........#......................#...............#....................................................................................
.........#........................................................................................#...................#...................#.
......................#......#.............................................................#................................................
#..............................................................................#............................................................
..............#....................#.........................................................................................#......#.......
.................................................#...................#...............................#......................................
....................#......#..................................#...........#.......#....................................#....................
..........#.....................................................................................................#...........................
.....#...................................................#.....................................................................#............
........................#.......#......#......#..................#........................................................................#.
.............................................................................#.............................#................................
..............#........................................................................#....................................................
.....................#.............#...................#.........................#..........#...............................................
.............................#............#....................#.........#.......................#..................................#.......
........................................................................................................#...................................';


/*
SET @input='...#......
.......#..
#.........
..........
......#...
.#........
.........#
..........
.......#..
#...#.....';
*/



DECLARE @width int=PATINDEX('%['+CHAR(13)+CHAR(10)+']%', @input)-1;
SET @input=REPLACE(REPLACE(@input, CHAR(10), ''), CHAR(13), '');

DROP TABLE IF EXISTS #map;

CREATE TABLE #map (
    x           bigint NOT NULL,
    y           bigint NOT NULL,
    galaxy_no   int NULL,
    PRIMARY KEY CLUSTERED (y, x)
);

CREATE INDEX galaxies ON #map (galaxy_no) INCLUDE (y, x) WHERE (galaxy_no IS NOT NULL);





--- Part 1:

INSERT INTO #map (x, y, galaxy_no)
SELECT x.[value], y.[value],
       (CASE WHEN s.symbol IS NOT NULL
             THEN SUM((CASE WHEN s.symbol IS NOT NULL THEN 1 ELSE 0 END)) OVER (ORDER BY y.[value], x.[value] ROWS UNBOUNDED PRECEDING)
             END)
FROM GENERATE_SERIES(1, @width, 1) AS x
CROSS JOIN GENERATE_SERIES(1, CAST(LEN(@input)/@width AS int), 1) AS y
CROSS APPLY (VALUES (NULLIF(SUBSTRING(@input, @width*(y.[value]-1)+x.[value], 1), '.'))) AS s(symbol);


--- Shift empty x columns to the right:
UPDATE map
SET map.x=map.x+sub.shift_len
FROM #map AS map
INNER JOIN (
    SELECT x AS from_x,
        LEAD(x, 1, 32000) OVER (ORDER BY x)-1 AS to_x,
        COUNT(*) OVER (ORDER BY x ROWS UNBOUNDED PRECEDING) AS shift_len
    FROM #map
    GROUP BY x
    HAVING COUNT(galaxy_no)=0) AS sub ON map.x BETWEEN sub.from_x AND sub.to_x;


--- Shift empty y rows down:
UPDATE map
SET map.y=map.y+sub.shift_len
FROM #map AS map
INNER JOIN (
    SELECT y AS from_y,
        LEAD(y, 1, 32000) OVER (ORDER BY y)-1 AS to_y,
        COUNT(*) OVER (ORDER BY y ROWS UNBOUNDED PRECEDING) AS shift_len
    FROM #map
    GROUP BY y
    HAVING COUNT(galaxy_no)=0) AS sub ON map.y BETWEEN sub.from_y AND sub.to_y;


--- Result:
SELECT SUM(ABS(a.x-b.x)+ABS(a.y-b.y))
FROM #map AS a
INNER JOIN #map AS b ON a.galaxy_no>b.galaxy_no
WHERE a.galaxy_no IS NOT NULL
  AND a.galaxy_no IS NOT NULL;







--- Part 2:



--- Introduce a scale variable:
DECLARE @scale int=1000000;


--- Start over:
TRUNCATE TABLE #map;

INSERT INTO #map (x, y, galaxy_no)
SELECT x.[value], y.[value],
       (CASE WHEN s.symbol IS NOT NULL
             THEN SUM((CASE WHEN s.symbol IS NOT NULL THEN 1 ELSE 0 END)) OVER (ORDER BY y.[value], x.[value] ROWS UNBOUNDED PRECEDING)
             END)
FROM GENERATE_SERIES(1, @width, 1) AS x
CROSS JOIN GENERATE_SERIES(1, CAST(LEN(@input)/@width AS int), 1) AS y
CROSS APPLY (VALUES (NULLIF(SUBSTRING(@input, @width*(y.[value]-1)+x.[value], 1), '.'))) AS s(symbol);


--- Shift empty x columns to the right (@scale number of columns):
UPDATE map
SET map.x=map.x+(@scale-1)*sub.shift_len
FROM #map AS map
INNER JOIN (
    SELECT x AS from_x,
        LEAD(x, 1, 32000) OVER (ORDER BY x)-1 AS to_x,
        COUNT(*) OVER (ORDER BY x ROWS UNBOUNDED PRECEDING) AS shift_len
    FROM #map
    GROUP BY x
    HAVING COUNT(galaxy_no)=0) AS sub ON map.x BETWEEN sub.from_x AND sub.to_x;


--- Shift empty y rows down (@scale number of rows):
UPDATE map
SET map.y=map.y+(@scale-1)*sub.shift_len
FROM #map AS map
INNER JOIN (
    SELECT y AS from_y,
        LEAD(y, 1, 32000) OVER (ORDER BY y)-1 AS to_y,
        COUNT(*) OVER (ORDER BY y ROWS UNBOUNDED PRECEDING) AS shift_len
    FROM #map
    GROUP BY y
    HAVING COUNT(galaxy_no)=0) AS sub ON map.y BETWEEN sub.from_y AND sub.to_y;


--- Result:
SELECT SUM(ABS(a.x-b.x)+ABS(a.y-b.y))
FROM #map AS a
INNER JOIN #map AS b ON a.galaxy_no>b.galaxy_no
WHERE a.galaxy_no IS NOT NULL
  AND a.galaxy_no IS NOT NULL;

