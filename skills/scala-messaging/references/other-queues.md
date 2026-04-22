# Other Message Queues - Reference

Complete API reference for ElasticMQ, OX, and Pulsar4s.

- [ElasticMQ](#elasticmq)
  - [Queue Operations](#elasticmq-queue-operations)
  - [Message Operations](#elasticmq-message-operations)
  - [Queue Attributes](#elasticmq-queue-attributes)
  - [Testing Mode](#elasticmq-testing-mode)
  - [Persistence](#elasticmq-persistence)
  - [Configuration](#elasticmq-configuration)
- [OX](#ox)
  - [Channels](#ox-channels)
  - [Queues](#ox-queues)
  - [Semaphores](#ox-semaphores)
  - [Structured Concurrency](#ox-structured-concurrency)
  - [Error Handling](#ox-error-handling)
  - [Scheduling](#ox-scheduling)
  - [Resiliency](#ox-resiliency)
  - [Flows](#ox-flows)
  - [Direct Style & Loom](#ox-direct-style--loom)
  - [Producers](#pulsar4s-producers)
  - [Consumers](#pulsar4s-consumers)
  - [Readers](#pulsar4s-readers)
  - [Subscriptions](#pulsar4s-subscriptions)
  - [Topics](#pulsar4s-topics)
  - [Schemas](#pulsar4s-schemas)
  - [Batching](#pulsar4s-batching)
  - [Authentication](#pulsar4s-authentication)
  - [Effect Integrations](#pulsar4s-effect-integrations)
- [Common Patterns](#common-patterns)
  - [Producer/Consumer](#common-producerconsumer)
  - [Message Ordering](#common-message-ordering)
  - [Delivery Guarantees](#common-delivery-guarantees)
  - [Backpressure](#common-backpressure)
  - [Dead Letter Queues](#common-dead-letter-queues)
  - [Retry Strategies](#common-retry-strategies)
  - [Testing Message Systems](#common-testing-message-systems)
  - [Performance Optimization](#common-performance-optimization)

---

## ElasticMQ

ElasticMQ is an in-memory message queue with an Amazon SQS-compatible interface. It's ideal for testing SQS applications or as a lightweight message broker.

### ElasticMQ Queue Operations

#### Creating Queues

```scala
import software.amazon.awssdk.services.sqs._

val client: SqsClient = SqsClient.builder()
  .endpointOverride(URI.create("http://localhost:9324"))
  .build()

// Simple queue
val createResponse = client.createQueue(
  CreateQueueRequest.builder()
    .queueName("my-queue")
    .build()
)

// Queue with attributes
val queueUrl = client.createQueue(
  CreateQueueRequest.builder()
    .queueName("my-queue-attrs")
    .attributesWithStrings(Map(
      "VisibilityTimeout" -> "30",
      "MessageRetentionPeriod" -> "86400",
      "MaximumMessageSize" -> "262144",
      "ReceiveMessageWaitTimeSeconds" -> "20",
      "DelaySeconds" -> "5"
    ))
    .build()
).queueUrl()

// FIFO queue
val fifoUrl = client.createQueue(
  CreateQueueRequest.builder()
    .queueName("my-queue.fifo")
    .attributesWithStrings(Map(
      "FifoQueue" -> "true",
      "ContentBasedDeduplication" -> "true"
    ))
    .build()
).queueUrl()
```

#### Queue Attributes

| Attribute | Type | Description | Default |
|-----------|-------|-------------|---------|
| `VisibilityTimeout` | Integer | Seconds message hidden after receipt | 30 |
| `MessageRetentionPeriod` | Integer | Seconds messages retained | 345600 (4 days) |
| `MaximumMessageSize` | Integer | Max message size in bytes | 262144 (256 KB) |
| `ReceiveMessageWaitTimeSeconds` | Integer | Long polling wait time | 0 |
| `DelaySeconds` | Integer | Initial delivery delay | 0 |
| `FifoQueue` | Boolean | Enable FIFO ordering | false |
| `ContentBasedDeduplication` | Boolean | Deduplicate by content (FIFO only) | false |

#### Listing Queues

```scala
val listResponse = client.listQueues()
listResponse.queueUrls().forEach { url =>
  println(s"Queue: $url")
}
```

#### Deleting Queues

```scala
client.deleteQueue(
  DeleteQueueRequest.builder()
    .queueUrl(queueUrl)
    .build()
)
```

### ElasticMQ Message Operations

#### Sending Messages

```scala
// Simple message
client.sendMessage(
  SendMessageRequest.builder()
    .queueUrl(queueUrl)
    .messageBody("Hello, World!")
    .build()
)

// Message with delay
client.sendMessage(
  SendMessageRequest.builder()
    .queueUrl(queueUrl)
    .messageBody("Delayed message")
    .delaySeconds(60)
    .build()
)

// FIFO message with deduplication
client.sendMessage(
  SendMessageRequest.builder()
    .queueUrl(fifoQueueUrl)
    .messageBody("Ordered message")
    .messageGroupId("group-1")
    .messageDeduplicationId("unique-id-123")
    .build()
)

// Message with attributes
client.sendMessage(
  SendMessageRequest.builder()
    .queueUrl(queueUrl)
    .messageBody("Message with metadata")
    .messageAttributes(Map(
      "Attribute1" -> MessageAttributeValue.builder()
        .stringValue("value1")
        .dataType("String")
        .build()
    ))
    .build()
)
```

#### Batch Sending

```scala
val entries = (1 to 10).map { i =>
  SendMessageBatchRequestEntry.builder()
    .id(s"msg-$i")
    .messageBody(s"Batch message $i")
    .build()
}

client.sendMessageBatch(
  SendMessageBatchRequest.builder()
    .queueUrl(queueUrl)
    .entries(entries)
    .build()
)
```

#### Receiving Messages

```scala
// Single message (short polling)
val receiveResponse = client.receiveMessage(
  ReceiveMessageRequest.builder()
    .queueUrl(queueUrl)
    .maxNumberOfMessages(10)
    .build()
)

receiveResponse.messages().forEach { msg =>
  println(s"Received: ${msg.body()}")
}

// Long polling (wait up to 20 seconds)
val longPollResponse = client.receiveMessage(
  ReceiveMessageRequest.builder()
    .queueUrl(queueUrl)
    .maxNumberOfMessages(10)
    .waitTimeSeconds(20)
    .build()
)

// Receive with attribute filtering
val filteredResponse = client.receiveMessage(
  ReceiveMessageRequest.builder()
    .queueUrl(queueUrl)
    .messageAttributeNames("All")
    .build()
)
```

#### Deleting Messages

```scala
// Delete single message
receiveResponse.messages().forEach { msg =>
  processMessage(msg)
  client.deleteMessage(
    DeleteMessageRequest.builder()
      .queueUrl(queueUrl)
      .receiptHandle(msg.receiptHandle())
      .build()
  )
}

// Batch delete
val deleteEntries = receiveResponse.messages().map { msg =>
  DeleteMessageBatchRequestEntry.builder()
    .id(msg.messageId())
    .receiptHandle(msg.receiptHandle())
    .build()
}

client.deleteMessageBatch(
  DeleteMessageBatchRequest.builder()
    .queueUrl(queueUrl)
    .entries(deleteEntries)
    .build()
)
```

#### Changing Message Visibility

```scala
// Extend visibility timeout (prevent re-delivery)
client.changeMessageVisibility(
  ChangeMessageVisibilityRequest.builder()
    .queueUrl(queueUrl)
    .receiptHandle(message.receiptHandle())
    .visibilityTimeout(60) // Extend to 60 seconds
    .build()
)
```

### ElasticMQ Testing Mode

#### Embedded Server

```scala
import org.elasticmq.rest.sqs._

// Start with default settings
val server = SQSRestServerBuilder.start()
val address = server.localAddress() // e.g., http://localhost:9324
val client = createSqsClient(address)

// Custom port and interface
val customServer = SQSRestServerBuilder
  .withPort(9325)
  .withInterface("localhost")
  .start()

// Use resource for cleanup
SQSRestServerBuilder.start().use { server =>
  val client = createSqsClient(server.localAddress())
  // ... test code ...
}
```

#### Using Testcontainers

```scala
import com.dimafeng.testcontainers.GenericContainer

val elasticmq = GenericContainer(
  "softwaremill/elasticmq-native:latest"
)
elasticmq.withExposedPorts(9324, 9325).start()

val host = elasticmq.getHost
val port = elasticmq.getMappedPort(9324)
val endpoint = s"http://$host:$port"

val client = SqsClient.builder()
  .endpointOverride(URI.create(endpoint))
  .build()
```

### ElasticMQ Persistence

#### Queue Metadata Persistence

```hocon
# config file: queues.conf
queues-storage {
  enabled = true
  path = "/path/to/storage/queues.conf"
}
```

```scala
// Start with persistence
val server = SQSRestServerBuilder
  .withConfig(ConfigFactory.load("queues.conf"))
  .start()
```

#### Message Persistence (H2 Database)

```hocon
# config file: messages.conf
messages-storage {
  enabled = true
  uri = "jdbc:h2:/path/to/elasticmq"
}
```

```scala
val server = SQSRestServerBuilder
  .withConfig(ConfigFactory.load("messages.conf"))
  .start()

// Messages persist across restarts
```

### ElasticMQ Configuration

#### HOCON Configuration

```hocon
include classpath("application.conf")

node-address {
  protocol = http
  host = localhost
  port = 9324
  context-path = ""
}

rest-sqs {
  enabled = true
  bind-port = 9324
  bind-hostname = "0.0.0.0"
  sqs-limits = strict
}

rest-stats {
  enabled = true
  bind-port = 9325
  bind-hostname = "0.0.0.0"
}

aws {
  region = us-west-2
  accountId = 000000000000
}
```

#### Automatic Queue Creation

```hocon
queues {
  "my-queue" {
    defaultVisibilityTimeout = 10 seconds
    delay = 5 seconds
    receiveMessageWait = 0 seconds
    deadLettersQueue {
      name = "my-queue-dlq"
      maxReceiveCount = 3
    }
  }

  "my-queue-dlq" { }

  "test.fifo" {
    fifo = true
    contentBasedDeduplication = true
  }
}
```

---

## OX

OX is a direct-style concurrency and streaming library built on Project Loom (JDK 21+). It provides safe concurrency primitives, channels, and resiliency patterns.

### OX Channels

Channels provide Go-like communication for concurrent computations.

#### Buffered Channels

```scala
import ox.*

// Create buffered channel with capacity
val channel = Channel.buffered[String](10)

// Sending (blocks if full)
channel.send("hello")

// Receiving (blocks if empty)
val msg = channel.receive()

// Send with timeout
val sent = channel.sendOrNone("message", timeout = 1.second)
// sent: Option[String] - None if timeout

// Receive with timeout
val received = channel.receiveOrNone(timeout = 1.second)
// received: Option[String] - None if timeout
```

#### Rendezvous Channels

```scala
// Rendezvous channels have no buffer
val channel = Channel.rendezvous[Int]()

// Both sender and receiver must be ready
supervised {
  fork {
    // This blocks until receiver is ready
    channel.send(42)
  }

  fork {
    // This blocks until sender is ready
    val value = channel.receive()
    println(s"Received: $value")
  }
}
```

#### Selecting from Channels

```scala
val channel1 = Channel.rendezvous[Int]()
val channel2 = Channel.rendezvous[String]()

// Select from multiple channels (non-blocking)
select(
  channel1.receiveClause(),
  channel2.receiveClause()
) match {
  case Channel.Selected.Received(1, msg) =>
    println(s"Got from channel1: $msg")
  case Channel.Selected.Received(2, msg) =>
    println(s"Got from channel2: $msg")
}

// Select with send clause
select(
  channel1.sendClause(100),
  channel2.receiveClause()
) match {
  case Channel.Selected.Sent(1) =>
    println("Sent to channel1")
  case Channel.Selected.Received(2, msg) =>
    println(s"Received from channel2: $msg")
}
```

#### Multiple Producers/Consumers

```scala
val channel = Channel.buffered[Int](100)

// Fan-out: multiple producers
supervised {
  val producers = (1 to 5).map { i =>
    fork {
      (1 to 20).foreach { j =>
        channel.send(i * 100 + j)
      }
    }
  }
  channel.done() // Signal no more messages
}

// Single consumer
val consumer = fork {
  var count = 0
  var sum = 0
  while (count < 100) {
    sum += channel.receive()
    count += 1
  }
  sum
}
consumer.join() // Result: sum of all messages
```

### OX Queues

OX provides typed queues for concurrent data structures.

#### Bounded Queue

```scala
import ox.collections.BoundedQueue

val queue = BoundedQueue.bounded[Int](10)

// Add element (blocks if full)
queue.add(1)

// Try add (returns false if full)
val added = queue.offer(2)

// Remove element (blocks if empty)
val element = queue.remove()

// Try remove (returns Option if empty)
val maybeElement = queue.poll()
```

#### Unbounded Queue

```scala
import ox.collections.UnboundedQueue

val queue = UnboundedQueue.unbounded[String]()

// Add element (never blocks)
queue.add("message")

// Remove element (blocks if empty)
val msg = queue.remove()
```

### OX Semaphores

Semaphores limit concurrent access to resources.

#### Semaphore

```scala
import ox.*

val semaphore = Semaphore(3) // Allow 3 concurrent permits

// Acquire permit (blocks if none available)
semaphore.acquire()
try {
  accessLimitedResource()
} finally {
  semaphore.release()
}

// Acquire with timeout
val acquired = semaphore.acquireOrNone(timeout = 5.seconds)
if (acquired.isDefined) {
  try {
    accessLimitedResource()
  } finally {
    semaphore.release()
  }
}
```

#### Using Semaphore Pattern

```scala
def processLimited[F[_]: ox.Effect](items: List[Int]): F[Unit] = supervised {
  val semaphore = Semaphore(3)

  items.map { item =>
    fork {
      semaphore.acquire()
      try {
        processItem(item)
      } finally {
        semaphore.release()
      }
    }
  }.foreach(_.join())
}
```

### OX Structured Concurrency

Ox provides structured concurrency with automatic supervision.

#### fork

```scala
// Fork a computation
val f1 = fork {
  Thread.sleep(1000)
  "result1"
}

// Wait for result
val result = f1.join() // Blocks until complete
```

#### supervised

```scala
// Supervision scope - children interrupted on failure
supervised {
  val f1 = fork {
    Thread.sleep(1000)
    println("Task 1 complete")
  }

  val f2 = fork {
    Thread.sleep(500)
    throw new RuntimeException("Task 2 failed!")
  }

  // If f2 fails, f1 is interrupted
}
```

#### forkUser

```scala
// User fork: errors don't interrupt siblings
supervised {
  val f1 = forkUser {
    Thread.sleep(1000)
    println("Task 1 complete")
  }

  val f2 = forkUser {
    Thread.sleep(500)
    throw new RuntimeException("Task 2 failed!")
  }

  // f1 continues even if f2 fails
  // Supervisor waits for all to complete
}
```

#### par

```scala
// Run computations in parallel
val (a, b) = par(
  { Thread.sleep(1000); 1 },
  { Thread.sleep(500); 2 }
)
// Completes in ~1000ms, returns (1, 2)

// Triple parallel
val (x, y, z) = par(
  computation1(),
  computation2(),
  computation3()
)
```

### OX Error Handling

#### raceSuccess

```scala
// Return first successful result
val winner = raceSuccess(
  { Thread.sleep(1000); "slow" },
  { Thread.sleep(100); "fast" }
)
// Result: "fast"

// If all fail, throws aggregate exception
val result = raceSuccess(
  { Thread.sleep(100); throw new Exception("fail1") },
  { Thread.sleep(200); "success" }
)
// Result: "success"
```

#### race

```scala
// Return first completed result (success or failure)
val result = race(
  { Thread.sleep(100); "first" },
  { Thread.sleep(200); "second" }
)
// Result: "first"

val error = race(
  { Thread.sleep(100); throw new RuntimeException("boom") },
  { Thread.sleep(200); "later" }
)
// Result: throws RuntimeException
```

#### either

```scala
import ox.either

val v1: Either[String, Int] = Right(42)
val v2: Either[Long, String] = Right("hello")

val result: Either[String | Long, Int | String] = either:
  val i = v1.ok() // Extract Right or throw
  val s = v2.ok()
  (i, s) // Returns (42, "hello")
```

### OX Scheduling

#### retry

```scala
import ox.*

val result = retry(Schedule.exponentialBackoff(100.millis)
  .maxRetries(5)
  .jitter()) {
  riskyOperation()
}

// Custom schedule
val schedule = Schedule.spaced(1.second).maxRetries(10)
retry(schedule)(unstableApi())
```

#### repeat

```scala
// Repeat forever
repeat(Schedule.fixedInterval(100.millis)) {
  pollService()
}

// Repeat with count
repeat(Schedule.fixedInterval(100.millis).take(10)) {
  performAction()
}

// Repeat until predicate
repeat(Schedule.spaced(1.second)) { attempt =>
  attempt < 10 && shouldContinue()
}
```

#### forever

```scala
// Infinite loop with cancellation support
forever {
  val msg = channel.receive()
  processMessage(msg)
}
```

### OX Resiliency

#### Rate Limiters

```scala
import ox.resilience.*

// Fixed window rate limiter
val rateLimiter = RateLimiter.fixedWindowWithStartTime(100, 1.minute)
supervised {
  (1 to 200).foreach { i =>
    rateLimiter.runBlocking {
      apiCall()
    }
  }
}

// Token bucket
val tokenBucket = RateLimiter.tokenBucket(10, 1.second)
supervised {
  (1 to 100).foreach { i =>
    tokenBucket.runBlocking {
      processRequest()
    }
  }
}
```

#### Circuit Breakers

```scala
val breaker = CircuitBreaker.of(
  maxFailures = 5,
  resetTimeout = 1.minute
)

supervised {
  forever {
    try {
      breaker.protect {
        callExternalService()
      }
    } catch {
      case _: CircuitBreakerOpenException =>
        // Circuit is open, use fallback
        useFallback()
    }
  }
}
```

#### Timeouts

```scala
// Timeout a computation
val result = timeout(1.second) {
  longRunningOperation()
}
// Throws TimeoutException if not complete

// Catch timeout
val result = Either.catchOnly[TimeoutException] {
  timeout(5.seconds) {
    compute()
  }
} match {
  case Right(value) => value
  case Left(_) => fallback()
}
```

### OX Flows

Flows provide streaming data transformations with backpressure.

#### Creating Flows

```scala
import ox.flow.*

// From iterator
val flow1 = Flow.fromIterator((1 to 100).iterator)

// From range
val flow2 = Flow.range(1, 100)

// From emit
val flow3 = Flow.usingEmit { emit =>
  (1 to 100).foreach(emit)
}

// Tick (periodic values)
val flow4 = Flow.tick(100.millis, "tick")
```

#### Transformations

```scala
// Map
Flow.range(1, 100)
  .map(_ * 2)

// Filter
Flow.range(1, 100)
  .filter(_ % 2 == 0)

// Take/Drop
Flow.range(1, 100)
  .take(10)
  .drop(5)

// FlatMap
Flow.range(1, 10)
  .flatMap(i => (1 to i).iterator)
```

#### Concurrency in Flows

```scala
// Map with parallelism
def processSlowly(i: Int): Int = ???

Flow.range(1, 100)
  .mapPar(4)(processSlowly)
  // Processes 4 items in parallel

// Buffer between stages
Flow.range(1, 100)
  .buffer(10)
  .mapPar(4)(process)
```

#### Stateful Operations

```scala
// Running total
Flow.fromIterator(List(1, 2, 3, 4, 5).iterator)
  .mapStateful(0) { (state, value) =>
    val newState = state + value
    (newState, newState)
  }
  .runForeach(println)
// Output: 1, 3, 6, 10, 15

// Sliding window
Flow.fromIterator(List(1, 2, 3, 4, 5).iterator)
  .sliding(3)
  .runForeach(window => println(window.toList))
// Output: List(1,2,3), List(2,3,4), List(3,4,5)
```

#### Sink Operations

```scala
// Foreach (consume)
Flow.range(1, 100)
  .runForeach(println)

// Drain (discard)
Flow.range(1, 100)
  .runDrain()

// Fold (aggregate)
val sum = Flow.range(1, 100)
  .runFold(0)(_ + _)

// To list
val list = Flow.range(1, 100)
  .runToList()
```

### OX Direct Style & Loom

OX is designed for direct-style programming with Loom.

#### Virtual Threads

```scala
// All ox.fork uses virtual threads
supervised {
  val fibers = (1 to 10000).map { i =>
    fork {
      Thread.sleep(100)
      process(i)
    }
  }
  fibers.foreach(_.join())
}
// 10,000 concurrent virtual threads, lightweight
```

#### Blocking IO

```scala
// Direct-style blocking is efficient with virtual threads
def fetchFromHttp(url: String): String = {
  java.net.http.HttpClient
    .newHttpClient()
    .send(
      java.net.http.HttpRequest.newBuilder(URI.create(url)).build(),
      java.net.http.HttpResponse.BodyHandlers.ofString()
    )
    .body()
}

supervised {
  val results = par(
    fetchFromHttp("https://api1.com"),
    fetchFromHttp("https://api2.com"),
    fetchFromHttp("https://api3.com")
  )
}
```

#### Resource Management

```scala
import ox.*

def useResource[R](resource: R)(f: R => Unit): Unit =
  try f(resource)
  finally cleanup(resource)

def withFile(path: String): File = ???
def closeFile(file: File): Unit = ???

supervised {
  val file = useResource(withFile("data.txt")) { file =>
    fork {
      file.write("Hello")
    }
    Thread.sleep(1000)
    fork {
      file.read()
    }
  }
}
```

---

## Pulsar4s

Pulsar4s is a type-safe Scala client for Apache Pulsar.

### Pulsar4s Producers

#### Creating Producers

```scala
import com.sksamuel.pulsar4s._

implicit val schema: Schema[String] = Schema.STRING

val client = PulsarClient("pulsar://localhost:6650")

val producer: Producer[IO] = client.producer[IO, String](
  ProducerConfig(
    topic = Topic("my-topic"),
    producerName = Some("my-producer"),
    sendTimeout = Some(30.seconds),
    batchingEnabled = Some(true),
    batchingMaxMessages = Some(1000),
    blockIfQueueFull = Some(true)
  )
)
```

#### Sending Messages

```scala
// Simple send
producer.send("Hello, Pulsar!")

// Async send
producer.sendAsync("async message")

// With key
producer.send("message", Some("my-key"))

// With message options
val message = ProducerMessage(
  value = "payload",
  key = Some("key"),
  eventTime = Some(EventTime(System.currentTimeMillis())),
  properties = Map(
    "header1" -> "value1",
    "header2" -> "value2"
  ),
  sequenceId = Some(1L)
)

producer.send(message)
```

#### Producer Configuration Options

```scala
ProducerConfig(
  topic = Topic("my-topic"),
  producerName = Some("my-producer"),
  sendTimeout = Some(30.seconds),
  blockIfQueueFull = Some(true),
  maxPendingMessages = Some(1000),
  batchingEnabled = Some(true),
  batchingMaxPublishDelay = Some(10.millis),
  batchingMaxMessages = Some(100),
  chunkingEnabled = Some(false),
  compressionType = Some(CompressionType.LZ4),
  cryptoKeyReader = Some(keyReader),
  hashingScheme = Some(HashingScheme.JavaStringHash),
  messageRoutingMode = Some(MessageRoutingMode.CustomPartition),
  properties = Map("custom-prop" -> "value")
)
```

### Pulsar4s Consumers

#### Creating Consumers

```scala
implicit val schema: Schema[String] = Schema.STRING

val consumer: Consumer[IO] = client.consumer[IO, String](
  ConsumerConfig(
    topics = Seq(Topic("my-topic")),
    subscriptionName = Subscription("my-sub"),
    subscriptionType = SubscriptionType.Shared,
    consumerName = Some("my-consumer"),
    receiverQueueSize = Some(1000),
    maxTotalReceiverQueueSizeAcrossPartitions = Some(50000),
    consumerEventListener = Some(listener),
    negativeAckRedeliveryDelaySec = Some(60),
    ackTimeoutMillis = Some(10000L),
    priorityLevel = Some(0),
    readCompacted = Some(false),
    cryptoFailureAction = Some(ConsumerCryptoFailureAction.FAIL),
    properties = Map("custom" -> "value")
  )
)
```

#### Subscription Types

```scala
// Exclusive - single consumer per subscription
SubscriptionType.Exclusive

// Shared - multiple consumers, round-robin delivery
SubscriptionType.Shared

// Failover - one active, others standby
SubscriptionType.Failover

// Key_Shared - same key to same consumer
SubscriptionType.Key_Shared
```

#### Receiving Messages

```scala
// Receive (blocking)
val message: ConsumerMessage[String] = consumer.receive()

// Receive async
val future: Future[ConsumerMessage[String]] = consumer.receiveAsync()

// Receive with timeout
val message: Option[ConsumerMessage[String]] =
  consumer.receive(5.seconds)
```

#### Acknowledging Messages

```scala
consumer.receive.flatMap { msg =>
  processMessage(msg.value).flatMap { _ =>
    // Acknowledge successful processing
    msg.acknowledge
  }
}

// Negative acknowledge (redeliver)
msg.negativeAcknowledge

// Reconsume later (delayed redelivery)
msg.reconsumeLater(1.minute)
```

### Pulsar4s Readers

#### Creating Readers

```scala
val reader: Reader[IO] = client.reader[IO, String](
  ReaderConfig(
    topic = Topic("my-topic"),
    startMessageId = MessageId.earliest,
    receiverQueueSize = Some(1000),
    readerName = Some("my-reader"),
    subscriptionRolePrefix = Some("reader-role"),
    cryptoFailureAction = Some(ConsumerCryptoFailureAction.FAIL),
    readCompacted = Some(false)
  )
)
```

#### Reading Messages

```scala
reader.receive.flatMap { msg =>
  IO(println(msg.value)) *>
  msg.acknowledge
}
```

#### Message Id Options

```scala
// Earliest
MessageId.earliest

// Latest
MessageId.latest

// Specific message
MessageId(ledgerId = 1, entryId = 2, partitionIndex = 3, batchIndex = 4)

// From timestamp
MessageId.fromTimestamp(System.currentTimeMillis())
```

### Pulsar4s Subscriptions

#### Subscription Names

```scala
val sub1 = Subscription("my-subscription")
val sub2 = Subscription("my-subscription", "reader-role")
```

#### Creating Subscription Externally

```scala
val topic = Topic("persistent://my-tenant/my-namespace/my-topic")

// Create subscription before consumer
client.createSubscription(
  SubscriptionConfig(
    topic = topic,
    subscriptionName = Subscription("my-sub"),
    initialPosition = Some(InitialPosition.Latest)
  )
)
```

#### Deleting Subscriptions

```scala
client.deleteSubscription(
  SubscriptionConfig(
    topic = Topic("my-topic"),
    subscriptionName = Subscription("my-sub")
  )
)
```

### Pulsar4s Topics

#### Topic Patterns

```scala
// Non-persistent
Topic("my-topic")
Topic("persistent://my-tenant/my-namespace/my-topic")
Topic("non-persistent://my-tenant/my-namespace/my-topic")

// Partitioned topic
Topic("persistent://my-tenant/my-namespace/my-topic-partition-0")
```

#### Creating Topics

```scala
// Simple topic
client.createTopic(Topic("my-topic"))

// Partitioned topic
client.createPartitionedTopic(
  Topic("my-partitioned-topic"),
  numPartitions = 5
)

// Topic with configuration
client.createTopic(Topic("my-topic"), Map(
  "retentionTimeInMinutes" -> "60",
  "persistence" -> "memory",
  "deduplicationEnabled" -> "true"
))
```

#### Listing Topics

```scala
val topics: List[Topic] = client.topics("persistent://my-tenant/my-namespace")
topics.foreach(println)
```

### Pulsar4s Schemas

#### Built-in Schemas

```scala
implicit val stringSchema: Schema[String] = Schema.STRING
implicit val bytesSchema: Schema[Array[Byte]] = Schema.BYTES
implicit val intSchema: Schema[Int] = Schema.INT32
implicit val longSchema: Schema[Long] = Schema.INT64
implicit val floatSchema: Schema[Float] = Schema.FLOAT
implicit val doubleSchema: Schema[Double] = Schema.DOUBLE
implicit val boolSchema: Schema[Boolean] = Schema.BOOL
```

#### JSON Schemas with Circe

```scala
import io.circe.generic.auto._
import com.sksamuel.pulsar4s.circe._

case class User(id: String, name: String, email: String)

// Schema is automatically derived
val producer = client.producer[IO, User](
  ProducerConfig(Topic("users"))
)

producer.send(User("1", "Alice", "alice@example.com"))

val consumer = client.consumer[IO, User](
  ConsumerConfig(
    topics = Seq(Topic("users")),
    subscriptionName = Subscription("user-consumer")
  )
)
```

#### JSON Schemas with Jackson

```scala
import com.sksamuel.pulsar4s.jackson._

case class Event(type: String, data: String)

val producer = client.producer[IO, Event](
  ProducerConfig(Topic("events"))
)
```

#### Avro Schemas

```scala
import com.sksamuel.pulsar4s.avro._

case class Record(id: Long, value: String)

val producer = client.producer[IO, Record](
  ProducerConfig(Topic("records"))
)
```

### Pulsar4s Batching

#### Producer Batching

```scala
val producer = client.producer[IO, String](
  ProducerConfig(
    topic = Topic("my-topic"),
    batchingEnabled = Some(true),
    batchingMaxMessages = Some(1000),
    batchingMaxPublishDelay = Some(10.millis)
  )
)
// Messages are automatically batched
```

### Pulsar4s Authentication

#### TLS Authentication

```scala
val config = PulsarClientConfig(
  serviceUrl = "pulsar+ssl://localhost:6651",
  tlsTrustCertsFilePath = Some("/path/to/cacert.pem"),
  tlsAllowInsecureConnection = Some(false)
)

val client = PulsarClient(config)
```

#### Token Authentication

```scala
val config = PulsarClientConfig(
  serviceUrl = "pulsar://localhost:6650",
  authentication = Some(
    AuthenticationToken("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
  )
)
```

#### Mutual TLS

```scala
val config = PulsarClientConfig(
  serviceUrl = "pulsar+ssl://localhost:6651",
  tlsTrustCertsFilePath = Some("/path/to/cacert.pem"),
  tlsCertificateFilePath = Some("/path/to/client-cert.pem"),
  tlsKeyFilePath = Some("/path/to/client-key.pem")
)
```

### Pulsar4s Effect Integrations

#### Cats-Effect

```scala
import com.sksamuel.pulsar4s.cats.effect._

val client = PulsarClient[IO]("pulsar://localhost:6650")

val producer = client.producer[IO, String](ProducerConfig(Topic("topic")))

val consumer = client.consumer[IO, String](
  ConsumerConfig(Seq(Topic("topic")), Subscription("sub"))
)

consumer.receive.flatMap { msg =>
  msg.acknowledge *> IO(println(msg.value))
}
```

#### ZIO

```scala
import com.sksamuel.pulsar4s.zio._

val client = PulsarClient[Task]("pulsar://localhost:6650")

val producer = client.producer[Task, String](ProducerConfig(Topic("topic")))

producer.send("message").map { messageId =>
  println(s"Sent: $messageId")
}
```

#### Monix

```scala
import com.sksamuel.pulsar4s.monix._

val client = PulsarClient[Task]("pulsar://localhost:6650")

val consumer = client.consumer[Task, String](
  ConsumerConfig(Seq(Topic("topic")), Subscription("sub"))
)

consumer.receive.flatMap { msg =>
  Task(println(msg.value)) >> msg.acknowledge
}
```

---

