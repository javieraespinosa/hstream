# HStream

HSTREAM is a project aiming to combine stream and historial data processing in one single plataform. 

HSTREAM is based on the notion of *hybrid query operator*. A hybrid query operator combines the logic for querying a historical data provider with one or several data streams. A query operator can be combined with other query operators for defining a _dataflow_.

Current HSTREAM version provides `MIN`, `MAX`, `AVG`, `COUNT`, `SUM` hybrid query operators. These operators are implemended as [Spark][1] programs developped in Scala that communicates via [RabbitMQ][2]. Current version also supports [InfluxDB][3] as historical data provider.

## Try it

You can try HSTREAM by running the demo. The demo requires [docker][4] and python2. The demo illustrates the implementation in HSTREAM of the following SQL query like. 

```sql
SELECT    MAX (download_speed)
EVERY     5  sec
STARTING  30 sec ago
FROM      InfluxDB::Neubot::DownloadSpeed  # Historical Provider
          RabbitMQ::Neubot                 # Stream input
```

### Starting the Infrastructure

The demo is based on the `hstream` docker image. The image contains the following components:

* Spark Standalone Cluster 
* RabbitMQ
* InfluxDB
* Ruby

Build the image and start the infrastructure as follows:

```sh
# Build hstream image (take some time)
docker-compose build

# add `-d` for running in background
docker-compose up
```

RabbitMQ and Spark provide webUIs. Verify that everything is running as expected by visiting them:

* [Spark webUI][5]
* [RabbitMQ webUI][6] (usr/pwd=**guest**/**guest**)


### Preparing the Historical Provider & Deploying the Operator

The demo assumes the existence of the `Neubot::DownloadSpeed` database in InfluxDB (i.e., the historical provider). The following script inserts the data in `data/neubot_influx.csv` into InfluxDB. Thereafter, it deploys the HSTREAM `MAX` query operator (packaged inside `lib/IoT-Operators-assembly-1.4.jar`) into the spark cluster:

```sh
./start_demo
```

### Starting the Data Producer

The producer simulates a program measuring and sending the network `download_speed`. Start the producer as follows:

```sh
./start_producer
```

The following lines illustrates the data sent by the producer:


```json
1. '{"creation_timestamp":1522964179739,"download_speed":9808}'
2. '{"creation_timestamp":1522964179843,"download_speed":2127}'
3. '{"creation_timestamp":1522964179946,"download_speed":4178}'
4. '{"creation_timestamp":1522964180047,"download_speed":102278}'
5. '{"creation_timestamp":1522964180151,"download_speed":85}'
```


### Output Explanation

The following snipped illustrates operator' initial result:

```sh
5 ROWS:
Timestamp                Count      　Value
2017-10-03 20:52:00.0    7            108437.0
2017-10-03 20:54:00.0    12           65178.0
2017-10-03 20:56:00.0    12           113911.0 << result
2017-10-03 20:58:00.0    12           107199.0
2017-10-03 21:00:00.0    4            17327.0

INITIAL max VALUE = 113911.0
```

This snipped shows how the `MAX` operator divide the `30 sec` window in `5 sec` intervals (time-buckets). For each time-buckets, the operator computes the local maximum and then the global maximum. This is illustrated in the figure below.

![ex](img/demo.gif)

When a new time-bucket is reached, Spark Streaming returns a new row:

```sh
DEBUG: (row from stream)= 2017-10-03 21:00:00.0 7 108677.0
DEBUG: Merging last row with streamed row
4 ROWS:
Timestamp                Count      　Value
2017-10-03 20:54:00.0    12           65178.0
2017-10-03 20:56:00.0    12           113911.0 << result
2017-10-03 20:58:00.0    12           107199.0
2017-10-03 21:00:00.0    11           108677.0

SINK CONSOLE: function = max download_speed: 113911.0
```

In this snipped we can see that, even after receiving new data, the global MAX value remains the same. Eventually, a new row will arrive containing a new MAX value:

```sh
4 ROWS:
Timestamp                Count      　Value
2017-10-03 20:56:00.0    12           113911.0
2017-10-03 20:58:00.0    12           107199.0
2017-10-03 21:00:00.0    11           108677.0
2017-10-03 21:02:00.0    12           337008.0 << result

SINK CONSOLE: function = max download_speed: 337008.0
```

Hence the new MAX value will be updated and the output for the current windows sent to the RabbitMQ output queue. This process continue until the operator is stopped.

## API 

Arguments passed inside `start_demo`.

### Spark parameters

| Argument       | Type          | Meaning  |
| ------------- |-------------| -----|
| --class iotoperator.Max    | argument | The uber jar will contain all the Operators, this argument is to specify the entry class (in this case Max operator) |
| /scripts/IoT-Operators-assembly-1.4.jar | argument | The location of the Jar is in the mounted volume /scripts. The version number of the .jar may change |
| (arguments passed to the jar) |  | Described in next table |

### Operator parameters ('IoTOperators.jar')

| Order | In example | Argument | Meaning  |
|-------|------------|----------|----------|
| 1 | download_speed | name of value | Is the name of the variable/value to be observed. Is the value to be searched in the JSON obtained from the RabbitMQ and in the query to historical |
| 2 | 120000 | Size of the hop size (bucket size) in milliseconds | The **2 minutes** in the query "*every __2 minutes__, give me avg of the last 12 minutes" |
| 3 | 720000 | For sliding window: Size of the window in milliseconds. For landmark: Lookup time | The **12 minutes** in the query "*every 2 minutes, give me avg \[of the last __12 minutes__\]|\[starting __12 minutes__ ago\]" |
| 4 | landmark | Type of window 'landmark' or 'sliding' | **Landmark**: considers the data in the data stream from the beginning until now. **Sliding**: considers the data from now up to a certain range in the past. |
| 5 | influxdb | Historical information provider 'influxdb' or 'cassandra' | Name of the historical information provider |
| 6 | http://root:root@influx:8086 | connection string of the historical provider | In the format http://user:password@hostname:port |
| 7 | neubot | Database name | Name of the Database to query the historical provider |
| 8 | speedtest | Series name | Depending on the historical provider, this can be mapped to a series (in influxdb) or a table (in cassandra) |
| 9 | amqp://guest:guest@rabbit:5672/%2f | Connection string of RabbitMQ to receive input | In the format amqp://user:password@hostname:port/vhost |
| 10 | neubot | Name of input RabbitMQ queue | The queue where Spark Streaming will take the messages from |
| 11 | amqp://guest:guest@rabbit:5672/%2f | Connection string of RabbitMQ to receive input | In the format amqp://user:password@hostname:port/vhost |
| 12 | salida3 | Name of output RabbitMQ queue | The queue where HStream will send the results of the aggregation function. |


## Acknowledgment

HSTREAM was developped by [Enrique Arriaga Varela][7], master student of the Autonomous University of Guadalajara, during his 6 months internship at the Barcelona Supercomputing Center. His intership was financed by the Mexican government through a CONACyT mobility grant ("beca mixta").


[1]: http://spark.apache.org/
[2]: http://rabbitmq.com/
[3]: http://influxdata.com/
[4]: https://www.docker.com/community-edition
[5]: http://localhost:8080
[6]: http://localhost:15672
[7]: https://www.linkedin.com/in/enriquejav/