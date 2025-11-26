-- The city of Shoreline is right next to Seattle. As it turns out, some entries in the original data
-- incorrectly label a point in Seattle as being in Shoreline
-- Using the washington city boundaries, find all entries where loc isn't in the right city (ignore incomplete rows)
-- Also find the distance in miles to city it was listed in (Some cities in the dataset are composed of multiple disjoint polygons like Auburn. These tend to be significantly smaller, so only consider the largest area shape for each city)
-- Some smaller towns like 'By Center' aren't listed in the boundaries, so the distance to them may be unknown
-- Note, the city boundaries data is in SRID 2927 which has units of US survey feet

-- https://geo.wa.gov/datasets/69fcb668dc8d49ea8010b6e33e42a13a_0
-- make sure to run cityboundaries.sh once to setup this supplemental data

\set QUIET

\timing on
select
    POI.long || ' ' || POI.lat as location,
    POI.city as listed,
    CityBoundaries.city_disso as actual,
    st_distance(st_transform(POI.loc, 2927), (select geom from CityBoundaries where city_disso = POI.city order by st_area(geom) desc limit 1))/5280 as distance
from POI join CityBoundaries on st_contains(CityBoundaries.geom, st_transform(POI.loc, 2927))
where POI.city <> CityBoundaries.city_disso
order by POI.city, CityBoundaries.city_disso
;
\timing off

-- TODO FINISH optimize and compute distance between?