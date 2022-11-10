# Introduction

The example shows how to join three streams together using KSQL using foreign key relations. While foreign key is not a concept in KSQL in is a useful way of thinking about it as the three streams are sourced from a relational database where they are modelled as such.

> **Disclaimer**: This code is provided as-is and should be tested and likely tweaked before used in production environments.

The tables in question are modelled as follows and each have a corresponding cdc stream:

```
+-----------------+          +-----------------+          +-----------------+
| location        |          | department      |          | emplouee        |
+-----------------+          +-----------------+          +-----------------+
| id int          |<----+    | id int          |<----+    | id int          |
| ts datetime     |     |    | ts datetime     |     |    | ts datetime     |
| name string     |     |    | name string     |     |    | name string     |
+-----------------+     +--- | loc_id int      |     +--- | loc_id int      |
                             +-----------------+          +-----------------+
```

## The Challenge

In this specific use case the goal is to:
- 1 Denormalize location and department to a flat employee stream and,
- 2 Trigger changes for an update that happens on any of the tables which means that,
- 3 Changes should cascase from parent streams to child stream (denormalized employee).

This is not as straight forward as it might seem doing in KSQL.

Generally it is common to assume, when new to KSQL, that KSQL for Kafka is similar to SQL for Relational database as they share some syntactial similarities. However, seen from a relational point of view there are many limitations on the side of KSQL but the key reason for it is that it operates on streams rather than tables. The good news is that it is possible to create tables from streams as we will be exploiting in this example.

Specific to the use case at hand, the ability to join on a foreign key, is new and is only supported when joining `stream->table` or `table->table`, more information can be found in the [documentation](https://docs.ksqldb.io/en/latest/developer-guide/joins/join-streams-and-tables/).

> What is not explitly stated is that joins only go one level, that is to say, you cannot join arbitrary levels `table_0->table_1->table_2->...->table_n`. You can do N-way joins so long as it's flat, like a star schema. It is possible however to join `stream_0->table_0->table_1` but no more. The way to get around is is to handle joins individually into new streams and chain it, eg. `stream_0->table_0` into `stream_1` and then `stream_1->table_1` into `stream_2` and so on.

The other challenge is that as only joins that go _upwards_ that is from a foreign key on a stream or table _up_ to a primary key on a table. It is not possible to go _downwards_ that is from a primary key on a table or stream and _down_ to a table and expand the referenced records. This makes sense when you think about it from a streams perspective.

## The solution

The solution proposed here is three different output streams that share structure but triggered by the different sources upstream. In order to overcome the join limitations as mentioned above there will be used two "index" tables, one that allows to get employee ids from table and one to get department id from location. The index will be built using the [COLLECT_SET](https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-reference/aggregate-functions/#collect_set) function which allows grouping of the primary key on the foreign key, eg. {department_id: 1, employee_ids: [1, 2, 3]} from the employee table. Because this table is now keyed on the department id, a change on department id 1 can me replicated into 3 employee key using the [EXPLODE](https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-reference/table-functions/#synopsis) table function, which in turn allows us to join with the employee and enrich.

The similar pattern can be reused for location, but this has to repeat the same excercise two times in order to get down to employee as can be viewd in the KSQL code. For the same reason, the overall solution can be a bit verbose, in particular if this has to be done for more levels of join, but it forms a general pattern.

The logical diagram looks as follows in two parts:

The support tables/indexes:

```

+-----------------+     +-----------------+
| employee str    |-----| employee tab    |
+-----------------+     +-----------------+

+-----------------+     +-----------------+
| department str  |-----| department tab  |
+-----------------+     +-----------------+

+-----------------+     +-----------------+
| department str  |-----| department tab  |
+-----------------+     +-----------------+

+-----------------+     +-----------------+
| employee str    |-----| department ix   |
+-----------------+     +-----------------+

+-----------------+     +-----------------+
| department str  |-----| location ix     |
+-----------------+     +-----------------+

```

The three streams delivering output:

```

+-----------------+                                                                    +-----------------+
| employee str    |------------------------------------------------------------------->| OUTPUT_STREAM_1 |
+-----------------+        ^                 ^                                         +-----------------+
                           |                 |
+-----------------+        |                 |
| departmen tab   |--join--+                 |
+-----------------+                          |
                                             |
                  +-----------------+        |
                  | department tab  |--join--+
                  +-----------------+

+-----------------+  (exp employee)                                                    +-----------------+
| department str  |------------------------------------------------------------------->| OUTPUT_STREAM_2 |
+-----------------+        ^                 ^                 ^                       +-----------------+
                           |                 |                 |
+-----------------+        |                 |                 |
| employee ix     |--join--+                 |                 |
+-----------------+                          |                 |
                                             |                 |
                  +-----------------+        |                 |
                  | employee tab    |--join--+                 |
                  +-----------------+                          |
                                                               |
                                    +-----------------+        |
                                    | location tab    |--join--+
                                    +-----------------+

+-----------------+ (exp department)   (exp employee)                                  +-----------------+
| location str    |------------------------------------------------------------------->| OUTPUT_STREAM_3 |
+-----------------+        ^                 ^                 ^                 ^     +-----------------+
                           |                 |                 |                 |
+-----------------+        |                 |                 |                 |
| location   ix   |--join--+                 |                 |                 |
+-----------------+                          |                 |                 |
                                             |                 |                 |
                  +-----------------+        |                 |                 |
                  | department ix   |--join--+                 |                 |
                  +-----------------+                          |                 |
                                                               |                 |
                                    +-----------------+        |                 |
                                    | department tab  |--join--+                 |
                                    +-----------------+                          |
                                                                                 |
                                                                                 |
                                                      +-----------------+        |
                                                      | location tab    |--join--+
                                                      +-----------------+

```

One catch to keep in mind is that for instance the employee and department streams are read 3 times and the location stream is read 2 times. This is a current limitation in KSQL since there is no ability to fork or split a stream into multiple outputs. The impact is not necessarily a huge one, but it does require scaling considerations when it comes to number of rows + number and level of joins needed. Some ideas to play around with are the [Event Splitter](https://developer.confluent.io/patterns/event-processing/event-splitter/) and [Event Router](https://developer.confluent.io/patterns/event-processing/event-router/) patterns.

Another thing is that there are 3 outputs rather than one. This can be overcomed by using a [Event Stream Merger](https://developer.confluent.io/patterns/stream-processing/event-stream-merger/) or by using a client library such as Java or .Net that allows you to subscribe to multiple topics that share a schema. Thing to keep in mind is when consuming from multiple topics where the same key can appear in all topics is that there can be a reace condition that could cause an out of date value to receive after the latest one. To get around this, it is recommended that a timestamp from the record that triggered the change to be added the output record.

## Getting Started

This example is using docker compose that will spin up a Microsoft SQL Server and a Confluent Platform on the same docker network. The docker needs to be able to access the internet in order to install the JDBC Connector for Kafka Connect using the provided scripts. Alternatively the script can be modified to use a proxy or install via other means.

To initialize the environment run the following commands from the directory:
- Run `$ docker-compose up -d` to get the docker environment up. Wait a few seconds afterwards for the services to come up.
- Run `$ ./01_initialize_db` to initialize the database schema and data.
- Run `$ ./02_install_jdbc.sh.sh` to install JDBC provider. Wait a few seconds afterwards to allow the connect service to be restarted.
- Run `$ ./03_create_source_connectors.sh` to create a source connector for the database tables.
- Run `$ ./04_define_ksql.sh.sh` to create the KSQL tables and streams.

This sets up the streaming solution from database to output topics. The initial dataset is 8 employees divided evenly between 4 departments which are divided evently beteen 2 locations. This will later be used to shows the correctness of the solution.

## Testing using KSQL CLI

It is recommended to run four terminals to run the example effectively.

In terminal #1 - Run the following command to subscribe to changes from the employee stream. We are setting offset to earliest because we want the initial data.

```
docker exec -i ksqldb-cli ksql --execute "SET 'auto.offset.reset'='earliest'; SELECT * FROM CHANGES_BY_EMPLOYEE EMIT CHANGES;" -- http://ksqldb-server:8088
```

In terminal #2 - Run the following command to subscribe to changes from the department stream. We are _not_ setting offset to earliest because we already have the initial data.

```
docker exec -i ksqldb-cli ksql --execute "SELECT * FROM CHANGES_BY_DEPARTMENT EMIT CHANGES;" -- http://ksqldb-server:8088
 ```

In terminal #3 - Run the following command to subscribe to changes from the department stream. We are _not_ setting offset to earliest because we already have the initial data.

 ```
docker exec -i ksqldb-cli ksql --execute "SELECT * FROM CHANGES_BY_LOCATION EMIT CHANGES;" -- http://ksqldb-server:8088
 ```

 Notice the similar structure of the outputs.

 In terminal #4 - Run the following commands:

```
docker exec mssql /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1,1433 -U SA -P 'pdw123!@#' -d test -q "update employee set name = name where id = 1"
```

This should result in 1 new record being outputted in Terminal #1.

```
docker exec mssql /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1,1433 -U SA -P 'pdw123!@#' -d test -q "update department set name = name where id = 1"
```

This should result in 2 new record being outputted in Terminal #2. Notice the department id being the same for all records.

```
docker exec mssql /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1,1433 -U SA -P 'pdw123!@#' -d test -q "update location set name = name where id = 1"
```

This should result in 4 new record being outputted in Terminal #4. Notice the location id being the same for all records.

## Testing .Net Client

There is a code example for .Net and it can be tested out by building and running the project using the following commands:

```
$ dotnet build client/TestClient

$ dotnet build --project client/TestClient/TestClient.csproj
```

> Note that this example does not handle deletes, but this does not alter the approach, other than a 'delete' marked key has to be able to be propogated through the pipe as part of the overall CDC solution.