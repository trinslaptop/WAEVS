-- Pull out "Make" to a new table
drop table if exists EVMake cascade;
create table EVMake(name text primary key);
insert into EVMake select distinct "Make" from csv;

-- Extract "Electric Vehicle Type" into table
drop table if exists EVType cascade;
create table EVType(name text primary key, description text);
-- Split up rows like "Battery Electric Vehicle (BEV)"
insert into EVType select distinct substring("Electric Vehicle Type" from '\((.*?)\)'), substring("Electric Vehicle Type" from '(.*?) \(.*\)') from csv;

-- Extract the functionally different variants of EVs into a table
-- (Functionally different as in make, model, year, engine, battery, etc... not color or radio which we don't even know)
drop table if exists EVModel cascade;
create table EVModel(
    make text not null references EVMake(name),
    model text not null,
    year int not null,
    type text not null references EVType(name),
    msrp int null, -- explicitly nullable since we're missing several data points
    range int null, -- explicitly nullable since we're missing several data points
    tax_exempt boolean null, -- whether this model was eligible for the Clean Alternative Fuel Vehicle tax exemption (depends on battery range and price; may be true, false, or unknown)
    -- Sometimes, the same (make, model, year) isn't enough to fully distinguish the rest of the data (like range).
    -- While not universally true, most manufacturers use the 8th character of the VIN to specify engine/motor/battery type.
    -- This is almost sufficient to identify the other values; however, for some reason, the Chinese Volvo XC60 2022 (LYVH60##)
    -- has a slightly different range than the more common Swedish variant (YV4H60DL##), and the UK Tesla Roadster 2008
    -- (SFZRE11B##) is missing range data while the more common United States one has it. As such, we need even more than
    -- just engine info or vin attributes. To identify each variant of a model uniquely, we'll use the first 8 characters of
    -- the VIN (effectively "WMI" || "Attributes") along with (make, model, year). Note that "discriminant" here is just eight
    -- characters in [A-HJ-NPR-Z0-9] that help uniquely identify variants and not much of a meaningful value in and of itself.
    discriminant char(8) not null,
    -- As opposed to having to use (make, model, year, discriminant) as a primary key, we'll use a synthetic id column
    id int primary key generated always as identity,
    unique(make, model, year, discriminant)
);
insert into EVModel select distinct
    "Make",
    "Model",
    "Model Year"::int,
    substring("Electric Vehicle Type" from '\((.*?)\)'),
    nullif("Base MSRP"::int, 0), -- convert a msrp of 0 into null since the dataset uses a mix of both to indicate unknown/missing
    nullif("Electric Range"::int, 0), -- convert a range of 0 into null since the dataset uses a mix of both to indicate unknown/missing
    case "Clean Alternative Fuel Vehicle (CAFV) Eligibility"
        when 'Clean Alternative Fuel Vehicle Eligible' then true
        when 'Not eligible due to low battery range' then false
        when 'Eligibility unknown as battery range has not been researched' then null
        else ('Unknown CAFV eligibility: ' || "Clean Alternative Fuel Vehicle (CAFV) Eligibility")::boolean -- dirty hack to raise error on default branch
    end,
    substring("VIN (1-10)", 1, 8)
from csv;

-- "State" in the source data may refer to one of 50 U.S. States, Washington DC, one of the Canadian Providences, or a handful of others. Not all listed here are used.
-- This list comes from https://en.wikipedia.org/wiki/List_of_U.S._state_and_territory_abbreviations and https://en.wikipedia.org/wiki/Canadian_postal_abbreviations_for_provinces_and_territories
drop table if exists State cascade;
create table State(
    country char(2) not null,
    code char(2) unique not null,
    name text unique not null,
    primary key(code, name)
);
insert into State values
    -- U.S. States
    ('US', 'AL', 'Alabama'),
    ('US', 'AK', 'Alaska'),
    ('US', 'AZ', 'Arizona'),
    ('US', 'AR', 'Arkansas'),
    ('US', 'CA', 'California'),
    ('US', 'CO', 'Colorado'),
    ('US', 'CT', 'Connecticut'),
    ('US', 'DE', 'Delaware'),
    ('US', 'FL', 'Florida'),
    ('US', 'GA', 'Georgia'),
    ('US', 'HI', 'Hawaii'),
    ('US', 'ID', 'Idaho'),
    ('US', 'IL', 'Illinois'),
    ('US', 'IN', 'Indiana'),
    ('US', 'IA', 'Iowa'),
    ('US', 'KS', 'Kansas'),
    ('US', 'KY', 'Kentucky'),
    ('US', 'LA', 'Louisiana'),
    ('US', 'ME', 'Maine'),
    ('US', 'MD', 'Maryland'),
    ('US', 'MA', 'Massachusets'),
    ('US', 'MI', 'Michigan'),
    ('US', 'MN', 'Minnesota'),
    ('US', 'MS', 'Mississippi'),
    ('US', 'MO', 'Missouri'),
    ('US', 'MT', 'Montana'),
    ('US', 'NE', 'Nebraska'),
    ('US', 'NV', 'Nevada'),
    ('US', 'NH', 'New Hampshire'),
    ('US', 'NJ', 'New Jersey'),
    ('US', 'NM', 'New Mexico'),
    ('US', 'NY', 'New Your'),
    ('US', 'NC', 'North Carolina'),
    ('US', 'ND', 'North Dakota'),
    ('US', 'OH', 'Ohio'),
    ('US', 'OK', 'Oklahoma'),
    ('US', 'OR', 'Oregon'),
    ('US', 'PA', 'Pennsylvania'),
    ('US', 'RI', 'Rhode Island'),
    ('US', 'SC', 'South Carolina'),
    ('US', 'SD', 'South Dakota'),
    ('US', 'TN', 'Tennessee'),
    ('US', 'TX', 'Texas'),
    ('US', 'UT', 'Utah'),
    ('US', 'VT', 'Vermont'),
    ('US', 'VA', 'Virginia'),
    ('US', 'WA', 'Washington'),
    ('US', 'WV', 'West Virginia'),
    ('US', 'WI', 'Wisconsin'),
    ('US', 'WY', 'Wyoming'),
    -- U.S. Territories/Commonwealths
    ('US', 'AS', 'American Samoa'),
    ('US', 'GU', 'Guam'),
    ('US', 'MP', 'Northern Mariana Islands'),
    ('US', 'PR', 'Puerto Rico'),
    ('US', 'VI', 'U.S. Virgin Islands'),
    ('US', 'UM', 'U.S. Minor Outlying Islands'),
    -- Canadian Provinces
    ('CA', 'AB', 'Alberta'),
    ('CA', 'BC', 'British Columbia'),
    ('CA', 'MB', 'Manitoba'),
    ('CA', 'NB', 'New Brunswick'),
    ('CA', 'NL', 'Newfoundland and Labrador'),
    ('CA', 'NT', 'Northwest Territories'),
    ('CA', 'NS', 'Nova Scotia'),
    ('CA', 'NU', 'Nunavut'),
    ('CA', 'ON', 'Ontario'),
    ('CA', 'PE', 'Prince Edward Island'),
    ('CA', 'QC', 'Quebec'),
    ('CA', 'SK', 'Saskatchewan'),
    ('CA', 'YT', 'Yukon'),
    -- Other
    ('MH', 'MH', 'Marshall Islands'),
    ('FM', 'FM', 'Micronesia'),
    ('PW', 'PW', 'Palau'),
    ('US', 'AA', 'U.S. Armed Forces - Americas'),
    ('US', 'AE', 'U.S. Armed Forces - Europe'),
    ('US', 'AP', 'U.S. Armed Forces - Pacific'),
    ('US', 'DC', 'District of Columbia')
;

drop table if exists POI cascade;
create table POI(
    state char(2) not null references State(code), -- in some cases (especially outside WA), only the state code exists; any other field can be null
    county text null,
    city text null,
    postalcode int null,
    tract numeric(11) null, -- 2020 Census tract, null if "state" is not in US or is US Armed Forces
    -- In theory, "long"/"lat"/"loc" with 5 decimal places has 1.1m accuracy, but it appears to be heavily bucketed (likely for privacy reasons). In practice, "tract" may have narrower accuracy (https://gis.stackexchange.com/a/8674)
    -- electricutility text null,
    long real null, -- Longitude for base Postgres
    lat real null, -- Latitude for base Postgres
    loc geometry(point, 4326) null, -- (Longitude Latitude) Point for PostGIS (4326 is Spatial Reference System Identifier for World Geodetic System 1984 aka point type)

    id int primary key generated always as identity, -- As opposed to having to use (state, county, city, postalcode, long, lat) as a primary key, we'll use a synthetic id column
    unique(state, county, city, postalcode, tract, loc) -- (note, Postgres treats null values as not the same for uniqueness)
);
insert into POI select distinct
    "State", "County", "City", "Postal Code"::int,
    "2020 Census Tract"::numeric(11),
    -- "Electric Utility",
    substring("Vehicle Location" from '^POINT ?\((.*?) .*?\)$')::real, -- null will propagate through
    substring("Vehicle Location" from '^POINT ?\(.*? (.*?)\)$')::real, -- null will propagate through
    st_pointfromtext("Vehicle Location", 4326) -- null will propagate through
from csv;

-- Create a table of instanced vehicle variants
drop table if exists Vehicles cascade;
create table Vehicles(
    id int primary key, -- The DOL vehicle ID
    vin char(10), -- First 10 characters of VIN,
    model int not null references EVModel(id),
    loc int not null references POI(id) 
);
insert into Vehicles select 
    "DOL Vehicle ID"::int,
    "VIN (1-10)",
    (
        select id from EVModel where EVModel.make = "Make" and EVModel.model = "Model" and EVModel.year = "Model Year"::int and EVModel.discriminant = substring("VIN (1-10)", 1, 8)
    ),
    (
        select id from POI where 
            POI.state = "State"
            and POI.county is not distinct from "County" -- `a is not distinct from b` is like `a = b` except that comparing null and null is true
            and POI.city is not distinct from "City"
            and POI.postalcode is not distinct from "Postal Code"::int
            and POI.tract is not distinct from "2020 Census Tract"::numeric(11)
            and POI.loc is not distinct from st_pointfromtext("Vehicle Location", 4326)
    )
from csv;







