-- Time for crazy
-- Lets find out which two utility companies power the most and least amount of EVs!
-- For the sake of this example, we'll only consider rows we have complete positional data (loc) for 
with 
    -- Expand many-to-many relation
    POIUtilities as (
        select
            POI.id,
            POI.loc,
            ElectricUtility.name as utility
        from POI 
        join RegionalElectricUtility on POI.id = RegionalElectricUtility.loc
        join ElectricUtility on ElectricUtility.id = RegionalElectricUtility.utility
    ),
    -- The original dataset had used a multi-valued string since each location could have multiple utilities
    -- Instead expand on a join
    EvUtilities as (
        select
            EVModel.make,
            EVModel.model,
            EVModel.year,
            POIUtilities.loc,
            POIUtilities.utility
        from POIUtilities
        join EVs on POIUtilities.id = EVs.loc
        join EVModel on EVModel.id = EVs.model
    ),
    -- Count EVs per utility 
    AggregateEvUtilities as (
        select
            rank() over (order by count(*) desc) as i,
            utility,
            count(*) as n
        from EvUtilities
        group by utility
    )
-- Select only the min and max count rows
select
    utility,
    n
from AggregateEvUtilities
where i = 1 or i = (select max(i) from AggregateEvUtilities)
order by n desc
;

