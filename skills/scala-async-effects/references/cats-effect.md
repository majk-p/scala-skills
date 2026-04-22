# Cats Effect Reference

Complete API reference for cats-effect. Load this when you need specific IO API signatures, Resource patterns, concurrency primitives, or testing strategies.

## Table of Contents
- [IO Type](#io-type)
- [Creating IO Effects](#creating-io-effects)
- [Error Management](#error-management)
- [Concurrency Primitives](#concurrency-primitives)
- [Resource](#resource)
- [Fibers](#fibers)
- [Cancellation](#cancellation)
- [Temporal Operations](#temporal-operations)
- [Testing](#testing)

---

## IO Type

`IO[A]` is actually `IO[Throwable, A]` — it always fails with `Throwable`. For typed errors, use `IO[Either[E, A]]` or `EitherT[IO, E, A]`.

```scala
IO.pure(42)           // pure value (eager, use for known values)
IO.delay(42)          // lazy evaluation (use for side effects)
IO.unit               // IO[Unit]
IO.raiseError(new Exception("boom"))  // fail
```

## Creating IO Effects

```scala
// Pure values
IO.pure(42)
IO.unit

// Wrapping side effects (preferred over pure for computed values)
IO.delay { println("side effect"); 42 }
IO(println("eager"))                  // alias for IO.delay

// Async
IO.async { (cb: Either[Throwable, Int] => Unit) => cb(Right(42)) }
IO.async_ { cb => cb(Right(42)) }    // simpler variant

// Blocking (shifts to blocking thread pool)
IO.blocking { Thread.sleep(1000); 42 }
IO.interruptible { longRunning() }   // cancellable blocking

// From stdlib
IO.fromTry(scala.util.Success(42))
IO.fromEither(Right(42))
IO.fromCompletableFuture(future)
IO.never                              // never completes
IO.canceled                           // self-cancel
```

## Error Management

```scala
effect.handleErrorWith(_ => IO.pure(-1))     // recover from any error
effect.redeem(err => IO.pure(-1), identity)   // handle both paths
effect.recover { case _: IOException => -1 }  // catch specific
effect.mapError(_.getMessage)                  // transform error
effect.attempt                                // IO[Either[Throwable, A]]
effect.fold(err => s"fail", ok => s"ok")     // fold both paths
effect.onError(err => IO.println(err))        // inspect without handling

// Retry (requires retry library or cats-effect-testing)
effect.retry(RetryPolicies.limitRetries(3))
effect.retry(RetryPolicies.exponentialBackoff(1.second))
```

## Concurrency Primitives

### Ref — Atomic Reference

```scala
for {
  ref <- Ref[IO].of(0)
  _   <- ref.update(_ + 1)
  v   <- ref.get                    // IO[Int]
  _   <- ref.set(42)
  res <- ref.modify(n => (n * 2, n + 1))  // returns transformed value, updates ref
} yield res
```

### Deferred — One-Time Coordination

```scala
for {
  d <- Deferred[IO, Int]
  _ <- d.complete(42).start         // complete in background
  v <- d.get                        // blocks until completed
} yield v
```

### Semaphore — Concurrency Limiter

```scala
for {
  sem <- Semaphore[IO](5)
  _   <- sem.permit.use(_ => doWork)   // acquire 1 permit, release after
  _   <- (sem.permit.use(_ => work1), sem.permit.use(_ => work2)).parTupled
} yield ()
```

### Queue — Asynchronous Messaging

```scala
for {
  q <- Queue.bounded[IO, Int](100)
  _ <- q.offer(42)                  // enqueue
  v <- q.take                       // dequeue (async if empty)
  _ <- q.tryTake                    // IO[Option[Int]] — non-blocking
} yield ()

Queue.unbounded[IO, Int]            // no capacity limit
Queue.synchronous[IO, Int]          // handoff queue (producer waits for consumer)
```

### Mutex — Mutual Exclusion

```scala
for {
  m <- Mutex[IO]
  v <- m.lock.surround(criticalSection)  // only one fiber at a time
} yield v
```

## Resource

```scala
// From AutoCloseable
def fileResource(path: String): Resource[IO, BufferedReader] =
  Resource.fromAutoCloseable(IO.blocking(new BufferedReader(new FileReader(path))))

// From acquire/release
val res: Resource[IO, Connection] = Resource.make(
  IO.blocking(openConnection())
)(conn => IO.blocking(conn.close()))

// Use
val result: IO[String] = res.use(conn => IO.blocking(query(conn)))

// Compose
val combined: Resource[IO, (Reader, Writer)] = (
  fileResource("in.txt"), fileResource("out.txt")
).tupled

// Resource + eval
val withSetup: Resource[IO, Config] =
  Resource.eval(IO.blocking(loadConfig()))
```

## Fibers

```scala
// Start
val fiber: IO[Fiber[IO, Throwable, Int]] = IO.pure(42).start

// Await
fiber.flatMap(_.join)                  // IO[Outcome[IO, Throwable, Int]]

// Cancel
fiber.flatMap(_.cancel)                // IO[Unit]

// Race — first to complete
IO.pure(1).race(IO.pure(2))           // IO[Int]

// Race both — first wins, cancel the other
IO.pure(1).raceBoth(IO.pure(2))       // IO[Either[Int, Int]]

// Parallel tuple
(IO.pure(1), IO.pure("a")).parTupled  // IO[(Int, String)]

// Parallel traverse
List(1, 2, 3).parTraverse(n => IO.pure(n * 2))  // IO[List[Int]]
```

## Cancellation

```scala
// Uncancellable region
val critical: IO[Int] = IO.uncancelable { poll =>
  acquire.flatMap { r =>
    poll(use(r))  // only poll-wrapped section can be cancelled
  }
}

// Self-cancel
IO.canceled                            // cancel current fiber

// On cancel callback
resource.onCancel(IO.println("cancelled"))

// Guarantee — run cleanup regardless
effect.guarantee(cleanup)              // like try/finally
effect.guaranteeCase {
  case Succeeded(_) => cleanupSuccess
  case Errored(e)   => cleanupError(e)
  case Canceled     => cleanupCancel
}
```

## Temporal Operations

```scala
IO.sleep(1.second)                     // non-blocking sleep
effect.timeout(1.second)               // IO[Option[A]] — None if timeout
effect.timeoutTo(1.second)(fallback)   // switch to fallback on timeout
IO.monotonic                           // IO[FiniteDuration] — current time
IO.realTime                            // IO[FiniteDuration] — wall clock
effect.timed                           // IO[(FiniteDuration, A)] — measure duration
```

## Testing

```scala
// Simple test
test("addition") {
  IO.pure(1 + 1).map(v => assert(v == 2))
}

// Test error paths
test("fails correctly") {
  IO.raiseError(new Exception("boom")).attempt.map {
    case Left(e) => assert(e.getMessage == "boom")
    case Right(_) => fail("should have failed")
  }
}

// Test async behavior
test("deferred completes") {
  for {
    d <- Deferred[IO, Int]
    _ <- d.complete(42).start
    v <- d.get
  } yield assert(v == 42)
}

// Deterministic time testing with TestControl (cats-effect-testkit)
import cats.effect.kernel.testkit.TestControl

TestControl.execute(IO.sleep(1.second).as(42)).flatMap { control =>
  for {
    _ <- control.advance(1.second)
    r <- control.results
  } yield assert(r == Outcome.succeeded(IO.pure(42)))
}
```
