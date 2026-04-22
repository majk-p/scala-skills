# Concurrency Reference

Complete reference for parallel processing, backpressure strategies, merging streams, rate limiting, time-based operations, and resource pooling with fs2.

## Parallel Processing

### parEvalMap

Process up to N elements concurrently with bounded parallelism.

```scala
// Bounded concurrency
Stream.range(0, 100).parEvalMap(10) { i =>
  IO { Thread.sleep(100); i * 2 }
}

// Unbounded concurrency (use with caution)
Stream.range(0, 100).parEvalMapUnbounded { i =>
  IO(heavyComputation(i))
}
```

### parJoin

Merge a stream of streams with bounded concurrency.

```scala
val streams = (0 until 10).map(i => Stream.eval(process(i)))

// Bounded: max 5 concurrent inner streams
Stream(streams: _*).parJoin(5)

// Unbounded
Stream(streams: _*).parJoinUnbounded
```

### broadcastThrough

Send each element to multiple pipes in parallel, merge results.

```scala
val pipe1: Pipe[IO, Int, String] = _.map(i => s"Pipe1: $i")
val pipe2: Pipe[IO, Int, String] = _.map(i => s"Pipe2: $i")

Stream.range(0, 10).broadcastThrough(10, pipe1, pipe2)
```

### concurrently

Run a background stream alongside the foreground. Background cancels when foreground completes.

```scala
val foreground = Stream.range(0, 10).evalMap(i => IO(println(s"Main: $i")))
val background = Stream.awakeEvery[IO](1.second).evalTap(_ => IO.println("Tick"))

foreground.concurrently(background).compile.drain
```

## Merging Streams

### merge

Interleave elements from two streams nondeterministically.

```scala
val s1 = Stream.range(0, 5)
val s2 = Stream.range(5, 10)

s1.merge(s2)           // elements from both, order not guaranteed
s1.mergeHaltBoth(s2)   // halt when either completes
s1.mergeHaltL(s2)      // halt when left (s1) completes
```

### Interleave

```scala
s1.interleave(s2)  // strictly alternate: s1[0], s2[0], s1[1], s2[1], ...
```

### Zip

```scala
s1.zip(s2)             // (s1[0], s2[0]), (s1[1], s2[1]), ...
s1.zipWith(s2)(_ + _)  // combine with function
```

## Backpressure Strategies

### Buffering

```scala
// Buffer N elements ahead of consumer
source.buffer(100)

// Buffer all elements, emit at end
source.bufferAll

// Buffer with overflow strategy
source.buffer(n)
```

### Rate Limiting

```scala
import scala.concurrent.duration._

// Throttle: max N elements per period, with burst
source.throttle(10, 1.second, 10)

// Metered: fixed rate between elements
source.metered(100.millis)
source.meteredStartImmediately(100.millis)

// Spaced: fixed delay after each element
source.spaced(100.millis)

// Debounce: emit last element after quiet period
events.debounce(200.millis)
```

### Flow Control

```scala
// Prefetch: eagerly request ahead of slow consumer
val slowPipe: Pipe[IO, Int, Int] = _.evalTap(i => IO.sleep(100.millis))
source.through(slowPipe).prefetch(10)

// Conflate: combine elements when consumer falls behind
source.conflate(10, 0)(_ + _)         // sum chunks of 10
source.conflateSemigroup[Int](10)     // use Semigroup combine
```

## Time-based Operations

### Periodic Emission

```scala
// Emit every N duration (emits the elapsed duration)
Stream.awakeEvery[IO](1.second)

// Emit at fixed rate (compensates for processing time)
Stream.fixedRate[IO](1.second)
Stream.fixedRateStartImmediately[IO](1.second)

// Fixed delay between elements (no compensation)
Stream.fixedDelay[IO](1.second)
```

### Delays and Timeouts

```scala
// Delay before stream starts
Stream.sleep_[IO](1.second) ++ Stream(1, 2, 3)

// Timeout entire stream
source.timeout(5.seconds)                  // raises TimeoutException
source.timeoutTo(5.seconds, Stream.emit(-1)) // fallback on timeout
```

### Counting Timer

```scala
Stream.awakeEvery[IO](1.second)
  .scan(0)((acc, _) => acc + 1)
  .evalMap(n => IO(println(s"Tick $n")))
```

## Resource Pooling

### Connection Pool Pattern

```scala
def pool[F[_]]: Resource[F, Queue[F, Connection]] = ???

def processWithPool[F[_]]: Stream[F, Result] =
  for {
    queue  <- Stream.resource(pool)
    result <- Stream.fromQueueUnterminated(queue)
      .evalMap(conn => conn.query("SELECT * FROM users"))
  } yield result
```

### Multiple Concurrent Resources

```scala
def databaseConnection: Resource[IO, Connection] =
  Resource.make(IO.openConnection())(conn => IO(conn.close()))

def redisConnection: Resource[IO, Redis] =
  Resource.make(IO.connectRedis())(conn => IO(conn.close()))

val program: Stream[IO, Result] = for {
  db    <- Stream.resource(databaseConnection)
  cache <- Stream.resource(redisConnection)
} yield queryWithCache(db, cache)
```

## Cancellation and Interruption

### InterruptWhen

```scala
import fs2.concurrent.SignallingRef

for {
  stop <- Stream.eval(SignallingRef[IO, Boolean](false))
  _ <- source
    .evalMap(processItem)
    .interruptWhen(stop.discrete)  // halt when stop becomes true
} yield ()
```

### onCancel / uncancellable

```scala
// Handle cancellation
source.onCancel(IO(println("Cancelled!")))

// Prevent cancellation for critical section
source.uncancellable
```

## Common Concurrency Patterns

### Concurrent Processing with Rate Limit

```scala
def processConcurrently[A](
  source: Stream[IO, A],
  concurrency: Int,
  rateLimit: FiniteDuration
): Stream[IO, Unit] =
  source
    .parEvalMap(concurrency)(item => processItem(item))
    .metered(rateLimit)
    .compile
    .drain
```

### Fan-out to Multiple Consumers

```scala
val source = Stream.awakeEvery[IO](1.second).scan(0)(_ + 1)

source.broadcastThrough(
  consumer1,  // Pipe[IO, Int, Result]
  consumer2,
  consumer3
)
```

### Concurrent Stream Composition

```scala
val timer = Stream.awakeEvery[IO](1.second)
val data  = Stream.range(0, 10)

// Interleave both
val merged = timer.merge(data.evalMap(i => IO(println(s"Item $i"))))

// Run data alongside timer
val concurrent = timer.concurrently(data.evalTap(i => IO(println(i))))
```

## Performance Tuning

### Chunk-Aware Operations

```scala
// Prefer mapChunks over map for batch operations
source.mapChunks(c => c.map(_ * 2))

// Prefer evalMapChunk over evalMap for batch effects
source.evalMapChunk(chunk => IO(processBatch(chunk)))
```

### Buffer Sizing

```scala
// Default chunks may be small — buffer into larger chunks
Stream.range(0, 10000).buffer(1000)
Stream.range(0, 10000).chunkLimit(100)
```

### Parallelism Tuning

```scala
// Use available processors as concurrency limit
val cores = Runtime.getRuntime.availableProcessors()
Stream.range(0, 10000).parEvalMap(cores)(heavyComputation)
```

### Avoid Intermediate Collections

```scala
// Bad: materializes intermediate collections
stream.map(f).toList.map(g).filter(h)

// Good: compose operations as pipes
stream.through(mapPipe.andThen(filterPipe))
```

## Operator Summary

| Operator | Purpose | Returns |
|----------|---------|---------|
| `parEvalMap` | Bounded parallel map | `Stream[F, O2]` |
| `parEvalMapUnbounded` | Unbounded parallel map | `Stream[F, O2]` |
| `parJoin` | Join parallel streams | `Stream[F, O]` |
| `parJoinUnbounded` | Unbounded parallel join | `Stream[F, O]` |
| `concurrently` | Run background stream | `Stream[F, O]` |
| `broadcastThrough` | Fan-out to pipes | `Stream[F, O]` |
| `merge` | Nondeterministic interleave | `Stream[F, O]` |
| `mergeHaltBoth` | Merge, halt on either end | `Stream[F, O]` |
| `mergeHaltL` | Merge, halt on left end | `Stream[F, O]` |
| `buffer` | Buffer ahead | `Stream[F, O]` |
| `bufferAll` | Buffer all elements | `Stream[F, O]` |
| `prefetch` | Eager prefetch ahead | `Stream[F, O]` |
| `throttle` | Max rate per period | `Stream[F, O]` |
| `metered` | Fixed rate | `Stream[F, O]` |
| `spaced` | Fixed delay | `Stream[F, O]` |
| `debounce` | Emit after quiet period | `Stream[F, O]` |
| `conflate` | Combine when slow | `Stream[F, O]` |
| `awakeEvery` | Periodic emission | `Stream[F, FiniteDuration]` |
| `fixedRate` | Compensated rate | `Stream[F, FiniteDuration]` |
| `fixedDelay` | Fixed delay | `Stream[F, FiniteDuration]` |
| `timeout` | Timeout stream | `Stream[F, O]` |
| `timeoutTo` | Timeout with fallback | `Stream[F, O]` |
| `interruptWhen` | Halt on signal | `Stream[F, O]` |
| `onCancel` | Cancel handler | `Stream[F, O]` |
| `uncancellable` | Prevent cancellation | `Stream[F, O]` |
