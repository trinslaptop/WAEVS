-- The city of Shoreline is right next to Seattle. As it turns out, some entries in the original data
-- incorrectly label a point in Seattle as being in Shoreline
-- Using the washington city boundaries, find all entries where loc isn't in the right city (ignore incomplete rows)
-- https://geo.wa.gov/datasets/69fcb668dc8d49ea8010b6e33e42a13a_0

-- make sure to run cityboundaries.sh once to setup this supplemental data

\set QUIET

-- select * from POI where st_contains((select geom from cityboundaries where city_disso = 'Seattle'), st_transform(loc, 2927));

\timing on
select
    POI.long || ' ' || POI.lat as location,
    POI.city as listed,
    CityBoundaries.city_disso as actual
from POI join CityBoundaries on st_contains(CityBoundaries.geom, st_transform(POI.loc, 2927))
where POI.city <> CityBoundaries.city_disso
order by POI.city, CityBoundaries.city_disso
;
\timing off

-- TODO FINISH optimize and compute distance between?