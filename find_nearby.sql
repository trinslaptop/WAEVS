-- Lets demonstrate finding cars within some distance of a point.

-- There's a Volvo dealership here, lets look for Volvo cars within 2km...
-- The closest matches are about 1.38 km away at the University of Washington
-- https://maps.app.goo.gl/a8sRh977V6R1o2Wb8
\set lat     47.66872
\set long   -122.29832
\set radius  2000

\set QUIET
drop function if exists haversine_distance;
drop index if exists poi_location_idx;
drop index if exists evs_loc_idx;

-- With plain SQL/Postgres, we'll have to use a bit of math (the haversine distance formula) to find
-- distance since long/lat are in decimal degrees while radius is in meters. Additionally, we need to loop
-- over every Volvo vehicle to check it's distance. No B+ Tree will help here
--
-- (I suppose you could make an index on the distance to speed things up, but it would
-- only help with running this *exact* query multiple times not any other center point)
--
-- Haversine distance formula: https://www.movable-type.co.uk/scripts/latlong.html
create function haversine_distance(long real, lat real)
    returns real
    language sql
    immutable
    returns null on null input
    return 6371000*2*atan2(
        sqrt(    (pow(sin(radians(lat - :lat)/2), 2) + cos(radians(lat))*cos(radians(:lat))*pow(sin(radians(long - :long)/2), 2))),
        sqrt(1 - (pow(sin(radians(lat - :lat)/2), 2) + cos(radians(lat))*cos(radians(:lat))*pow(sin(radians(long - :long)/2), 2)))
    );

\timing on
\echo '=== Example 1 ==='
select
    haversine_distance(long, lat) as distance,
    make,
    model,
    year,
    long || ' ' || lat as location
from waevs
where make = 'VOLVO' and haversine_distance(long, lat) < :radius
order by distance asc, make, model, year asc;
\timing off
\echo '================='
\echo

-- That works, but it's neither simple to write nor all that fast (~25ms for me)
-- Let's use PostGIS, we can use st_distancesphere(a,b) to do all the work for us
-- NOTE: name may be st_distance_sphere or st_distancesphere depending on your version!
-- (Also happens to have a more accurate radius for Earth)
\timing on
\echo '=== Example 2 ==='
select
    st_distancesphere(loc, st_setsrid(st_makepoint(:long, :lat), 4326)) as distance,
    make,
    model,
    year,
    long || ' ' || lat as location
from waevs
where make = 'VOLVO' and st_distancesphere(loc, st_setsrid(st_makepoint(:long, :lat), 4326)) < :radius
order by distance asc, make, model, year asc;
\timing off
\echo '================='
\echo

-- That's simpler since we didn't need to make the function ourselves, but it's even slower (~50ms for me)!
-- (Partially due to being more accurate!)
-- For the above example, PostGIS still needs to loop over all the Volvo cars
-- Let's make a special spatial index on the POI and a normal index on the loc id of EVs (used in view WAEVs)
create index poi_location_idx on POI using GIST(loc);
create index evs_loc_idx on EVs(loc);
\timing on
\echo '=== Example 3 ==='
select
    st_distancesphere(loc, st_setsrid(st_makepoint(:long, :lat), 4326)) as distance,
    make,
    model,
    year,
    long || ' ' || lat as location
from waevs
where make = 'VOLVO' and st_distancesphere(loc, st_setsrid(st_makepoint(:long, :lat), 4326)) < :radius
order by distance asc, make, model, year asc;
\timing off
\echo '================='
\echo

-- That still didn't help... turns out st_distancesphere still needs to loop over each point and can't
-- use our index. Fortunately, the boolean function st_within and a bounding region can! (The EVs(loc) index can only be applied iff the spatial index also works!)
\timing on
\echo '=== Example 4 ==='
select
    st_distancesphere(loc, st_setsrid(st_makepoint(:long, :lat), 4326)) as distance,
    make,
    model,
    year,
    long || ' ' || lat as location
from waevs
where make = 'VOLVO' and st_within(loc , st_buffer(st_setsrid(st_makepoint(:long, :lat), 4326), :radius/111320.0))
order by distance asc, make, model, year asc;
\timing off
\echo '================='
\echo

-- 5ms! that's 1000% faster than the naive PostGIS method and 80% faster than the plain SQL version!
-- Plus we didn't have to do any math!
-- speedup = new/old