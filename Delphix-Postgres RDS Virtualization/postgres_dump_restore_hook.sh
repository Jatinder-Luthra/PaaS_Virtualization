#!/bin/bash

#############          postgres_dump_restore_hook.sh      ###################
## Hook script to automate dumps & restore for PaaS Postgres database #######
############ Author: Jatinder Luthra                   ######################
############ Created: 04/20/2023                       #####################

rds_endpoint="jl-rds-pg-1022.cdsvgllsbibq.us-east-1.rds.amazonaws.com"
rds_dbname="airlinedb"
timestamp=$(date +"%Y%m%d_%H%M%S")
dump_dir="rds_"$rds_dbname"_"$timestamp

echo "Dump Directory, $dump_dir"

## dumping rds postgres database

echo "Dump of RDS Postgres Database, Started .."

pg_dump -h $rds_endpoint  -Z0 -j 4 -Fd airlinedb -f /home/postgres/$dump_dir

echo "Dump of RDS Postgres Database, Finished"

## restore rds postgres dump on staging

echo "Restore of RDS Postgres Database, Started .."

echo "drop staging instance database, $rds_dbname"
psql -p 5433 -U postgres -c "drop database airlinedb"

pg_restore -j 4 -Fd -O -C -d postgres -p 5433 /home/postgres/$dump_dir

echo "Restore of RDS Postgres Database, Finished"