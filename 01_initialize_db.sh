#!/bin/bash
docker exec mssql /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1,1433 -U SA -P 'pdw123!@#' -i sql_scripts/01_create_db.sql
docker exec mssql /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1,1433 -U SA -P 'pdw123!@#' -i sql_scripts/02_create_tables.sql
docker exec mssql /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1,1433 -U SA -P 'pdw123!@#' -i sql_scripts/03_data_init.sql