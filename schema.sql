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
    -- As opposed to having to use (make, model, year, discriminant) as a primary key, we'll use a generated id column
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