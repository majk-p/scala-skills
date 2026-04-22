---
name: scala-messaging
description: Use this skill when working with message queues, messaging systems, or concurrent data processing in Scala. This includes in-memory queues (elasticmq), streaming concurrency (ox), Kafka integration (fs2-kafka), or Pulsar clients. Trigger when the user mentions messaging, queues, Kafka, Pulsar, concurrent processing, or needs to implement producer/consumer patterns.
---

# Message Queues & Concurrency in Scala

Scala provides multiple approaches to message queues and concurrent data processing:

- **ElasticMQ** — In-memory SQS-compatible message queue for testing and lightweight messaging
- **OX** — Direct-style streaming, concurrency, and channels using Project Loom (JDK 21+)
- **fs2-kafka** — Functional Kafka client with cats-effect/fs2 integration
- **Pulsar4s** — Type-safe Scala client for Apache Pulsar

## Quick Start

### ElasticMQ — In-Memory Queue

```scala
import org.elasticmq.rest.sqs._

val server = SQSRestServerBuilder.start()
val queueUrl = server.localAddress() + "/queue/my-queue"
server.stopAndWait()
```

### OX — Channels & Concurrency

```scala
import ox.*

// Parallel computations
val (a, b) = par(
  { Thread.sleep(1000); 1 },
  { Thread.sleep(500); 2 }
)

// Channel communication
val channel = Channel.buffered[String](8)
channel.send("message")
val msg = channel.receive()
```

### fs2-kafka — Functional Kafka

```scala
import fs2.kafka._

val producerSettings = ProducerSettings[IO, String, String]
  .withBootstrapServers("localhost:9092")

val consumerSettings = ConsumerSettings[IO, String, String]
  .withBootstrapServers("localhost:9092")
  .withGroupId("group")
```

### Pulsar4s — Apache Pulsar

```scala
import com.sksamuel.pulsar4s._

val client = PulsarClient("pulsar://localhost:6650")
val producer = client.producer[IO, String](ProducerConfig(Topic("my-topic")))
producer.send("Hello, Pulsar!")
```

## ElasticMQ Core Patterns

### SQS-Compatible API

```scala
import software.amazon.awssdk.services.sqs._

val queueUrl = client.createQueue(
  CreateQueueRequest.builder().queueName("my-queue").build()
).queueUrl()

client.sendMessage(SendMessageRequest.builder()
  .queueUrl(queueUrl).messageBody("message").build())

val receiveResult = client.receiveMessage(
  ReceiveMessageRequest.builder()
    .queueUrl(queueUrl).maxNumberOfMessages(10).waitTimeSeconds(20).build())

receiveResult.messages().forEach { msg =>
  processMessage(msg)
  client.deleteMessage(DeleteMessageRequest.builder()
    .queueUrl(queueUrl).receiptHandle(msg.receiptHandle()).build())
}
```

### FIFO Queues

```scala
val fifoQueue = client.createQueue(
  CreateQueueRequest.builder()
    .queueName("my-queue.fifo")
    .attributesWithStrings(Map("FifoQueue" -> "true"))
    .build()
)

client.sendMessage(SendMessageRequest.builder()
  .queueUrl(fifoQueueUrl).messageBody("message")
  .messageGroupId("group-1").messageDeduplicationId("unique-id").build())
```

## OX Core Patterns

### Channels

```scala
import ox.*

val channel = Channel.buffered[Int](10)

val producer = fork { (1 to 5).foreach(channel.send) }
val consumer = fork { (1 to 5).map(_ => channel.receive()).sum }
```

### Select from Channels

```scala
val channel1 = Channel.rendezvous[Int]()
val channel2 = Channel.rendezvous[String]()

select(
  channel1.receiveClause(),
  channel2.receiveClause()
) match {
  case Channel.Selected.Received(1, msg) => println(s"Got from channel1: $msg")
  case Channel.Selected.Received(2, msg) => println(s"Got from channel2: $msg")
}
```

### Structured Concurrency

```scala
supervised {
  val f1 = fork { task1() }
  val f2 = fork { task2() }
  // Automatic supervision on failure
}
```

## fs2-kafka Core Patterns

### Producer Configuration

```scala
val producerSettings = ProducerSettings[IO, String, String]
  .withBootstrapServers("localhost:9092")
  .withAcks(Acks.All)
  .withEnableIdempotence(true)
```

### Consumer Groups & Offsets

```scala
KafkaConsumer.stream(consumerSettings)
  .evalTap { msg =>
    processMessage(msg.record.value).flatMap { _ =>
      msg.commitOffset
    }
  }
  .compile.drain
```

## Pulsar4s Core Patterns

### Producers

```scala
val producer = client.producer[IO, String](
  ProducerConfig(topic = Topic("my-topic"))
)

val message = ProducerMessage(
  value = "Hello, World!",
  key = Some("my-key"),
  eventTime = Some(EventTime(System.currentTimeMillis()))
)

producer.send(message)
```

### Subscription Types

- **Exclusive** — Single consumer per subscription
- **Shared** — Multiple consumers, round-robin delivery
- **Failover** — One active, others standby
- **Key_Shared** — Same key to same consumer

```scala
val consumer = client.consumer[IO, String](
  ConsumerConfig(
    topics = Seq(Topic("my-topic")),
    subscriptionName = Subscription("my-sub"),
    subscriptionType = SubscriptionType.Shared
  )
)
```

### Schemas

```scala
import io.circe.generic.auto._
import com.sksamuel.pulsar4s.circe._

case class User(id: String, name: String)
val producer = client.producer[IO, User](ProducerConfig(Topic("users")))
producer.send(User("1", "Alice"))
```

## Common Patterns

### Producer/Consumer Pattern

```scala
val channel = Channel.buffered[String](100)

supervised {
  val producer = fork {
    (1 to 100).foreach { i => channel.send(s"message-$i") }
    channel.done()
  }

  val consumer = fork {
    forever {
      val msg = channel.receive()
      processMessage(msg)
    }
  }
}
```

### Error Handling & Retries

```scala
import ox.*

val result = retry(Schedule.exponentialBackoff(100.millis)
  .maxRetries(5).jitter()) {
  riskyOperation()
}
```

## Choosing the Right Library

| Use Case | Library | Why |
|-----------|----------|-----|
| **SQS testing/local** | ElasticMQ | SQS-compatible, lightweight, embeddable |
| **In-memory concurrency** | OX | Direct-style, channels, Loom-based |
| **Kafka integration** | fs2-kafka | Functional, cats-effect, type-safe |
| **Pulsar integration** | Pulsar4s | Type-safe idiomatic Scala, multi-effect |

## Key Considerations

1. **Message Ordering**: FIFO queues preserve order. Kafka preserves order within partitions.
2. **Delivery Guarantees**: At-least-once (Kafka), exactly-once (Pulsar transactions).
3. **Backpressure**: OX channels and fs2-kafka naturally handle backpressure.
4. **Error Handling**: Implement dead letter queues and idempotent consumers.
5. **Testing**: Use embedded/local instances for integration tests.

## Dependencies

```scala
// ElasticMQ
"org.elasticmq" %% "elasticmq-rest-sqs" % "1.6.+"

// OX (requires JDK 21+)
"com.softwaremill.ox" %% "core" % "1.0.+"

// fs2-kafka
"com.github.fd4s" %% "fs2-kafka" % "3.9.+"

// Pulsar4s
"com.clever-cloud.pulsar4s" %% "pulsar4s-core" % "2.12.+",
"com.clever-cloud.pulsar4s" %% "pulsar4s-cats-effect" % "2.12.+"
```

## Related Skills

- **scala-streaming** — when combining message queues with fs2 stream processing
- **scala-akka** — for Akka actor-based messaging patterns
- **scala-async-effects** — for effect-based concurrency primitives

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/kafka.md** — Complete fs2-kafka API reference: producer configuration, consumer groups, offsets, deserialization, admin operations, testing with embedded Kafka, common Kafka patterns
- **references/other-queues.md** — Complete ElasticMQ API reference (queue operations, message operations, FIFO queues, persistence, configuration), OX reference (channels, queues, semaphores, structured concurrency, error handling, flows), Pulsar4s reference (producers, consumers, readers, subscriptions, topics, schemas, batching, authentication, effect integrations)
