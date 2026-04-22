# Kafka (fs2-kafka) - Reference

Complete API reference and advanced patterns for fs2-kafka, the functional Kafka client for Scala.

- [fs2-kafka](#fs2-kafka)
  - [Producer](#fs2-kafka-producer)
  - [Consumer](#fs2-kafka-consumer)
  - [Admin](#fs2-kafka-admin)
  - [Topics & Partitions](#fs2-kafka-topics--partitions)
  - [Consumer Groups](#fs2-kafka-consumer-groups)
  - [Offsets](#fs2-kafka-offsets)
  - [Deserialization](#fs2-kafka-deserialization)
  - [Auto-Commit](#fs2-kafka-auto-commit)
  - [Error Handling](#fs2-kafka-error-handling)
  - [Testing](#fs2-kafka-testing)
- [Pulsar4s](#pulsar4s)

---

## fs2-kafka

fs2-kafka is a functional Kafka client built on fs2 and cats-effect.

### fs2-kafka Producer

#### Producer Configuration

```scala
import fs2.kafka._

val producerSettings: ProducerSettings[IO, String, String] =
  ProducerSettings[IO, String, String]
    .withBootstrapServers("localhost:9092")
    .withAcks(Acks.All) // Wait for all replicas
    .withRetries(3)
    .withClientId("my-producer")
    .withLinger(10.milliseconds)
    .withBatchSize(16384)
    .withEnableIdempotence(true)
```

#### Creating Producer

```scala
val producerResource: Resource[IO, KafkaProducer[IO, String, String]] =
  KafkaProducer.resource(producerSettings)

producerResource.use { producer =>
  for {
    _ <- producer.produceOne("topic", "key", "value")
    _ <- producer.produceOne("topic", "key2", "value2")
  } yield ()
}
```

#### Producing Messages

```scala
// Single message
val record = ProducerRecord("topic", "key", "value")
producer.produceOne(record)

// With headers
val record = ProducerRecord(
  topic = "topic",
  key = "key",
  value = "value",
  headers = Headers("header1", "value1")
)

// With timestamp
val record = ProducerRecord(
  topic = "topic",
  key = "key",
  value = "value",
  timestamp = java.time.Instant.now()
)

// Batch produce
val records = (1 to 100).map { i =>
  ProducerRecord("topic", s"key-$i", s"value-$i")
}

val recordsBatch = ProducerRecords(records)
producer.produce(recordsBatch)
```

#### Producing Streams

```scala
// Stream values to topic
val stream: Stream[IO, ProducerRecord[String, String]] =
  Stream.emits((1 to 100).map { i =>
    ProducerRecord("topic", s"key-$i", s"value-$i")
  })

stream
  .through(produce(producerSettings))
  .compile
  .drain
```

### fs2-kafka Consumer

#### Consumer Configuration

```scala
val consumerSettings: ConsumerSettings[IO, String, String] =
  ConsumerSettings[IO, String, String]
    .withBootstrapServers("localhost:9092")
    .withGroupId("my-group")
    .withAutoOffsetReset(AutoOffsetReset.Earliest)
    .withEnableAutoCommit(false)
    .withAutoCommitInterval(5.seconds)
    .withMaxPollRecords(500)
    .withMaxPollInterval(5.minutes)
```

#### Creating Consumer Stream

```scala
val consumerStream: Stream[IO, CommittableConsumerRecord[IO, String, String]] =
  KafkaConsumer.stream(consumerSettings)

consumerStream
  .evalMap { msg =>
    IO(println(s"Received: ${msg.record.value}")) *>
    msg.commitOffset
  }
  .compile
  .drain
```

#### Manual Commit

```scala
consumerStream
  .evalMap { msg =>
    processMessage(msg.record.value).attempt.flatMap {
      case Right(_) =>
        msg.commitOffset // Commit after success
      case Left(error) =>
        IO.raiseError(error) // Don't commit on failure
    }
  }
  .compile
  .drain
```

#### Batch Commit

```scala
consumerStream
  .groupWithin(100, 5.seconds) // Max 100 records or 5 seconds
  .evalMap { batch =>
    processBatch(batch.map(_.record.value)).as {
      CommittableOffsetBatch[IO, String, String](batch)
    }
  }
  .evalMap { batch =>
    batch.commit // Commit entire batch
  }
  .compile
  .drain
```

### fs2-kafka Admin

#### Admin Configuration

```scala
import fs2.kafka.admin._

val adminSettings: AdminClientSettings[IO] =
  AdminClientSettings[IO]
    .withBootstrapServers("localhost:9092")
```

#### Creating Topics

```scala
KafkaAdminClient.resource(adminSettings).use { admin =>
  for {
    _ <- admin.createTopic(
      topic = "new-topic",
      numPartitions = 3,
      replicationFactor = 1.toShort
    )
    _ <- admin.createTopic(
      topic = "compact-topic",
      numPartitions = 6,
      replicationFactor = 1.toShort,
      topicConfig = Map(
        "cleanup.policy" -> "compact",
        "min.cleanable.dirty.ratio" -> "0.01"
      )
    )
  } yield ()
}
```

#### Listing Topics

```scala
KafkaAdminClient.resource(adminSettings).use { admin =>
  for {
    topicNames <- admin.listTopicNames()
    _ <- topicNames.traverse { name =>
      IO(println(s"Topic: $name"))
    }
  } yield ()
}
```

#### Topic Descriptions

```scala
KafkaAdminClient.resource(adminSettings).use { admin =>
  for {
    descriptions <- admin.describeTopics(NonEmptyList.of("topic1", "topic2"))
    _ <- descriptions.toList.traverse { desc =>
      IO(println(s"${desc.topicName}: partitions=${desc.partitions.size}"))
    }
  } yield ()
}
```

### fs2-kafka Topics & Partitions

#### Partition Count

```scala
val consumerSettings = ConsumerSettings[IO, String, String]
  .withGroupId("my-group")

KafkaConsumer.stream(consumerSettings)
  .evalMap { msg =>
    IO(println(s"Partition: ${msg.record.partition}, Offset: ${msg.record.offset}")) *>
    msg.commitOffset
  }
  .compile
  .drain
```

#### Assignment Changes

```scala
val consumerStream = KafkaConsumer.stream(consumerSettings)

consumerStream
  .evalTap { msg =>
    msg.record.consumerGroupMetadata match {
      case Some(metadata) =>
        IO(println(s"Assigned: ${metadata.topicPartitions}"))
      case None => IO.unit
    }
  }
  .compile
  .drain
```

### fs2-kafka Consumer Groups

#### Consumer Group Concepts

- Each consumer group maintains its own offsets
- Partitions in a topic are distributed among group members
- Only one consumer per partition at a time

#### Manual Partition Assignment

```scala
val settings = ConsumerSettings[IO, String, String]
  .withGroupId("my-group")
  .withAutoOffsetReset(AutoOffsetReset.Earliest)
  .withManualAssignment(
    NonEmptyList.of(
      TopicPartition("topic1", 0),
      TopicPartition("topic1", 1)
    )
  )
```

### fs2-kafka Offsets

#### Auto-Offset Reset

```scala
// Earliest - read from beginning
ConsumerSettings[IO, String, String]
  .withAutoOffsetReset(AutoOffsetReset.Earliest)

// Latest - read new messages only
ConsumerSettings[IO, String, String]
  .withAutoOffsetReset(AutoOffsetReset.Latest)

// None - throw exception if no committed offset
ConsumerSettings[IO, String, String]
  .withAutoOffsetReset(AutoOffsetReset.None)
```

#### Seeking to Specific Offset

```scala
val settings = ConsumerSettings[IO, String, String]
  .withSeekTo(
    NonEmptyList.of(
      TopicPartition("topic", 0) -> OffsetAndMetadata(100L)
    )
  )
```

### fs2-kafka Deserialization

#### String Deserializer

```scala
implicit val keyDeserializer: Deserializer[IO, String] =
  Deserializer[IO, String]

implicit val valueDeserializer: Deserializer[IO, String] =
  Deserializer[IO, String]

val settings = ConsumerSettings[IO, String, String]
```

#### Avro Deserialization

```scala
import fs2.kafka.vulcan._

import io.confluent.kafka.serializers.KafkaAvroSerializer
import io.confluent.kafka.deserializers.KafkaAvroDeserializer

case class User(id: String, name: String)

implicit val userSchema: Schema[User] = ???
implicit val userCodec: Codec[User] = ???

implicit val avroDeserializer: AvroDeserializer[IO, User] =
  AvroDeserializer[IO].using[User]

val settings = ConsumerSettings[IO, String, User]
  .withValueDeserializer(avroDeserializer)
```

### fs2-kafka Auto-Commit

#### Enable Auto-Commit

```scala
val settings = ConsumerSettings[IO, String, String]
  .withEnableAutoCommit(true)
  .withAutoCommitInterval(5.seconds)

KafkaConsumer.stream(settings)
  .evalMap { msg =>
    IO(println(msg.record.value))
    // No need to commit offset
  }
  .compile
  .drain
```

#### Disable Auto-Commit

```scala
val settings = ConsumerSettings[IO, String, String]
  .withEnableAutoCommit(false)

KafkaConsumer.stream(settings)
  .evalMap { msg =>
    processMessage(msg.record.value).flatMap { _ =>
      msg.commitOffset // Manual commit
    }
  }
  .compile
  .drain
```

### fs2-kafka Error Handling

#### Producer Errors

```scala
producerSettings
  .withRetries(3)
  .withRetryBackoff(100.milliseconds)

// Handle produce errors
val result = producer.produceOne(record).attempt
result match {
  case Right(metadata) =>
    IO(println(s"Produced to ${metadata.topic}"))
  case Left(error) =>
    IO.raiseError(new Exception(s"Failed to produce: $error"))
}
```

#### Consumer Errors

```scala
KafkaConsumer.stream(consumerSettings)
  .evalTap { msg =>
    processMessage(msg.record.value).attempt.flatMap {
      case Right(_) =>
        msg.commitOffset
      case Left(error) =>
        IO(println(s"Error processing: $error")).as {
          CommittableOffset(batch, msg.offset)
        }
        // Still commit even if processing fails
    }
  }
  .compile
  .drain
```

### fs2-kafka Testing

#### Embedded Kafka with Testcontainers

```scala
import com.dimafeng.testcontainers.GenericContainer

val kafka = GenericContainer(
  "confluentinc/cp-kafka:latest"
).withExposedPorts(9092, 9093).withEnv(
  "KAFKA_ZOOKEEPER_CONNECT" -> "zookeeper:2181",
  "KAFKA_ADVERTISED_LISTENERS" -> "PLAINTEXT://kafka:9092"
)

kafka.start()
val kafkaHost = kafka.getHost
val kafkaPort = kafka.getMappedPort(9092)

val bootstrapServers = s"$kafkaHost:$kafkaPort"

val producerSettings = ProducerSettings[IO, String, String]
  .withBootstrapServers(bootstrapServers)

// ... test with embedded Kafka
```

#### Embedded-Kafka Library

```scala
import embeddedkafka.EmbeddedKafka._

val embeddedKafka = EmbeddedKafka.start()
val bootstrapServers = embeddedKafka.config.bootstrapServers

val producerSettings = ProducerSettings[IO, String, String]
  .withBootstrapServers(bootstrapServers)

// ... test code ...

embeddedKafka.stop()
```

---
## Common Patterns

### Common Producer/Consumer

#### Basic Pattern

```scala
// Generic producer/consumer using OX channels
val channel = Channel.buffered[String](100)

supervised {
  val producer = fork {
    (1 to 1000).foreach { i =>
      channel.send(s"message-$i")
    }
    channel.done()
  }

  val consumer = fork {
    forever {
      val msg = channel.receive()
      processMessage(msg)
    }
  }

  producer.join()
}
```

#### Multi-Producer Pattern

```scala
val channel = Channel.buffered[Int](100)

supervised {
  val producers = (1 to 5).map { i =>
    fork {
      val source = (i * 100 + 1) to (i * 100 + 100)
      source.foreach { n =>
        channel.send(n)
      }
    }
  }

  val consumer = fork {
    var sum = 0
    var count = 0
    while (count < 500) {
      sum += channel.receive()
      count += 1
    }
    sum
  }

  consumer.join()
}
```

### Common Message Ordering

#### FIFO Ordering (ElasticMQ)

```scala
// Use FIFO queue for ordering
client.createQueue(
  CreateQueueRequest.builder()
    .queueName("ordered-queue.fifo")
    .attributesWithStrings(Map(
      "FifoQueue" -> "true"
    ))
    .build()
)

// Send with message groups
client.sendMessage(
  SendMessageRequest.builder()
    .queueUrl(fifoQueueUrl)
    .messageBody("message")
    .messageGroupId("group-1")
    .messageDeduplicationId(UUID.randomUUID().toString)
    .build()
)
```

#### Kafka Partition Ordering

```scala
// Same key goes to same partition
val record = ProducerRecord("topic", "user-123", "user data")
producer.produceOne(record)

// Or specify partition explicitly
val record = ProducerRecord(
  topic = "topic",
  partition = 0,
  key = "key",
  value = "value"
)
```

### Common Delivery Guarantees

#### At-Least-Once (Kafka)

```scala
// Default Kafka behavior - may duplicate messages
val consumerSettings = ConsumerSettings[IO, String, String]
  .withEnableAutoCommit(false)

KafkaConsumer.stream(consumerSettings)
  .evalMap { msg =>
    processMessage(msg.record.value).flatMap { _ =>
      msg.commitOffset
    }
  }
  .compile
  .drain
```

#### Exactly-Once (Pulsar Transactions)

```scala
val producer = client.producer[IO, String](
  ProducerConfig(
    topic = Topic("my-topic"),
    sendTimeout = Some(30.seconds)
  )
)

// Transactional producer
producer.beginTransaction()
producer.send("message1")
producer.send("message2")
producer.commitTransaction()
```

#### Idempotent Consumers

```scala
val processed = scala.collection.concurrent.TrieMap.empty[String, Unit]

def processMessage(id: String, payload: String): IO[Unit] =
  processed.get(id) match {
    case Some(_) =>
      IO.println(s"Skipping duplicate: $id")
    case None =>
      doWork(payload).flatMap { _ =>
        IO(processed.put(id, ()))
      }
  }
```

### Common Backpressure

#### Channel Backpressure (OX)

```scala
val boundedChannel = Channel.buffered[String](10)

// Producer slows if channel is full
val producer = fork {
  (1 to 10000).foreach { i =>
    channel.send(s"message-$i") // Blocks if full
  }
}

// Consumer controls flow rate
val consumer = fork {
  while (true) {
    val msg = channel.receive() // Blocks if empty
    Thread.sleep(100) // Slow processing
    processMessage(msg)
  }
}
```

#### fs2-kafka Backpressure

```scala
// fs2 streams naturally handle backpressure
val stream: Stream[IO, ProducerRecord[String, String]] =
  Stream.emits(messages)

stream
  .through(produce(producerSettings))
  .compile
  .drain

// If consumer can't keep up, fetch automatically throttles
KafkaConsumer.stream(consumerSettings)
  .evalMap { msg =>
    slowProcess(msg) // Backpressure propagates
  }
  .compile
  .drain
```

### Common Dead Letter Queues

#### ElasticMQ DLQ

```scala
val mainQueue = client.createQueue(
  CreateQueueRequest.builder().queueName("main-queue").build()
)

val dlq = client.createQueue(
  CreateQueueRequest.builder().queueName("main-queue-dlq").build()
)

val dlqArn = s"arn:aws:sqs:elasticmq:000000000000:main-queue-dlq"

val redrivePolicy = s"""{
  "deadLetterTargetArn": "$dlqArn",
  "maxReceiveCount": "3"
}"""

val mainWithDLQ = client.createQueue(
  CreateQueueRequest.builder()
    .queueName("main-queue-with-dlq")
    .attributesWithStrings(Map("RedrivePolicy" -> redrivePolicy))
    .build()
)
```

#### Custom DLQ Pattern

```scala
val mainChannel = Channel.buffered[String](100)
val dlqChannel = Channel.buffered[String](100)

supervised {
  val producer = fork {
    (1 to 100).foreach { i =>
      mainChannel.send(s"message-$i")
    }
    mainChannel.done()
  }

  val consumer = fork {
    forever {
      val msg = mainChannel.receive()
      processMessage(msg).attempt.flatMap {
        case Right(_) => IO.unit
        case Left(_) => dlqChannel.send(msg) // Failed messages go to DLQ
      }
    }
  }

  val dlqHandler = fork {
    while (true) {
      val msg = dlqChannel.receive()
      logDLQMessage(msg)
    }
  }

  producer.join()
}
```

### Common Retry Strategies

#### Exponential Backoff (OX)

```scala
import ox.*

val result = retry(Schedule.exponentialBackoff(100.millis)
  .maxRetries(5)
  .jitter()) {
  unstableOperation()
}

// With maximum interval
val result = retry(Schedule.exponentialBackoff(100.millis)
  .maxRetries(10)
  .maxInterval(5.minutes)
  .jitter()) {
  externalApiCall()
}
```

#### Linear Backoff

```scala
val result = retry(Schedule.linear(1.second)
  .maxRetries(5)) {
  attemptDatabaseConnection()
}
```

#### Custom Retry Logic

```scala
def retryWithBackoff[F[_]: cats.effect.Monad](
  operation: F[Unit],
  maxRetries: Int,
  initialDelay: FiniteDuration
): F[Unit] = ???

// Usage:
retryWithBackoff[IO](
  sendMessage(msg),
  maxRetries = 3,
  initialDelay = 1.second
)
```

### Common Testing Message Systems

#### ElasticMQ Tests

```scala
import org.scalatest._
import org.scalatest.matchers.should.Matchers._

class MessageQueueSpec extends AnyFlatSpec with Matchers {
  "ElasticMQ" should "send and receive messages" in {
    val server = SQSRestServerBuilder.start()
    val client = createSqsClient(server.localAddress())

    val queueUrl = client.createQueue(
      CreateQueueRequest.builder().queueName("test-queue").build()
    ).queueUrl()

    client.sendMessage(
      SendMessageRequest.builder()
        .queueUrl(queueUrl)
        .messageBody("test message")
        .build()
    )

    val received = client.receiveMessage(
      ReceiveMessageRequest.builder().queueUrl(queueUrl).build()
    )

    received.messages().size shouldBe 1
    received.messages().get(0).body() shouldBe "test message"

    server.stopAndWait()
  }
}
```

#### Kafka Tests

```scala
import embeddedkafka.EmbeddedKafka._
import cats.effect.testing.scalatest.AsyncIOSpec

class KafkaSpec extends AsyncIOSpec {
  "Kafka" should "send and consume messages" in {
    val embeddedKafka = EmbeddedKafka.start()
    val bootstrapServers = embeddedKafka.config.bootstrapServers

    val producerSettings = ProducerSettings[IO, String, String]
      .withBootstrapServers(bootstrapServers)

    val consumerSettings = ConsumerSettings[IO, String, String]
      .withBootstrapServers(bootstrapServers)
      .withGroupId("test-group")
      .withAutoOffsetReset(AutoOffsetReset.Earliest)

    (for {
      _ <- KafkaProducer.resource(producerSettings).use { producer =>
        producer.produceOne(ProducerRecord("test-topic", "key", "value"))
      }

      results = KafkaConsumer.stream(consumerSettings)
        .take(1)
        .evalMap { msg =>
          IO(msg.record.value shouldBe "value").as(msg.commitOffset)
        }
        .compile
        .last
    } yield results).assert

    embeddedKafka.stop()
  }
}
```

### Common Performance Optimization

#### Batch Processing

```scala
// Process messages in batches for efficiency
val batchStream = KafkaConsumer.stream(consumerSettings)
  .groupWithin(100, 5.seconds)
  .evalMap { batch =>
    processBatch(batch.map(_.record.value))
  }
  .compile
  .drain
```

#### Parallel Processing

```scala
// OX - parallel processing
val channel = Channel.buffered[Int](100)

supervised {
  // Single producer
  fork {
    (1 to 10000).foreach(channel.send)
    channel.done()
  }

  // Multiple consumers
  (1 to 10).map { _ =>
    fork {
      while (true) {
        val msg = channel.receiveOrNone(100.millis)
        msg.foreach(processMessage)
      }
    }
  }
}
```

#### Consumer Group Scaling

```scala
// Kafka - scale by adding consumers
val consumerSettings = ConsumerSettings[IO, String, String]
  .withGroupId("my-group")
  .withAutoOffsetReset(AutoOffsetReset.Earliest)

// Start multiple consumer instances
val instances = (1 to 5).map { i =>
  KafkaConsumer.stream(consumerSettings)
    .evalMap(processMessage)
    .compile
    .drain
}

// Each instance gets a subset of partitions
```

---

## Summary

This reference provides comprehensive coverage of:

- **ElasticMQ**: SQS-compatible in-memory queue for testing
- **OX**: Direct-style concurrency and streaming with Loom
- **fs2-kafka**: Functional Kafka client
- **Pulsar4s**: Type-safe Pulsar client

Common patterns include producer/consumer implementations, error handling, backpressure, testing, and performance optimization.

For usage in agent contexts, activate the `message-queues` skill when working with any of these libraries or implementing messaging patterns.
