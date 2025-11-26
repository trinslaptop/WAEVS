#!/usr/bin/bash

# Run once to setup database and download data, then connect with `psql waevs`

sudo apt install wget postgis

sudo su - postgres <<< 'createdb waevs'
psql waevs -c 'create extension postgis;'
psql waevs -c 'create extension postgis_topology;'
psql waevs -c 'select postgis_version();'

wget 'https://data.wa.gov/api/views/f6w7-q2d2/rows.csv?accessType=DOWNLOAD' -O waevs.csv
psql waevs -c "create table csv (`head -n 1 waevs.csv | sed 's/[^,]*/"\0" text/g'`);"
psql waevs -c "\copy csv from 'waevs.csv' delimiter ',' csv header;"