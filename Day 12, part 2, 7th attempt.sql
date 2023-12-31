--DROP FUNCTION dbo.Permutations
IF (OBJECT_ID('dbo.Permutations') IS NULL) EXEC('
CREATE OR ALTER FUNCTION dbo.Permutations (
    @map                varchar(200),
    @groups             varchar(200)
)
RETURNS @res TABLE (
    group_no            tinyint NOT NULL,
    permutations        bigint NOT NULL
)
AS

BEGIN;

RETURN;

END;
');

GO
ALTER FUNCTION dbo.Permutations (
    @map                varchar(200),
    @groups             varchar(200)
)
RETURNS @res TABLE (
    group_no            tinyint NOT NULL,
    permutations        bigint NOT NULL
)
AS

BEGIN;

DECLARE @group_count    tinyint=(SELECT COUNT(*) FROM STRING_SPLIT(@groups, ',', 1)),
        @group          tinyint,
        @map_len        smallint=LEN(@map);












--- Trim leading and trailing dots:
IF ('.' IN (LEFT(@map, 1), RIGHT(@map, 1)))
    SELECT @map=REPLACE(TRIM(REPLACE(@map, '.', ' ')), ' ', '.');

--- If we've exhausted the work queue, we're done here:
IF (LEN(@map)=0) BEGIN;
    INSERT INTO @res (group_no, permutations)
    SELECT @group_count-COUNT(*), 1
    FROM STRING_SPLIT(@groups, ',');

    RETURN;
END;




--- These are our groups:
DECLARE @group_table TABLE (
    group_no        tinyint NOT NULL,
    group_width     tinyint NOT NULL,
    minimum_space   smallint NOT NULL,
    PRIMARY KEY CLUSTERED (group_no)
);

INSERT INTO @group_table (group_no, group_width, minimum_space)
SELECT ordinal AS group_no, CAST([value] AS tinyint) AS group_width,
       SUM(CAST([value] AS int)+1) OVER (ORDER BY ordinal ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)-1
FROM STRING_SPLIT(@groups, ',', 1);

--- More helper variables
SELECT @group_count=(SELECT COUNT(*) FROM @group_table),
       @map_len=LEN(@map);









--- SHORTCUT: If the entire map is just "_", but there's more than one group,
--- we can use sciency things to compute the number of outcomes:
IF (@map NOT LIKE '%[^_]%' AND @map!='') BEGIN;

    INSERT INTO @res (group_no, permutations)
    SELECT x.k AS group_no,
           ROUND(ISNULL(nk.factorial/k.factorial, 1), 0) AS permutations
    FROM (
               --- k is the _number of_ values, not the total width
        SELECT CAST(@group_count AS int) AS k,
               --- n is the width of the map, corrected so that each value is 1 wide
               --- and allowing for at least one space between each value.
               CAST(@map_len-SUM(group_width)+1 AS int) AS n
        FROM @group_table AS ss
        HAVING SUM(minimum_space)<=@map_len
    ) AS x
    CROSS APPLY (
        SELECT ROUND(EXP(SUM(LOG(CAST([value] AS numeric(38, 18))))), 0) AS factorial
        FROM GENERATE_SERIES(1+x.n-x.k, x.n, 1)
        WHERE x.n>=x.k
        --AND LEN(@map)>=x.min_groups_length -- Already covered in HAVING in x
        GROUP BY ()
    ) AS nk
    CROSS APPLY (
        SELECT ROUND(EXP(SUM(LOG(CAST([value] AS numeric(38, 18))))), 0) AS factorial
        FROM GENERATE_SERIES(1, x.k, 1)
    ) AS k;

    --- If this calculation isn't valid, proceed with our regular scheduled programming.
    IF (@@ROWCOUNT>0)
        RETURN;
END;






--- Now we're going to brute-force what's left:

DECLARE @recursion TABLE (
    offset          smallint NOT NULL,
    group_no        tinyint NOT NULL,
    permutations    bigint NOT NULL,
    _id             int IDENTITY(1, 1) NOT NULL,
    PRIMARY KEY CLUSTERED (offset, _id)
);




--- Start the iteration:

INSERT INTO @recursion (offset, group_no, permutations)
SELECT CAST(0 AS smallint) AS offset, CAST(0 AS tinyint) AS group_no, 1 AS permutations;

SET @group=1;
WHILE (@group<=@group_count) BEGIN;

    INSERT INTO @recursion (offset, group_no, permutations)
    SELECT CAST(x.offset AS smallint), CAST(x.group_no AS tinyint) AS group_no, cte.permutations*COUNT_BIG(*) AS permutations
    FROM @recursion AS cte
    CROSS APPLY (VALUES (
        SUBSTRING(@map, cte.offset+1, 200)
    )) AS m(map)
    CROSS APPLY (
        --- Add a "#" group
        SELECT cte.offset+gs.[value]+g.group_width+(CASE WHEN @group=@group_count THEN 0 ELSE 1 END) AS offset,
               @group AS group_no,
               1 AS item,
               gen.map
        FROM @group_table AS g
        CROSS APPLY GENERATE_SERIES(0, LEAST(LEN(m.map)-g.minimum_space, CHARINDEX('#', m.map+'#')+g.group_width), 1) AS gs
        CROSS APPLY (VALUES (
            REPLICATE('.', gs.[value])+
            REPLICATE('#', g.group_width)+
            (CASE WHEN @group=@group_count THEN '' ELSE '.' END)
        )) AS gen(map)
        WHERE g.group_no=@group
          AND cte.group_no+1<=@group_count
          AND gen.map LIKE LEFT(m.map, LEN(gen.map))
    ) AS x
    WHERE cte.group_no=@group-1
      AND cte.offset<=@map_len
    GROUP BY x.offset, x.group_no, x.item, cte.permutations;

    SET @group=@group+1;
END;

--- If the remaining dots are in violation of the results (like
--- we've allocated all our groups too early), delete those results.
DELETE FROM @recursion
WHERE group_no=@group_count
  AND offset<@map_len
  AND REPLICATE('.', @map_len-offset) NOT LIKE RIGHT(@map, @map_len-offset);


--- Result the results:
INSERT INTO @res (group_no, permutations)
SELECT group_no, SUM(permutations)
FROM @recursion
WHERE group_no=@group_count
GROUP BY group_no;

RETURN;

END;

GO
IF (@@ERROR!=0) RETURN;








DECLARE @input varchar(max)='??#??????#..????? 9,2,1
???##??#?.?#? 5,1,2
????.????. 1,1
.?#?????###???. 1,6,1
????.?#????#?? 2,1,1,3
??.??.?????#??##.??. 1,1,10,2
??.?###?#??????? 2,7,2,1
?????..#??? 4,1,1
#?????.?#???.#.???# 1,2,4,1,1,1
??#??#???????.?#??? 1,1,7,1,2,1
?..??#????#?.? 3,1,2
..#?????.#.??#.? 1,3,1,1,1
?#.?.?.??#??#?#??? 2,1,1,10
???#???.##?#?????#.? 1,1,1,6,1,1
?.??#?#?#?#?? 1,8
?#??????????? 2,4
??????????? 4,1,1
????.??#?. 4,3
??###??????? 6,1,1
?.?.?#???#?. 1,5
??.?#?..???.???###? 3,1,7
?????#.????? 3,2
#???????.??????#?? 1,4,1,2
?#??????????#??. 1,11
?.????..?..???##? 4,1,6
??????#???#?#?.# 9,1
?#?#??#?##?##?.#??. 10,3,3
??##?#?##????? 8,2
???#??#?.?.???? 5,2
?.??.?..??????.????# 1,2,1,6,3,1
?..#????#???#??.?.?# 1,1,9,1
.?#?.?????. 2,1
???##.???#???#???? 1,2,5,3,1
??????????#?.?.??.?? 9,1,1,2
.#.???????.???#. 1,1,5,1
??.??????##?.? 1,2,4
?????.??.#?.#.# 1,2,1,1,1
#?????.???????#.??? 1,2,1,1,2,2
?#?????..#????#? 6,1,4
.??????.???#??? 5,1,1
??????.?#??# 5,2,1
??.?#?.?#?.#??? 2,2,1
???#?.#???.?. 4,3,1
???.?#??##..##??.? 1,6,3
???##?#?#.#???.?#?. 1,7,3,3
#.?????#??????? 1,1,1,6,1
?#.?.???## 2,1,2
?.???#????? 1,2,1
?.?#??.?#?#??.#.?#?? 1,1,6,1,1,1
??.????.??#? 1,1,1,2
??.#?#??.???#??#?? 1,1,1,1,7,1
.?.??.#??? 1,1,2
????????##?#??#?..? 6,1
?.???#?#.?.?#. 1,5,1,1
?.??#???.??. 4,1
???.???.?#.?#??#?.?? 2,1,2,2,3,1
.#????#.??#? 6,4
#?????.???##?? 4,1,1,4
..????#??????????# 10,3
#????##?#..? 9,1
?#.?.?#?.? 2,1,1
?#?.##???????.????? 3,4,2,3,1
?..?#??##????????# 1,7,1,1
??.?#.??????????. 1,2,2,6
?????..?#?????????#? 1,1,8,1,2
??#???????. 1,4
?????????##.?????? 1,8,1,4
#?#.?.??###??#????? 1,1,1,9
??#????#.??????.??## 1,6,2,2,4
...#?.?###? 1,4
#.?#..???#??. 1,1,1,3
.????.???? 1,3
.#??..???????.?? 1,1,5,1
.???????????? 3,1,4
?..#????????.?.#?? 1,3,1,1,1,1
???##??.???.#? 2,2,3,1
??#?#?????????. 7,1,1,1
???###?#??.???? 9,2
??#?.??????.??##???? 3,1,2,4,1
????.???.? 2,1,1
?..?...#??????#?.?? 1,2
????#???#?????? 4,1,6
??####??????.#??#?? 8,2,1,1
#???????.??.??. 5,1,1,2
????#?#??? 1,5
.????????? 1,2
???????#?. 1,2
?###..##?. 3,2
.??#??.??????.??#.#? 2,1,4,1,1,1
?.??###?#.? 5,1
???##???#?#?.#?. 11,2
.??#???..?#?????#? 3,5,2
???#?#.???#?? 1,1,4
?.??.??.?? 1,1,1
???.???#???#?????#? 1,12
?#??????#?.?#? 3,1,3,2
?#??.?##???.?.?. 3,5,1
????.?????# 1,4,1
.???#???#??#.?.??? 2,5
##??????.?????? 5,1,1,1,1
.?##?###??#?? 7,2
#.????#?????????#??# 1,2,11,2
?.??.?#???????? 1,1,10
???#????#?? 2,1,1
????..??#? 1,2
.??..????##.? 2,5
?????.#??? 1,2,1
?..#.??????? 1,1,4
??#??#???###?# 5,3,1
???.?#..#? 1,1,1
??#?????#??#????##?? 1,2,1,3,1,6
??????????###??.?. 2,3,3,1,1
??#???.??? 3,1,1
????????.? 1,3,1
?#??.??????.? 2,6
???.#????..#??#? 2,1,3,5
????.?#??#? 2,2,2
??.????#????#????#. 1,1,5,1,1,1
??#.????##?#??# 1,8
?#???##?#???.#????. 8,2,1
#?#????#?#?.#?. 1,8,2
#??#??##?#???. 1,10
.?????.??? 5,2
?#???????.?. 2,1,1,1
?.##???..??#??###?? 5,1,8
?.??????#???.?#? 1,7,1
??.#??????.?.#???#? 1,4,1,1,3
.?#?????#????# 2,10
##??????#..? 2,2,3,1
#?????.??????#?? 6,2,2
?.#?????#?# 5,1,1
????.???#????????? 4,12
???##??.??????? 5,3,1
#?????#.?.??.#?# 1,1,1,1,3
??##??#?#? 4,1,1
???????????.?? 1,3,1,2
.?????#.??#. 2,2,1
#.#?.??##????#????? 1,1,1,7,1,1
?.??#.??????? 1,1,1,2
#?.?#??#?????.?.? 1,5,1,1
?.?.??#??? 1,4
???#??#?.?.????#.#. 7,1,2,2,1
..???#????????#? 5,1,1,2
##????..#???? 3,2,4
?.?.#?#?????.#??#?? 6,1,4
???.?##???.????.?? 2,4,1,1,1,1
??#????.?#?. 4,2
?#???????#?#???#? 3,1,7,2
????..#???? 2,5
?#.?????????? 2,1,3,1
?????.??##?#.#????? 1,1,6,1,2,1
#??#??..#? 1,1,1
?????#????#??#???.? 2,8,1,1,1
.????##?.#????#?. 4,6
.?.???.#?###.? 1,5
?.??##??????.#??# 8,4
?#????#??#. 2,5
??#??#.#???#???# 1,2,2,1,1
.#?..???.#??#?????#. 2,1,1,2,5,1
?.???##??#?##.? 1,7,2,1
?#??#?#.??.?.? 3,3,1
??#???#???#????. 11,1
.###?????????? 4,1,3
??#??#????..###?.?? 6,2,3,1
#???.##?.?? 4,2,1
??.##??#??.????# 6,4
????#?????. 1,7
???.???????#???#? 2,1,10
?????###??.?##?? 1,5,3
???#.##?#???#?#??? 2,1,8,1,1
?..?##?.?????#? 1,3,5
????????????###???? 1,1,2,1,8
#??.?#?#?.?????#?. 3,1,1,1,1,1
?.?????.?#??##??# 2,1,3,5
???##?#??????#.??? 10,1,1
??.?###?#? 1,6
???###??????? 6,4
??????#.?.#??? 1,2,2
.?.?.??#?????#???#?? 1,1,8,2
?#..??????#.????. 2,1,2,1,2
.??#?.????##??#.?.# 1,2,7,1,1
??###????.???#???? 5,2,2,2,1
?#???#?#..?? 2,1,1,2
?.#?#??.???? 3,3
.???#?.??????###???? 3,9
????.##?????..#??.? 1,1,3,1,1,3
????????.??????#? 1,3,6
????.#.?#?#?????#??. 2,1,11
#???????#? 1,1,1
?????##?##? 3,6
?#???.??##?#?????.# 1,2,7,1,1,1
.?.#??.??.???##???#? 3,1,9
#????????#???.??? 2,1,1,5,1
????#??.?.?#??###?# 2,1,1,1,9
?#.??..??###???? 1,1,1,5,1
?.??????.?#.?.?#???. 6,2,1,2
????#??????? 1,6,1
#?.??.??#?.??#??? 1,2,1,1,5
.?##?????#?##??.? 5,6
?????..####????.? 4,8
?#?????###???????. 9,5
?????????#???..? 1,3
??#?.???.?.?.?? 2,1,1
???.??????#??#??#. 1,2,1,1,2,1
.#???###??#???.?#??? 11,3
?.???.??##?. 2,3
???#???????##??#? 4,1,5
.???#?.?????## 1,1,2,3
?..????##????.??#.?. 7,2
?#?#.??#???.????#.? 4,6,1,1
.#??????##??##.?###? 2,2,4,2,3
?????#???##???.##?. 1,4,3,1,3
#..???##???##?.??#. 1,5,4,1
.????#?#..????#??. 6,2
??#??.???#?####. 2,1,8
.???.??#?? 1,4
?#?..????#??????? 2,9,1
????#??#??#???.?. 6,4,1,1
???????#.?..?? 5,1,1
??##?????##.??.????? 11,1,1
.#?##?????. 5,1
#.??????#??????? 1,10,1
??#??????.##???. 1,1,1,1,4
?????#??#?. 1,1,2
?.?#?#??.?.#???? 4,3
#?#.?#.????? 1,1,1,1
??????????#? 5,1
??????#?.?##?#?????? 3,7
.????????.?...? 1,2,1,1,1
??##???##??#.???? 1,2,4,1,3
???#?.#????? 1,1,1,2
.??????.????.??#? 4,3,4
??????.??????? 1,1,2,2
????..#??#??? 1,2,1,1
??#??????#?????.???. 10,2
?..#???..??..?.? 4,1
??#?#??#??.#.??#? 7,1,1
..?#???.?.?????? 5,3
?.????#???.?#?? 1,2,4,2
.?#????#??.?? 5,3,1
.#.????##??????????# 1,17
???????.???.# 2,2,2,1
??##?????.??. 7,1
?.?.????.??? 1,1,1,1
?.????????.# 1,4,1
?????#??..#?#.? 1,1,3,3
?#?.#?##??#?? 1,5,2
?.??##??#??#???? 5,4
?.?##?..???###??? 3,6
??#.??#.??.. 2,1,1
#?##?????????#???? 1,2,1,6,2
?.?????.?????#??.#.? 1,1,1,8,1,1
??.?#?.#?##????#.? 3,5,3
..??.????????..? 1,2
.???..????.???..? 3,2,2,1
?.?.??.???. 1,1,1
????#?#??????.??.??. 8,1
??#????????? 4,1,3
??#??????..#?#?? 2,1,2,3,1
?#??#.???# 1,1,1
??#?????#?? 2,4
????#.?#???? 5,1,2
??.???#?????.??#??#? 1,3,1,6
?#.?#.????.#? 1,2,2,1
#?#??#????.?.??????? 8,1,1,2
??##???#.??. 4,2,1
?##??#???.? 6,1,1
?.#?#.?#??????? 3,5
?????#???#..?. 1,8,1
??#..#????.. 2,1,1
?#????.?#?. 2,2,3
?.#????#????###?? 8,3
????...?.?? 2,1
##.????#?????.?##?? 2,5,4
.?#????.???? 6,1
??.?????..???..??? 2,3,3,2
???????#???#???????? 1,1,8,1,1,1
.?.???.?#??.?.?? 1,1,3,1,1
????#.????###.?? 1,1,1,7,1
?.?##?#???.#???.? 5,4
????#?...??.##?????? 2,2,1,5,1
??.???###? 2,6
??.??.?.?##???. 1,2,6
???????#???#?.??#??? 10,5
?.???????#?#??. 1,8,3
..?#?##?.???? 4,2
.?##?#?????. 5,1
?#????#?.??. 1,2,1
??#?#.???????. 3,3
???.????#??.# 2,7,1
????#?.#????????? 5,1,1,1,1
????##???????? 5,1,1,1
???#?????..?#? 2,5,3
?..??##.?????#.?? 4,1,1
.?#????.???#####?? 4,2,7
???.?###.???.? 4,2
?#?????.?#???? 6,4
???#?.?..????? 5,1,1,2
??.#??????####??? 1,1,2,1,7
?.???????#? 2,3
..#????????#? 8,1
?#?##?##?##????. 12,1
?#?.??.?.?# 2,1,1
.?.?#???#?.????. 1,6,1
?#???.??.???????? 5,1,1,2
???????#?#??.?..?? 1,6,1,1,1
???????#???.. 3,1,1
..??#?????????? 1,2,6
??????##?????#???## 8,1,2
??????.#?####?#?#??# 1,1,1,6,2,1
#?#????..#?.? 1,5,1,1
?##???..?#? 2,1,1
.????#.????.??#?#. 1,2,2,3,1
?###??????#. 5,1,1
.?##??#?????...???? 9,4
?.???#?##?#??? 1,10
???.?.?#???#???? 2,1,3,2,2
?????##?##?#? 2,2,2,2
????#???## 2,2
??##..#.??.? 4,1,1,1
??..#?#????? 4,1
.??#??????#?????#?? 3,3,3,4
#?#??#?#??#??. 6,1,4
???##????.?#. 5,1,2
??????##?????# 7,1,2
#??##?#?#????#?????? 12,1,1,1
?.?.???.???. 1,1,3,2
???#.??#####??##?? 1,1,12
??#?##.?#.?? 4,2
?????????.???.??#?. 1,6,1,4
?.#??.?#.???.?. 1,1,2,1,1
?.#????#??.??? 6,2
#?..?#?#???###??#?? 2,14
????????##?????.?#. 3,5,1,2
.#??#?..?????#????? 2,2,8,2
#?????#?????.?.?# 1,1,4,1,2
???#???????? 1,2,6
???????.?..? 1,1,1,1
..?#.?#???.#????#?. 1,3,1,1,1,2
.??#?????##????##.?? 11,3
.##?.##???##?#?#??? 3,11
?##???#.????#??.#? 7,1,1,3,1
???.??#??#?????????? 1,1,1,10,1
?#.#??????#????#???# 2,4,3,7
.#????#?##??#????#? 2,8,3
????????#???.???#??? 1,5,1,2,1,1
.#??????#? 2,4
#?#?????????# 3,5,1
..??#??.#?? 1,1,2
??.?#????.??? 3,3
???#?#?##?#?????? 11,1
#?????#?##???#?.?.?? 4,8,1
?#??.?#??. 2,4
???????..?#?.??? 3,2
?.##?#?.????##?. 5,4
???.#???????????##? 1,7,2,3
.??#?.??#??? 1,1,4
??.??.?#??? 1,4
..?????#.?.. 1,1
??????.???#?#?##??# 1,1,1,1,6,2
??##?#..#??##?#???.? 5,7,1
???#?#????#?.#. 1,5,1,1
.????????? 1,1,1
?#??????????????? 6,1,1,1,1
?.?##???..#. 1,2,1,1
#?#????.#.?????##??. 3,1,1,7
?????.?#?#??#??????? 1,1,1,6,5
??..?.??.#????# 2,1,2,4,1
?##??#??????????.? 9,2,1,1
#?.#..?#?### 1,1,6
???#???.???#??#.?? 1,1,1,3,1,1
?#?????.?#????#???? 3,9
.??????.??.? 4,2
?#?#?.?#??#?#???? 4,2,2,1,1
???.#??#?##??? 1,1,6
??.?..??.?..#????. 1,1,2,1,2,1
???#?????. 2,1,2
.???#??#??? 3,4
#????#?#???? 1,2,3,2
??#??.#?... 2,2
??.?.??#??#?. 2,1,5
???#??????????? 8,1
#????#?????# 2,7
??????.#.##?? 4,1,2,1
?.?.?#?###??#? 1,1,6,2
??.?.?#???#???? 1,1,8,1
?###?..??????.#?.??# 4,5,1,1,1
??##?#???????##??# 6,8
???.?????.????. 1,3,1
????#?????????#??? 9,3
??#???#??????#???? 10,3
.??.##?#??#???#??.. 9,2
..#?#?###???.? 7,1
?????#??#???#??.?.? 2,6,2,1,1
??????.???#????.? 1,8
.?????.#.##? 2,1,2
?.??#?#??????? 1,4,1,1
??#???#.?.?#??#? 2,2,2,3
.?#?..????# 2,1,2
.??##??#?#??? 4,2,1,1
?#???#?#?#..? 2,3,1
.?????###????. 1,5,1
??.???#???#?# 1,8
?#?.#?#?#??.?#?. 2,6,2
?.????#??#???.?? 1,7,1
?.??...???? 1,2,1
.#?.?#.?.???? 1,1,1
.#?##??????? 5,3
..#?#??.#????#?? 3,7
?.?#??##?#?????##?? 1,1,7,2
??????#..?#????? 6,2,2
??#.??.?..?.???? 2,1,1,1,2
???..???????? 3,7
???????.#.??????. 1,1,1,1,6
?#?.??.?#?#?#??????. 2,1,6,1,1
.?#??????. 1,1,1
.?##??#.????? 6,1
?.?#?.?#.?? 3,1,1
?????.????? 1,1,2
??.???????#?? 1,5
???????#?.???.????? 3,2,1,2,5
??????????##?????? 2,2,6,1,1
??#????.?????#?##?# 2,1,9,1
??????#?#.?.?. 8,1
?..#?.??##.?.?? 1,2,2,1,1
??..#??##.?#????#? 1,1,2,1,4
????#?#..?.#?????? 7,1,1,5
.#??????????.???.? 6,1,1,2,1
#?..???.?? 1,3,1
..?????.??.??# 2,2,2,3
.??????.???#??.?? 1,3
..?#.?.????.#?????? 1,1,2,7
??#?#?.???????.? 3,1,1,3
????#??????????## 11,1,2
##??????.???????. 5,1,1
#????#????#?##? 1,10
???##???##?#?????#?? 15,1
????.??????#?#?? 2,7
???#??..?#??##?? 3,8
.##?.#.???? 2,1,2
.?#?????????#?##?#?? 2,1,8,1,1
???###..?#?..??###?? 5,3,1,5
?#?.??#?#?. 1,3,1
??????#?????#??.?.# 1,6,5,1,1
??????#???.# 3,4,1
??#?.??.?##.?#? 3,2,2
????????..??.?.. 1,1
#???#??.????# 7,1,2
??????.?#??. 1,1,1,2
?.#???#???????.? 1,6,1
#.#.##????.#? 1,1,6,1
?.?#?????.?#?#? 4,5
??.?#????? 1,1,1
.?##?????#.????.??? 7,1,1
####.#???#.?.???#?#? 4,1,2,6
???.##??#???##????? 1,1,14
??????#??#??#?#???? 7,1,2,2
.#.????##???????? 1,9,3
#??#?.???##?? 2,2,2
#??#?.??.? 5,2
?#?##?#####????#.?# 12,1,1,1
.?#?#??#??#?????.. 10,2
?????.???#????? 3,7
?.????#.??.??.???##? 1,2,1,1,1,4
?????#??..?????##? 6,7
?#??#?.???????##? 1,1,1,1,3
?##?????.#.?#? 8,1,1
.?#????.??? 4,2
#????#???#????.?#?? 1,1,8,3
?.??????#????#???# 1,1,1,7,2
???????#?#?#?? 2,7
??#?????.#? 3,2,1
?#?.??.?..#????.??## 1,1,1,5,1,2
?????..????????. 2,1,4
.???#?#??#??#?.???? 13,1,1
.#?..???????? 1,1,1,2
??????#??????? 3,9
??#?.??.?.????#???? 4,1,2,2
??##??.????#? 3,1,1
.???##?.?????###. 4,6
?#.??#???#? 1,5,1
????.???.????#. 2,1,5
??.?.?#?????#?. 2,3,2
?.???##??##.????? 9,1
..?.??????????#?.??? 1,1,9,1,1
#?.##??##??#???.? 1,7,1,1,1
#???.#?.????????.# 3,2,3,1,1
?#???#?.#?????## 1,2,2,1,2
.#?##?##??#?# 1,10
?#?##.????.#?????? 1,2,2,1,2,4
#..??###????.#? 1,5,2
.???#??????##???#?? 8,4,1
?.????#???????????. 1,9,2
?#??#????##?.??????? 11,1,2
??#?#.???? 5,1
#?????.???# 4,1,2
???#??#???????????? 2,2,1,7,2
????.???#?????? 1,1,1,1,3
?????????.???#????? 9,1,3,1
??????.??.??.???.??. 4,1,1,2,2,1
???.?#???????#??? 2,4,2,2
###???#???#??.??##?. 7,5,5
.?????####???????? 6,1
????.????? 1,1,1
?????###??#???? 2,5,5
.??.???#??.?.???. 2,5,1,3
#.??#????.???### 1,3,3,1,3
????????#.? 1,3
????##??#.?????. 1,3,1,1,1
..#????#..?#?????? 3,1,5
??#??#?#???#?.? 2,2,2,3,1
###??#?????.?. 4,5
????.?#???.?? 3,2,1
#??????..??#??????? 4,2,2,1,2
???#?#?..#??.??? 4,3
???#????..?? 8,1
#?.?#?????? 2,2,3
??#.????.????## 1,1,1,1,4
???#.?.#?..? 1,1,1,1
#??#????#??##?#? 6,2,5
.????.#???. 1,2
?????.?????.??##??.? 3,1,1,2,4,1
.?#??#??.?. 2,4
????????#???..? 2,6
?#???##???#?.?..??# 8,2,2
.??#?..#????.?? 1,5
.??????#???.?#?#. 1,4,3
????.?????#? 1,1,1,2
.#.?.?.??? 1,1,1
#??????.#? 3,2
?????.#?##?.???#. 2,1,5,2,1
???#?.?.???##??.?. 1,4
?##???????? 4,5
?#?#??#???#??.#?#?? 3,8,4
##?????#??????? 2,5,1,1
????.?#??..????##?? 1,1,1,1,6
????.#???.????#??#? 1,3,1,3,2
?..???#??###???? 1,1,8
??#?#??#???? 3,4,2
#????.??.#?? 5,1,1,1
?.????##???#?????.? 1,11
??????..?.?#?.??. 1,2,1,3,1
?????.?#?? 1,1,1
.?.????????# 1,2,5
.?.?.#?#.????. 1,1,1,3
.???.??#?????#?? 3,10
???#?#????.?? 5,2,1
??#.???.?? 2,1,1
??###??????.?#?? 11,3
??.?????????#?. 2,2
.??#?#??##???????.# 12,1,1
.##??????????.. 3,1,1,2
?????##.?#??.#?.??# 1,1,2,1,1,3
.??..???#??#??.# 2,1,1,2,1
??#.?#.#?.?##?#?#??# 2,1,1,6,1
?.??.??#??? 1,1
#?##??.?##?#?#?#?? 5,10
.??#?.#??#. 1,2,1
?#??????#?.?? 1,5,1
##???..???#?..?????? 2,2,4,3
??.#????.#?? 1,1,2,1
?.?#.???.???? 1,1,2,1
.???##?..?..?#?.??? 3,1
?????????.##????.??. 7,4
##???#?.??.???. 3,1,2,1
????????#..#?.?##?.? 9,2,3
?.??.?..?#. 1,1,1
???????.?##. 5,1,3
#?#.#.???????????##? 3,1,6,6
?.??#??????? 4,3
??#?##???.##? 8,2
???.???.#????.#?.? 2,3,3,1,2
???????##???? 2,2,4,1
????##?#???? 1,7,1
##??..???? 2,1,1
?#??..??.? 3,1
?.??#??#..????.??? 3,2,1,1,3
#?#..#?????#??.? 3,1,5
?????.???????#??. 1,3,2
?.?#????.?? 4,1
?#???#????????#? 11,1
#????#.#??#????#?#?. 1,3,6,3
?????##?.##??.? 2,3
??.??#??..??? 4,2
?#?#???#??#??##????? 1,8,4,1
?????.?.?. 2,1,1
?.?#..???##??.?. 1,1,5,1
??##???#???#?#.?.?. 1,8,1,1,1,1
?#???#??????.???#??. 10,2,2
#?.???#??#?.?????? 1,7,4
???????##?#??? 1,1,8
??.?????##?? 1,1,5
??#??##??##?????##?? 2,2,9,1
?.?#??#?##?.???????? 8,7
???#?#?#?#??????.?? 2,1,11
.????????..?? 1,1,2,1
?#??#?.??.?#? 4,1,1
???.?????#.?#??.. 6,3
#..?#???????. 1,8
?.???##?##?##??#?..? 14,1
?.???..??.??##?? 2,2,2
????#.#?.? 1,1,2
??????#??????#??? 1,4,1,4
?????.?.??. 4,2
?##??..#?.? 3,2
#?.??#.?##??#??#? 1,1,1,8
??#??##?##?#?#?..? 2,10,1
??????##??????.???? 1,10,1,1
?????...?# 3,1
?#?.?#?#?.?# 3,1,1,2
.#?.?#.?#? 1,1,2
??#????????#???.???? 13,1
.????????###????#. 2,1,8
???.?##??.??????# 1,5,1,2
????????.?? 1,5,1
??.?#?##???#?#.. 5,3
.#????????#?#? 3,4,4
???????.??#??? 4,4
##..????##?.?.?. 2,2,4,1
?.???????#?#.????#? 10,4
.?????#??.????#??. 5,1
?#.##??#?????. 1,7
?????????.????? 6,1,2
.?..????#? 1,4
?.##???????#?? 1,3,5
??#?????#??#?#?????. 2,11
.?.???????## 1,6
#???..?.?.?? 3,1,1,1
##?????..??? 2,1,2
#?.??.???????#.???? 1,1,1,2,2,4
?#?#?????.?.?? 4,1,1,1
?????#?#?.???.?.? 8,1,1,1
??###?#??????.?.#?. 10,1
?#????.?????.?? 1,1,4,1
?#?#???##?#??#??#.# 1,1,7,4,1
#.?????#????? 1,1,6
?..#??.???. 1,2
????#?#??.???. 1,5,1
.???.?????#?##?..? 1,8
#??#?#???????.#???#? 6,4,1,1,1,1
.?.##?.?..??????? 3,5
??.#???.#?#?.???#??? 1,4,3,1,1,2
.##?.??.?## 2,1,2
?##.??#.?#???#? 3,2,1,3
.??????#?????? 8,2
#..?????#????#.?#?#. 1,6,1,1,2,1
.????.??.?#?? 2,2,3
?#?#???????####.?#? 3,1,4,3
?#.????#.?.??? 1,1,2,2
???????.?#??#????? 1,1,9
.#?##.????? 1,2,3
???#??#?.??.?. 8,1
..??#??.???#???.? 4,4
???#??##???##??????? 13,1
?????#.?????#???#? 1,1,1,1,4,1
????##????.??.?##. 6,3
#???.#?.?#? 1,1,2
##???????#?#.???? 10,1,1,1
??#??##??#??.??.?.? 10,1
?#??#?#????#????? 1,9,1
#???????.##?.?#???? 2,1,3,2,2
?###??#?#?.#..??? 10,1,1,1
??##??.?????.??. 3,1,1,1,1
??#.?#???.?? 1,5
?##?#????##??#? 10,1
???#??????##?#???? 2,10
???#?.??#??? 1,1,4
???#?#????##?#?.?? 13,1
?#??????????.??. 2,4,2
?#.?##?#?? 1,4
????????..? 1,1
.??##?#???? 5,2
?##???#????###? 3,5,4
??..?.???????##?? 1,1,8
??#?##?????##??. 8,3
.##?..#?????##...? 3,8
????????#??.???# 10,1,1
.??????#?????. 1,1,5
?????#???#. 1,3,1
#.?#.??#.???##.. 1,1,2,4
??#.?.??#? 3,1,1
?.?.##??#??#.?.# 1,8,1,1
??????##?#?#? 1,5,1,1
??????#?????..????? 3,3,2,5
?##?????#.? 5,1,1
??????.??#.##???? 2,3,3,1
####???????#??#?# 6,1,5,1
.??#??#.?#.????##??# 1,1,1,2,1,6
#?#?#?#????????.?? 9,4,1
???###?##??.???. 1,8,1
???##???#??#.??? 2,6,2,1
???.??#????? 1,6
..?????#?. 1,1,1
#?#??.#????#? 5,6
.????#?????#?? 5,1,1
??.??.??#.??????.# 1,1,3,1,1,1
???????..#?#??#. 5,6
??.???###??##?????# 1,1,12,1
???.??????#?##?. 2,10
#????????.?..#.#.? 2,5,1,1,1,1
.?#???##.???#????##. 7,1,1,2
???????#???.##???# 2,1,1,6
?#???#???.?.?? 2,4,1,1
?.?.?.???.???.???? 1,1,2,1,2,1
?#??????.?#????#???. 4,1,1,1,1,1
??#?.##???? 1,1,5
?????#???# 3,1,1
.????.????#.. 3,1,2
???????#?.??##.???.? 5,2,1
?????????#?. 8,2
????#?#?.?.??##????? 1,5,1,1,4,1
?#.?#????####??#.? 2,12,1
?.?##..????#? 3,5
???#???#??? 1,6
??###???#????#.????? 1,7,1,1,2,1
??.????.?? 1,1,1
????.?##?#?## 2,7
.??????#???. 2,5
???##????#?#..## 1,2,4,2
.????.?##?? 1,1,4
#.??#?#.????.?.. 1,5,3,1
#.??.?#?.?#??. 1,1,1,3
???#??????#.?#?? 6,1,1,2
??.?.?#?.?? 1,3
?#???????#.? 4,1,1
?..????##????????.? 1,5,1,1,3,1
#..?#.?#??#??#??##?? 1,2,2,9
#??#?##??..??. 1,5,1,2
?#?????#????#??#..?? 2,12,1
??#.???#??????? 3,2,3,1,1
.?????.#????#???? 3,9
???.????#??????.?# 1,2,1,4,1
??.???.?#?# 1,3,4
#????????#??#..?#.? 4,8,2
????#?#?#??????????? 9,6
#???????#???#???.?.? 1,1,1,9,1,1
?????#?#?#??????. 1,9,2
?#????..?#????# 1,1,1,7
#?????????### 5,1,3
.#?????????? 1,3,1,1
?.?##???????#??#..?# 7,1,4,1
?#???????##??##?? 3,11
.????.#??.?#?#?#?.#? 2,1,1,1,7,1
???????#?.. 2,2
??#?#.?###??##??#?? 1,1,1,8,1,1
??##.?????????#?? 1,2,10
.?????.?#?. 1,1,2
#?????#??#???#..# 1,1,6,3,1
?#????#???.?.#?. 1,1,4,1,2
??#???##??.????#? 8,5
.????.?????#??. 4,1,4
????.??###?. 3,6
????.#???.? 1,4,1
??#???#????###?.. 3,8
.?#???????###??.## 13,2
????.#.????#??? 1,1,1,1,2
#??#?????.? 4,1,1
#?#.???????.? 3,3,1,1
.????????.??. 3,2,1
??.?.??.??##?????? 1,1,1,9
?..?#??#?#??#.?? 1,7,1
??.???##??#?.?? 2,5
.????#.??????? 3,1,2,3
??..??????#? 1,1,2,2
??#??.????# 1,3
??.???????? 1,6
??.?.?????????.???. 1,6,3
#???###???.#??? 1,6,2
?.#???#??????# 2,4,1
??##.???#??.????##. 2,5,6
##.?.????????# 2,1,3,1
#?##.??.#???? 4,4
????#????..?#?? 5,3
.??##?#???.?.???? 9,1,1
???#?#?#?.?.?.. 8,1,1
#????##???#???#???.# 4,2,7,1
.?.???#.?##?????# 1,1,2,3
#?????????#???..#. 5,8,1
???#??????#?..??? 5,3,2
???#?????? 4,1,1
?.???#????####????#? 1,3,6,1
????#?.#???.??#??? 1,1,2,1,5
##????#?..???? 7,2
?#??.?.??#?..???#? 4,1,1,2,5
.##????????..?? 6,1,1,1
????????.#????. 1,1,1,1,2
??????????#??.?????? 3,4,2,1,1,1
?#?.??????.? 1,2,2
.?.?#????#???? 2,1
?.?#????.?? 1,6,1
.?##???.?????. 2,2,4
#.????##?? 1,7
??#???##?#?? 2,6
.?.?#????. 3,2
?#??#?#.?.?##???? 6,1,4,1
?????.?.???#??????? 1,1,1,5,3
.#???????.#? 5,1
????..??#???#?. 3,8
?#??#???.?#?##.?? 7,4
?#????#..#????????? 2,1,1,4,1,1
...?#??#?.#?? 3,2,2
###???#?.???? 4,2,3
???#??????..?##? 4,4,4
????.????#? 2,1
????##?#???.???? 7,1,1
?????????.?..??. 3,2,1,2
#?..#????? 1,1,2
##???#????#?.???.. 7,2,1,1
??#????????#?..?##?? 11,3
.?#?..#??##???.. 3,8
##?#????#.?#?.#???## 2,2,3,2,2,2
???#???????????.? 1,3,5,1,1
#.????????#? 1,1,1,3
??.?.??.?.?.??????? 1,2
???.#???????#??## 1,3,8
..?#??.??##?????. 2,5
????.?????????? 1,1,2,2
#????.??#? 5,2
?.#??#????#?????.?# 5,5,1
?.?#??#??? 4,1
????????.????.? 8,2
????.?#?????. 1,1,3,2
???#??.?#??# 5,5
????#.?#?.##??????. 1,1,3,5,2
.?#??.?#?#?????. 4,4,2
??..?#?#????.#? 6,1
.?.#.?#????#???#?##? 1,1,15
#.?????##.? 1,5,1
.##?????.????????? 5,2,4
???.???.##???#.?#?? 1,1,1,6,4
???#??#?????# 1,2,4,1
#???.##??##????? 4,9
???...#?...???# 1,2,3
##?#?#????.# 6,1,1
.??#??..????.?# 2,1,1,1,1
##??#???????#.??# 5,1,1,1,2
.#???#?????##.??#?. 1,3,1,1,2,3
??????#???? 2,3
?.???#??#? 1,2,2
?#??.##?????#? 2,2,1,2
??#.??#?.??.#?#??? 3,3,1,1,1,1
?.?##?.?.???#?#.? 1,3,1,4
??.???#?###?#.? 1,1,6,1,1
.?.#?????#?.?????? 1,3,3,2,1
?#?#?####..#.? 8,1
???##?#????.??#??#?? 9,1,3,3
??#????#?.??#?. 1,7,4
???#..?.?? 1,1,1
?????#????.??###? 6,1,6
.#?????#?????.??# 1,5,1,1,2
???#????..???#### 3,7
???????##..? 1,4
.??.??.???... 1,2,3
.??.#?#?????#? 1,9
???#???.?????? 1,4,2,1
??.?#.?.??.?#???#?? 2,1,1,8
##.##?????????#.?? 2,2,7
???###??##?..??.??? 5,3,1,2
#..????#?#???? 1,1,4,2
???????????#? 2,2
??.?##?#????????#??# 1,8,2,1
????#?#???????????? 7,1,1,2,1
.#??.?#??.# 1,2,1
?#???????? 2,1,2
?????#??#???.??? 1,4,1,2
?.?????.?.????##? 3,7
???..#???#???#??. 1,2,7
???.#??#?#???#.?? 1,1,8,2
###?##?.???#??# 7,5
.???.?.??#? 1,1,2
??#??.???# 2,4
??###?????. 6,1
???#?#????.?.?#.?.# 4,5,2,1,1
.??????.?#...?#??. 2,1,3
.??#.??#?? 1,2
??#??.?#??#? 1,1,1,4
.?#?#?..#?.??? 5,1,2
#??#?##?#?..?#??? 1,7,1
#???????## 2,3,2
???.????##??#?#?.#?? 1,11,1
#.?..????#?#??..?#? 1,1,9,1
.?.?????#??? 1,4,1,1
.???.???..#?##??? 3,1,5
??..????.???.?# 1,4,1,2
???????#?? 1,1,3
.????????#??#.??. 1,9,1
?.?.#????.#????????. 3,7
????#??#??????.??.#? 8,3,2,1
?????.#???..???#??? 2,1,4,4,1
??#????..?.? 5,1
???#?#?#????.?##???? 11,7
?????????????#??? 4,10
?.??#...?#???.?.. 1,3
.????...???#...? 1,2
??#?.#.?????##? 3,1,1,1,2
????#.??#?.#. 1,1,3,1
#.??????#??##??#???? 1,17
###????.#?? 5,2
??????????#.?.?...?. 10,1,1
#.#.#.???##??#??.# 1,1,1,9,1
.??.??.#?. 1,1,1
?#???.???##??#?#? 1,1,1,8
.??##?#??????#???## 9,3,3
.???????#? 5,3
.????###??#?.???? 9,2
#?##??????????? 7,3,1
???..#?#???#???.? 1,9
??#.???#.# 2,1,1
#.?#??.#?.?? 1,3,1,2
.#??????#???????. 2,4,1,2
..??????.??? 1,2
?##???.??.??#???. 2,2,1,3,1
.?.?##???#.?? 3,2,1
..???????? 3,1
??.??#????????#?#? 1,1,1,1,5
#?.?#.###??##??????? 2,1,9,1
.#?????.??. 2,1,1
.??.??#????## 2,4,2
?#?#?#?#?###?..?? 12,1
??#??.??#???? 3,2
#??#??????.?????? 1,1,4,1,1
#??#???#??.????#??? 4,2,5,1
???????.?#?? 5,1
?.#??#??#????#???.? 8,6,1
.?##?#?.?.?? 5,1
??###??????##??. 5,4
?#?#.???.??# 1,1,2,2
.???????.?#?... 3,3
??.?#?????.?.??##?#? 1,1,3,1,7
?#.???????.???#? 2,1,1,1,2
.??#?????. 4,1
????.?#???.??????.. 2,3,1,5
.??????.#? 1,2
.??.???#?.? 2,3,1
#?##?.?.???.## 5,1,1,2
.##????.?? 4,1
#??.?#???.?##?... 1,1,4,3
?...##??.? 1,2,1
?###..#??? 3,1,1
?#?##?#??##??? 1,8,1
.??###??.?#?.???###? 4,3,5
?.??????#?##???? 1,1,9,1
?????#??.?????? 7,2
.???#????#???#? 6,2,3
????.????.?#?..??? 3,4,3,2
????.#?.???#?? 1,1,2,6
?.#???#?#?.?#?? 1,5,2,1,1
?#?.#.???????.?? 1,1,1,3,1
?#?????????????? 3,1,2,1,3
???.#??#?#???# 7,1
??#????#???.##??#. 8,1,5
???#?????#??.? 2,5
.#????.???? 5,1
??????#?????###?? 5,3
?..??#???.????? 1,1,1,2,1
#??.?...?.??. 2,1,2
?#???#?????.#??? 2,1,1,2,1
?#?????????.??????? 2,3,1,3,2
.?#???????? 2,2,1
?#??.?.?.?.? 3,1
?##?..????#?? 4,1,4
???#?..???????# 1,2,7
??#??##?.??????.?? 2,2,1,1,1,1
.#?#...#?????? 3,1
.??..??##? 1,4
?????##??.??##?.. 6,5
#?..?#???.?? 1,3,1
?##??.?.#?#????? 3,1,3,1,2
.?#?????..#?#..?? 7,3,1
????????##?##.?#.#?? 1,1,1,7,1,2
???..????.?.???##?? 2,2,1,1,2,1
??????.??????.# 3,1,2,1
#.??#????.??#?? 1,3,1,1,1
??#####??#?????#?# 10,3
##???###?#????? 12,1
????????????? 2,5
??#??.????.?##? 2,4,2
?.?#???.#?#.???#.. 1,4,3,2
????#????#? 2,2,2
???.#?.?#????? 1,1,2,6
?.#???#?????#?????. 5,5
??????#??#??? 1,7
??.??????#???#?????# 1,1,7,3,1
#?..?????? 1,3
??#???..???.# 3,2,2,1
?###?????? 6,1
???##.#??#?? 1,3,1,3
???##??..?#?#??? 3,4
??????##??.?????#? 9,1,5
?#???#?.?#???? 5,5
??.?.???.?? 1,2
??##??#?????# 2,7
???????.???????##?#. 1,1,1,1,7
#?#????#???.##.? 8,1,2,1
???#.??###??..#?#?? 1,1,4,1,1,3
.?.??###???#?.?????? 7,1
?#?#?#???????.?#? 5,2,3,2
???##???.??????#? 1,3,1,1,5
???????#?#??.? 1,2,5
????#?.??? 2,1,1';
/*
SET @input='???.### 1,1,3
.??..??...?##. 1,1,3
?#?#?#?#?#?#?#? 1,3,1,6
????.#...#... 4,1,1
????.######..#####. 1,6,5
?###???????? 3,2,1';
*/

DROP TABLE IF EXISTS #source;

WITH source AS (
    SELECT ordinal AS [row],
           REPLACE(LEFT([value], CHARINDEX(' ', [value])-1), '?', '_') AS map,
           SUBSTRING([value], CHARINDEX(' ', [value])+1, LEN([value])) AS groups
    FROM STRING_SPLIT(REPLACE(@input, CHAR(13), ''), CHAR(10), 1))

SELECT s.[row], s.map, s.groups, CAST(NULL AS bigint) AS permutations, CAST(NULL AS time(7)) AS duration
INTO #source
FROM source AS s;

CREATE UNIQUE CLUSTERED INDEX IX ON #source ([row]);



---------------------------------------
--- Unfolding

UPDATE #source
SET map=SUBSTRING(REPLICATE('_'+map, 5), 2, 1000),
    groups=SUBSTRING(REPLICATE(','+groups, 5), 2, 1000);


---------------------------------------

SET NOCOUNT ON;

DECLARE @row int=(SELECT MIN([row]) FROM #source WHERE permutations IS NULL), @dt datetime2(7);
WHILE (@row<=1000) BEGIN;
    SET @dt=SYSDATETIME();

    UPDATE s
    SET s.permutations=(SELECT SUM(permutations) FROM dbo.Permutations(s.map, s.groups))
    FROM #source AS s
    WHERE s.[row]=@row
      AND s.permutations IS NULL;

    UPDATE s
    SET duration=CAST(DATEADD(ms, DATEDIFF(ms, @dt, SYSDATETIME()), 0) AS time(7))
    FROM #source AS s
    WHERE s.[row]=@row
      AND s.duration IS NULL;

    PRINT 'Row '+STR(@row, 5, 0)+': '+STR(0.001*DATEDIFF(ms, @dt, SYSDATETIME()), 6, 2)+' s.';

    SET @row=@row+1;
END;



SELECT SUM(permutations)
FROM #source
