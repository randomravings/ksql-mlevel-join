#!/bin/bash
docker exec -i ksqldb-cli ksql --execute "SET 'auto.offset.reset'='earliest';" -- http://ksqldb-server:8088
docker exec ksqldb-cli ksql --file /ksql_scripts/01_base_tables.ksql -- http://ksqldb-server:8088
docker exec ksqldb-cli ksql --file /ksql_scripts/02_employee_stream.ksql -- http://ksqldb-server:8088
docker exec ksqldb-cli ksql --file /ksql_scripts/03_department_stream.ksql -- http://ksqldb-server:8088
docker exec ksqldb-cli ksql --file /ksql_scripts/04_location_stream.ksql -- http://ksqldb-server:8088