## Set up Sakila DB

1. `scripts/setup-nocodb-with-pg-sakila-db.sh`
2. `open localhsot:8080`
3. Create Base > Open settings of the created base > Data Sources > New Data Source > Use Connection URL & Set `SSL mode` to `No` > Submit
    - Execute `make show-NC_DB` to get the connection URL.