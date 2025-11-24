#!/usr/bin/bash
sudo su - postgres
createdb waevs
psql waevs -c 'create extension postgis;'
psql waevs -c 'create extension postgis_topology;'
psql waevs -c 'select postgis_version();'
