#!/bin/bash -eu
export NOCODB_TAG=0.111.4

if [ ! -d "_nocodb" ]; then
  git clone https://github.com/nocodb/nocodb.git _nocodb
fi

cd _nocodb
git fetch -p
git checkout .
git checkout $NOCODB_TAG

cd docker-compose/pg

# for Apple M1 chipset
# if [ $(uname) == 'Darwin' ] && [ $(uname -m) == 'arm64' ]; then
if [ $(uname -m) == 'arm64' ]; then
  DOCKER_DEFAULT_PLATFORM=linux/amd64
fi

docker-compose down -v --rmi all
docker-compose up -d
docker-compose cp ../../packages/nocodb/tests/pg-sakila-db root_db:/
docker-compose exec root_db bash -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB -f /pg-sakila-db/01-postgres-sakila-schema.sql'
docker-compose exec root_db bash -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB -f /pg-sakila-db/02-postgres-sakila-insert-data.sql'