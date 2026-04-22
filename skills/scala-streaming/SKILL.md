---
name: scala-streaming
description: Use this skill when working with functional data streams in Scala using fs2. Covers Stream API, pipes, chunks, resource-safe I/O, backpressure, parallel processing, merging streams, file/network streaming, WebSocket handling, and stream composition. Trigger when the user mentions streams, fs2, streaming data, pipe processing, backpressure, chunk processing, or needs to process large datasets or continuous data flows — even if they don't explicitly name the library.
---

# Functional Streaming in Scala (fs2)

fs2 is the standard library for functional streaming in Scala. It provides lazy, chunked, effect-polymorphic streams with built-in resource safety and backpressure. Streams compose via pipes, support concurrent processing, and integrate seamlessly with cats-effect.

## Quick Start

```scala
import cats.effect._
import fs2._

// Creating streams
val numbers: Stream[IO, Int] = Stream.range(0, 10)
val effect: Stream[IO, Int]  = Stream.eval(IO(42))

// Transformations
val doubled: Stream[IO, Int] = numbers.map(_ * 2)
val evens: Stream[IO, Int]   = numbers.filter(_ % 2 == 0)

// Effectful operations
val processed: Stream[IO, Int] = numbers.evalMap(i => IO(println(s"Processing $i"); i * 2))

// Consumption
val list: IO[List[Int]] = numbers.compile.toList
val sum: IO[Int]         = numbers.compile.fold(0)(_ + _)
val drain: IO[Unit]      = numbers.compile.drain
```

## Core Concepts

### Stream[F, O]

The core type — a stream that produces values of type `O` while evaluating effects in `F`.

```scala
// Pure (no effects)
val pure: Stream[Pure, Int] = Stream(1, 2, 3)

// Effectful
val effect: Stream[IO, Int] = Stream.eval(IO(42))

// Infinite
val infinite: Stream[IO, Int] = Stream.constant(42)

// Unfold (generate from seed)
Stream.unfold(0)(n => if (n < 10) Some((n, n + 1)) else None)
// 0, 1, 2, ..., 9

// Unfold with effects
Stream.unfoldEval(0)(n => IO(if (n < 10) Some((n, n + 1)) else None))
```

### Pipe[F, I, O]

A stream transformation: `Stream[F, I] => Stream[F, O]`.

```scala
type Pipe[F[_], -I, +O] = Stream[F, I] => Stream[F, O]

val filterPositive: Pipe[IO, Int, Int] = _.filter(_ > 0)
val toUpper: Pipe[IO, String, String]  = _.map(_.toUpperCase)

// Compose pipes
val pipeline: Pipe[IO, Int, String] =
  filterPositive.andThen(_.map(_.toString)).andThen(toUpper)

// Apply with .through
Stream(1, -2, 3).through(filterPositive).through(_.map(_.toString))
```

### Chunk

Efficient immutable batch type used internally by fs2. Operations preserve chunk structure when possible.

```scala
Chunk.singleton(42)
Chunk.seq(List(1, 2, 3))
Chunk.array(Array(1, 2, 3))

// Emit chunks directly
Stream(1, 2, 3).chunks          // Stream[IO, Chunk[Int]]
Stream.range(0, 100).chunkN(3) // Groups into chunks of 3

// Chunk-aware map (more efficient)
Stream.range(0, 10).mapChunks(_.map(_ * 2))
```

### evalMap and evalTap

```scala
// evalMap: effectful transformation
Stream(1, 2, 3).evalMap(i => IO(i * 2))

// evalTap: side effect without changing values
Stream(1, 2, 3).evalTap(i => IO(println(s"Saw $i")))

// parEvalMap: concurrent evaluation
Stream.range(0, 100).parEvalMap(10)(i => IO(i * 2))
```

### bracket and Resource

Resource-safe stream creation. Cleanup runs regardless of success, failure, or cancellation.

```scala
// Stream.bracket
Stream.bracket(IO(openResource()))(
  use = r => Stream.eval(useResource(r))
)(release = r => IO(closeResource(r)))

// Stream.resource (from cats-effect Resource)
def dbConn: Resource[IO, Connection] =
  Resource.make(IO(openConnection()))(c => IO(c.close()))

for {
  conn <- Stream.resource(dbConn)
  row  <- Stream.eval(conn.query("SELECT * FROM users"))
} yield row

// Multiple resources
for {
  db    <- Stream.resource(dbConn)
  cache <- Stream.resource(redisConn)
} yield queryWithCache(db, cache)
```

## Common Patterns

### File Processing

```scala
import fs2.io.file.{Files, Path}
import fs2.text

def transformFile(in: Path, out: Path): IO[Unit] =
  Files[IO].readAll(in)
    .through(text.utf8Decode)
    .through(text.lines)
    .filter(_.nonEmpty)
    .map(_.toUpperCase)
    .intersperse("\n")
    .through(text.utf8Encode)
    .through(Files[IO].writeAll(out))
    .compile.drain
```

### API Pagination

```scala
def fetchPage(page: Int): IO[List[Item]]

def allPages: Stream[IO, Item] =
  Stream.unfoldLoopEval(1) { page =>
    fetchPage(page).map { items =>
      if (items.isEmpty) (Nil, None)
      else (items, Some(page + 1))
    }
  }.flatMap(Stream.emits)
```

### Producer-Consumer

```scala
val producer: Stream[IO, Int]     = Stream.range(0, 100).evalTap(i => IO(println(s"Producing $i")))
val consumer: Pipe[IO, Int, Unit] = _.evalTap(i => IO(println(s"Consuming $i")))

producer.through(consumer).compile.drain
```

### WebSocket Handler

```scala
import fs2.concurrent.SignallingRef

def wsHandler(ws: WebSocket[IO], stop: SignallingRef[IO, Boolean]): Stream[IO, Unit] = {
  val receive = ws.receive.evalTap(msg => IO(println(s"Received: $msg")))
  val send = Stream.awakeEvery[IO](1.second)
    .evalMap(_ => IO("ping"))
    .through(ws.send)
    .interruptWhen(stop.discrete)

  receive.concurrently(send)
}
```

## Advanced Patterns

### Concurrent Processing

```scala
// parEvalMap: up to N concurrent effectful operations
Stream.range(0, 100).parEvalMap(10)(i => IO(heavyComputation(i)))

// parJoin: merge a stream of streams
val streams = (0 until 5).map(i => Stream.eval(process(i)))
Stream(streams: _*).parJoin(3)

// concurrently: run background stream alongside foreground
foreground.concurrently(background).compile.drain
```

### Backpressure Strategies

```scala
// Buffer ahead
source.buffer(100)

// Rate limit: max N per period
source.throttle(10, 1.second, 10)

// Fixed delay between elements
source.metered(100.millis)

// Debounce: emit last after quiet period
events.debounce(200.millis)

// Prefetch: eagerly request ahead of slow consumer
source.through(slowPipe).prefetch(10)

// Conflate: combine when consumer is slow
source.conflate(10, 0)(_ + _)
```

### Merging Streams

```scala
// Merge: interleave elements nondeterministically
s1.merge(s2)

// Merge variants
s1.mergeHaltBoth(s2) // halt when either completes
s1.mergeHaltL(s2)    // halt when left completes

// Broadcast to multiple pipes
source.broadcastThrough(pipe1, pipe2, pipe3)
```

### Time-based Operations

```scala
Stream.awakeEvery[IO](1.second)   // tick every second
Stream.fixedRate[IO](1.second)    // fixed rate
Stream.fixedDelay[IO](1.second)   // fixed delay between elements
Stream.sleep_[IO](1.second)       // delay before stream starts

// Timeout
source.timeout(5.seconds)
source.timeoutTo(5.seconds, Stream.emit(-1))
```

### Stream Interop

```scala
import fs2.interop.flow._

// Java Streams
Stream.fromJavaStream(javaStream)

// Reactive Streams
import fs2.interop.reactivestreams._
Stream.fromPublisher[IO](publisher)
stream.toUnicastPublisher
```

## Error Handling

```scala
// attempt: wrap each element/error in Either
stream.attempt  // Stream[IO, Either[Throwable, O]]
stream.attempt.rethrow  // back to original

// handleErrorWith: recover with fallback stream
stream.handleErrorWith(e => Stream.emit(-1))

// Error-specific handling
stream.handleErrorWith {
  case _: ArithmeticException => Stream.emit(0)
  case e => Stream.raiseError[IO](e)
}

// Retry with delay
stream.attempt.retry(Stream.fixedDelay[IO](1.second).take(3))

// ensure: validate elements
stream.ensure(new Exception("too large"))(_ < 100)
```

## Dependencies

```scala
// fs2 core — check for latest version
libraryDependencies += "co.fs2" %% "fs2-core" % "3.12.+"

// fs2 I/O (file, network)
libraryDependencies += "co.fs2" %% "fs2-io" % "3.12.+"

// Reactive Streams interop
libraryDependencies += "co.fs2" %% "fs2-reactive-streams" % "3.12.+"

// Kafka integration
libraryDependencies += "com.github.fd4s" %% "fs2-kafka" % "3.5.+"
```

## Related Skills

- **scala-async-effects** — IO monad, fibers, Resource, concurrency primitives used by fs2
- **scala-database** — streaming database results with doobie/skunk via fs2
- **scala-messaging** — Kafka and message queue integration with fs2 streams

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/fs2-core.md** — Stream API, transformations, pipes, compilation, Chunk operations, resource safety, testing
- **references/stream-io.md** — File I/O, network streams, WebSocket patterns, HTTP streaming, database streaming, stream interop
- **references/concurrency.md** — Parallel processing, backpressure, merging streams, rate limiting, time-based operations, resource pooling
