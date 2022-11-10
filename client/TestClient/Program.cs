using Avro.Generic;
using Confluent.Kafka;
using Confluent.SchemaRegistry;
using Confluent.SchemaRegistry.Serdes;
using Confluent.Kafka.SyncOverAsync;

static string Stringify(int k, GenericRecord v) =>
    $"{{{k},name:{v["EMP_NAME"]},department:{v["DEP_NAME"]},location:{v["LOC_NAME"]},timestmap:{v["TS"]:yyyy-mm-dd HH:mm:ss}}}";

static (int Key, GenericRecord Value) Upsert(
    IDictionary<int, GenericRecord> state,
    ConsumeResult<int, GenericRecord> result
)
{
    var k = result.Message.Key;
    var v = result.Message.Value;
    var ts = (DateTime)v["TS"];
    if(!state.TryGetValue(k, out var oldValue))
    {
        Console.WriteLine($"Add: {k}");
        state.Add(k, v);
        return (k, v);
    }
    var oldTs = (DateTime)oldValue["TS"];
    if(oldTs < ts)
    {
        Console.WriteLine($"Upd: {k}");
        state[k] = v;
        return (k, v);
    }
    Console.WriteLine($"Nop: {k}");
    return (k, oldValue);
}

var state = new SortedList<int, GenericRecord>();

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
    new TopicPartitionOffset("CHANGES_BY_DEPARTMENT", 0, Offset.Beginning),
    new TopicPartitionOffset("CHANGES_BY_LOCATION", 0, Offset.Beginning),
});

var loop = Task.Run(() =>{
    Console.WriteLine("Starting loop");
    while(!cts.IsCancellationRequested)
    {
        try
        {
            var result = consumer.Consume(cts.Token);
            if(result != null)
            {
                Console.WriteLine(result.Message.Value);
                (var k, var v) = Upsert(state, result);
                Console.WriteLine(Stringify(k, v));
            }
            
        }
        catch(OperationCanceledException)
        {
            Console.WriteLine("Exiting loop");
        }
        catch(Exception ex)
        {
            Console.WriteLine(ex);
        }
    }
});

Console.ReadLine();
cts.Cancel();
await loop;

Console.WriteLine("Final State:");
foreach(var kv in state)
    Console.WriteLine(Stringify(kv.Key, kv.Value));
return 0;