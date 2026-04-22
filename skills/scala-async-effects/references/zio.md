# ZIO Reference

Complete API reference for ZIO effect system. Load this when you need specific ZIO API signatures, concurrency primitives, or testing patterns.

## Table of Contents
- [Type Parameters](#type-parameters)
- [Creating Effects](#creating-effects)
- [Error Management](#error-management)
- [Concurrency Primitives](#concurrency-primitives)
- [Resource Management](#resource-management)
- [Fibers](#fibers)
- [Schedules](#schedules)
- [Services and Layers](#services-and-layers)
- [Testing](#testing)

---

## Type Parameters

`ZIO[R, E, A]` — an effect that requires environment `R`, can fail with `E`, and produces `A`.

```scala
type Task[A]  = ZIO[Any, Throwable, A]  // no environment, Throwable errors
type UIO[A]   = ZIO[Any, Nothing, A]    // no environment, cannot fail
type URIO[R, A] = ZIO[R, Nothing, A]    // requires R, cannot fail
type IO[E, A] = ZIO[Any, E, A]         // no environment, typed errors
type RIO[R, A] = ZIO[R, Throwable, A]  // requires R, Throwable errors
```

## Creating Effects

```scala
// Success
ZIO.succeed(42)                 // pure value
ZIO.unit                        // ZIO.succeed(())

// Failure
ZIO.fail("error")               // typed error
ZIO.die(new Exception("boom"))  // terminal (unrecoverable) defect

// Side effects
ZIO.attempt { risky() }         // Task[A] — catches Throwable
ZIO.attemptBlocking { io() }    // shifts to blocking thread pool
ZIO.succeed { println("ok") }   // eager evaluation (use carefully)

// Async
ZIO.async { cb => cb(ZIO.succeed(42)) }
ZIO.asyncInterrupt { cb => ... }

// From stdlib
ZIO.fromTry(scala.util.Try(42))
ZIO.fromEither(Right(42))
ZIO.fromOption(Some(42))
```

## Error Management

```scala
effect.orElse(fallback)                           // try fallback on error
effect.catchSome { case _: IOException => backup } // catch specific errors
effect.catchAll(err => ZIO.succeed(default))       // catch all
effect.mapError(_.getMessage)                      // transform error type
effect.fold(err => s"fail: $err", ok => s"ok: $ok") // handle both
effect.tapError(err => ZIO.logError(s"$err"))      // inspect error without handling
effect.getOrElse(0)                                // default on failure
effect.option                                      // ZIO[R, Nothing, Option[A]]
effect.either                                      // ZIO[R, Nothing, Either[E, A]]]
effect.unrefine { case _: IOException => "io" }    // convert defects to typed errors
effect.refineToOrDie[IOException]                  // narrow error type
effect.retry(Schedule.recurs(3))                   // retry up to 3 times
```

## Concurrency Primitives

### Ref — Thread-Safe Mutable Reference

```scala
for {
  ref <- Ref.make(0)
  _   <- ref.update(_ + 1)          // transform in place
  v   <- ref.get                    // IO[Int]
  _   <- ref.set(42)                // overwrite
  old <- ref.getAndUpdate(_ + 1)    // return old value
  new <- ref.updateAndGet(_ + 1)    // return new value
  res <- ref.modify(n => (n * 2, n + 1))  // transform and return result
} yield res
```

### Promise — One-Time Coordination

```scala
for {
  p  <- Promise.make[Nothing, Int]
  _  <- p.await.fork                // fiber waiting on completion
  _  <- p.succeed(42)              // complete the promise
} yield ()
```

### Semaphore — Concurrency Limiter

```scala
for {
  sem <- Semaphore.make(5)          // 5 permits
  _   <- sem.withPermit(doWork)     // acquire 1, release after
  _   <- sem.withPermits(3)(doWork) // acquire 3
} yield ()
```

### Queue — Asynchronous Messaging

```scala
for {
  q <- Queue.bounded[Int](100)      // bounded queue
  _ <- q.offer(42)                  // enqueue (async if full)
  v <- q.take                       // dequeue (async if empty)
} yield ()

Queue.unbounded[Int]               // no capacity limit
Queue.sliding[Int](100)            // drops oldest when full
Queue.dropping[Int](100)           // drops new when full
```

### Hub — Broadcast to Multiple Subscribers

```scala
for {
  h  <- Hub.bounded[Int](100)
  _  <- h.publish(42)
  sub <- h.subscribe
  v  <- sub.take                    // each subscriber gets all messages
} yield ()
```

## Resource Management

```scala
// Acquire/Release pattern
ZIO.acquireReleaseWith(
  ZIO.attempt(openResource())
)(r => ZIO.succeed(r.close()))(r => ZIO.succeed(use(r)))

// Scope-based (preferred)
ZIO.scoped {
  for {
    r1 <- ZIO.fromAutoCloseable(ZIO.attempt(createResource()))
    r2 <- ZIO.fromAutoCloseable(ZIO.attempt(createResource()))
  } yield useBoth(r1, r2)
}
// Both resources cleaned up when scope closes, regardless of success/failure
```

## Fibers

```scala
val fiber = ZIO.succeed(42).fork          // lightweight thread
fiber.join                                 // await result
fiber.interrupt                            // cancel
fiber.forkDaemon                           // outlives parent scope

ZIO.succeed(1).race(ZIO.succeed(2))        // first to complete wins
ZIO.succeed(1).raceBoth(ZIO.succeed(2))    // both run, first result wins
ZIO.collectAllPar(List(task1, task2))       // run all in parallel
ZIO.foreachPar(items)(process)              // parallel map
ZIO.foreachPar_(items)(process)             // parallel foreach (discard results)
```

## Schedules

```scala
// Repeat
effect.repeat(Schedule.spaced(1.second))          // every 1 second
effect.repeat(Schedule.recurs(10))                 // exactly 10 times
effect.repeat(Schedule.fixed(1.second))            // fixed interval

// Retry
effect.retry(Schedule.recurs(3))                   // up to 3 retries
effect.retry(Schedule.exponential(1.second))       // exponential backoff
effect.retry(Schedule.exponential(1.second) && Schedule.recurs(5)) // combined

// Compose schedules with && (both) or || (either)
```

## Services and Layers

ZIO's dependency injection via the environment type `R` and `ZLayer`.

```scala
// Define a service
trait Logging {
  def log(message: String): UIO[Unit]
}

// Create a layer (provides the service)
val loggingLayer: ULayer[Logging] =
  ZLayer.succeed(new Logging {
    def log(message: String): UIO[Unit] = ZIO.succeed(println(message))
  })

// Use the service
val program: ZIO[Logging, Nothing, Unit] =
  ZIO.serviceWithZIO[Logging](_.log("Hello"))

// Compose layers
val appLayer = loggingLayer ++ configLayer  // ++ = horizontal composition
val fullLayer = repoLayer >>> serviceLayer   // >>> = vertical (feed output to input)

// Provide to program
program.provideLayer(appLayer)
```

## Testing

```scala
import zio.test._
import zio.test.Assertion._

object MySpec extends ZIOSpecDefault {
  def spec = suite("My feature")(
    test("pure assertion") {
      assert(1 + 1)(equalTo(2))
    },
    test("effect assertion") {
      for {
        result <- ZIO.succeed(42)
      } yield assert(result)(equalTo(42))
    },
    test("error assertion") {
      for {
        result <- ZIO.fail("boom").either
      } yield assert(result)(isLeft(equalTo("boom")))
    },
    test("property-based") {
      check(Gen.int) { n =>
        assert(n.abs)(isGreaterThanEqualTo(0))
      }
    }
  ) @@ TestAspect.timeout(10.seconds)
}

// Shared fixtures via layers
val refLayer: ULayer[Ref[Int]] = ZLayer.scoped(Ref.make(0))
```
