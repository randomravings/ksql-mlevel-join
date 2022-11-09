using Avro.Generic;
using Confluent.Kafka;
using Confluent.SchemaRegistry;
using Confluent.SchemaRegistry.Serdes;
using Confluent.Kafka.SyncOverAsync;

var srConfig = new[] {new KeyValuePair<string, string>("schema.registry.url", "localhost:8081")};
var srClient = new CachedSchemaRegistryClient(srConfig);
var deserializer = new AvroDeserializer<GenericRecord>(srClient);

var config = new ConsumerConfig
{
    BootstrapServers = "localhost:9092",
    GroupId = "foo",
    AutoOffsetReset = AutoOffsetReset.Earliest
};

using var cts = new CancellationTokenSource();
var consumer = new ConsumerBuilder<int, GenericRecord>(config)
    .SetKeyDeserializer(Deserializers.Int32)
    .SetValueDeserializer(deserializer.AsSyncOverAsync())
    .Build();
consumer.Assign(new[]{
    new TopicPartitionOffset("CHANGES_BY_EMPLOYEE", 0, Offset.Beginning),
    new TopicPartitionOffset("CHANGES_BY_DEPARTMENT", 0, Offset.End),
    new TopicPartitionOffset("CHANGES_BY_LOCATION", 0, Offset.End),
});
while(true)
{
    var result = consumer.Consume(cts.Token);
    var k = result.Message.Key;
    var v = result.Message.Value;
    var s = $"{{id:{k},name:{v["EMP_NAME"]},department:{v["DEP_NAME"]},location:{v["LOC_NAME"]},timestmap:{v["TS"]:yyyy-mm-dd HH:mm:ss}}}";
    Console.WriteLine(s);
}