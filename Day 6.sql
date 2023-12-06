DECLARE @input varchar(max)='Time:        54     94     65     92
Distance:   302   1476   1029   1404';

DECLARE @sum bigint;

WITH inputs AS (
    SELECT race,
        MAX((CASE WHEN row_no=1 THEN [value] END)) AS [time],
        MAX((CASE WHEN row_no=2 THEN [value] END)) AS distance
    FROM (
        SELECT source.ordinal AS row_no,
            ROW_NUMBER() OVER (PARTITION BY source.ordinal ORDER BY cols.ordinal) AS race,
            TRY_CAST(cols.[value] AS int) AS [value]
        FROM STRING_SPLIT(REPLACE(@input, CHAR(13), ''), CHAR(10), 1) AS source
        CROSS APPLY STRING_SPLIT(source.[value], ' ', 1) AS cols
        WHERE cols.[value]!=''
        AND cols.ordinal>1
        ) AS sub
    GROUP BY race)

/*
    Effectively, distance=(totalTime-chargeTime)*chargeTime, or d=c(t-c), so
    we have a upside-down parable, for which we want to find the two points
    where distance>record (r):

    (t-c)c-r>0

    So let's find the two roots of this parable by completing the square
    https://en.wikipedia.org/wiki/Completing_the_square

    -c2+ct-r=0

    c2-ct=-r

    c2-ct-(t/2)2=(t/2)2-r

    (c+t/2)2=(t/2)2-r

    c+t/2 = ±sqrt( (t/2)2-r )

    => first root:  c=0.5t+sqrt( (t/2)2-r )
       second root: c=0.5t-sqrt( (t/2)2-r )

*/


--- Part 1:


SELECT @sum=ISNULL(@sum, 1)*(
        1+( FLOOR(0.5*[time]+SQRT(POWER(0.5*[time], 2)-distance))-
          CEILING(0.5*[time]-SQRT(POWER(0.5*[time], 2)-distance))))
FROM inputs;

SELECT @sum;








--- Part 2:

DECLARE @time bigint, @distance bigint;

SELECT @time    =MAX((CASE WHEN source.ordinal=1 THEN CAST(REPLACE(v.[value], ' ', '') AS bigint) END)),
       @distance=MAX((CASE WHEN source.ordinal=2 THEN CAST(REPLACE(v.[value], ' ', '') AS bigint) END))
FROM STRING_SPLIT(REPLACE(@input, CHAR(13), ''), CHAR(10), 1) AS source
CROSS APPLY STRING_SPLIT(source.[value], ':', 1) AS v
WHERE v.ordinal=2;

SELECT 1+(FLOOR(0.5*@time+SQRT(POWER(0.5*@time, 2)-@distance))-
       CEILING(0.5*@time-SQRT(POWER(0.5*@time, 2)-@distance)));
