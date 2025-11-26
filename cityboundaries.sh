#!/usr/bin/bash
wget 'https://hub.arcgis.com/api/v3/datasets/69fcb668dc8d49ea8010b6e33e42a13a_0/downloads/data?format=shp&spatialRefId=2927&where=1%3D1' -O City_Boundaries.zip
unzip City_Boundaries.zip

shp2pgsql -DI -s 2927 City_Boundaries.shp CityBoundaries | psql waevs