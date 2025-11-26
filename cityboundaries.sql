-- The city of Shoreline is right next to Seattle. As it turns out, some entries in the original data
-- incorrectly label a point in Seattle as being in Shoreline
-- Using the washington city boundaries, find all entries where loc isn't in the right city (ignore incomplete rows)

-- https://geo.wa.gov/datasets/69fcb668dc8d49ea8010b6e33e42a13a_0
-- make sure to run cityboundaries.sh once to setup this supplemental data

\set QUIET


\echo '=== Example 1 ==='
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
\echo '================='
\echo

-- That takes >1.5s for me and is way too slow! let's optimize it!
-- looking at explain, it's doing a seq scan on city boundaries and poi

create index poi_city_idx on POI(city);
create index cityboundaries_geom_idx on CityBoundaries using GIST(geom);

\echo '=== Example 2 ==='
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
\echo '================='
\echo

-- ~60ms is way better! that's a 96% speed up!
-- All we had to do was create an index, no changes to the query!

drop index poi_city_idx;
drop index cityboundaries_geom_idx;