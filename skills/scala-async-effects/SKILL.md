---
name: scala-async-effects
description: Use this skill when working with asynchronous effects, concurrency, or resource management in Scala using ZIO or cats-effect. Covers IO monad, Resource management, fiber-based concurrency, supervisors, error handling, effect composition, and side-effect management. Trigger when the user mentions IO, ZIO, Task, Resource, cats-effect, fibers, concurrent operations, async, or needs to handle side effects in a Scala codebase — even if they don't explicitly name the library.
---

# Asynchronous Effects & Concurrency in Scala

Scala has two dominant effect systems: **ZIO** and **cats-effect**. Both provide type-safe, composable ways to handle side effects, concurrency, and resource management. They share the same core ideas — wrapping side effects in values, compositional error handling, fiber-based concurrency — but differ in API and philosophy.

This skill covers both. When the user's codebase uses one or the other, focus on that library. When the choice is open, recommend based on ecosystem alignment: ZIO for self-contained applications, cats-effect for Typelevel ecosystem integration.

## Quick Start

### ZIO

```scala
import zio._

object MyApp extends ZIOAppDefault {
  def run: ZIO[Any, Nothing, Unit] =
    for {
      _ <- Console.printLine("Hello from ZIO!")
      name <- Console.readLine
      _ <- Console.printLine(s"Hello, $name!")
    } yield ()
}
```

### Cats Effect

```scala
import cats.effect._

object Main extends IOApp.Simple {
  val run: IO[Unit] = IO.println("Hello from Cats Effect!")
}
```

## Core Concepts

### Creating Effects

Wrapping side effects in effect types is the foundation. Never call `unsafeRun` or `unsafeRunSync` outside of `main` — the runtime does that for you.

```scala
// ZIO
val pure: ZIO[Any, Nothing, Int] = ZIO.succeed(42)
val sideEffect: ZIO[Any, Throwable, Int] = ZIO.attempt(println("side effect"); 42)
val blocking: ZIO[Any, Throwable, String] = ZIO.attemptBlocking(scala.io.Source.fromFile("f.txt").mkString)

// Cats Effect
val pure: IO[Int] = IO.pure(42)
val sideEffect: IO[Int] = IO.delay(println("side effect"); 42)
val blocking: IO[String] = IO.blocking(scala.io.Source.fromFile("f.txt").mkString)
```

Common type aliases in ZIO: `Task[A] = ZIO[Any, Throwable, A]`, `UIO[A] = ZIO[Any, Nothing, A]`, `IO[E, A] = ZIO[Any, E, A]`.

### Error Handling

Both libraries model errors in the type system. ZIO has a dedicated error type parameter `E`; cats-effect fixes `E = Throwable` but lets you layer typed errors via `EitherT` or `IO[Either[E, A]]`.

```scala
// ZIO — typed errors
val handled: ZIO[Any, Nothing, Int] = ZIO.fail("error").orElse(ZIO.succeed(0))
val folded: ZIO[Any, Nothing, String] = effect.fold(err => s"Fail: $err", ok => s"OK: $ok")
val retried: ZIO[Any, String, Int] = effect.retry(Schedule.recurs(3).addDelay(Schedule.exponential(1.second)))

// Cats Effect — Throwable-based
val handled: IO[Int] = IO.raiseError(new Exception("boom")).handleErrorWith(_ => IO.pure(-1))
val attempted: IO[Either[Throwable, Int]] = effect.attempt
val retried: IO[Int] = effect.retry(RetryPolicies.limitRetries(3))
```

### Resource Management

Resources must be cleaned up regardless of success or failure. Both libraries provide bracket-style patterns. Prefer these over try/finally.

```scala
// ZIO — Scope-based
val result: ZIO[Any, Throwable, String] = ZIO.scoped {
  for {
    reader <- ZIO.fromAutoCloseable(ZIO.attempt(new BufferedReader(new FileReader("in.txt"))))
    writer <- ZIO.fromAutoCloseable(ZIO.attempt(new BufferedWriter(new FileWriter("out.txt"))))
  } yield useBoth(reader, writer)
}

// Cats Effect — Resource type
def fileResource(path: String): Resource[IO, BufferedReader] =
  Resource.fromAutoCloseable(IO.blocking(new BufferedReader(new FileReader(path))))

val combined: Resource[IO, (BufferedReader, BufferedWriter)] = (
  fileResource("in.txt"), fileResource("out.txt")
).tupled

val process: IO[Unit] = combined.use { case (in, out) => IO.blocking(copy(in, out)) }
```

### Concurrency Primitives

Both libraries provide thread-safe mutable references, promises, semaphores, and queues — the building blocks for concurrent programs.

```scala
// ZIO
for {
  ref <- Ref.make(0)            // atomic reference
  _   <- ref.update(_ + 1)
  v   <- ref.get                // v == 1
  p   <- Promise.make[Nothing, Int]  // one-time coordination
  _   <- p.succeed(42).fork
  v2  <- p.await                // v2 == 42
  sem <- Semaphore.make(5)      // 5 concurrent permits
  _   <- sem.withPermit(doWork)
  q   <- Queue.bounded[Int](100)  // async queue
  _   <- q.offer(42)
  v3  <- q.take                 // v3 == 42
} yield ()

// Cats Effect — same primitives, different names
for {
  ref <- Ref[IO].of(0)
  _   <- ref.update(_ + 1)
  v   <- ref.get
  d   <- Deferred[IO, Int]      // one-time coordination
  _   <- d.complete(42).start
  v2  <- d.get
  sem <- Semaphore[IO](5)
  _   <- sem.permit.use(_ => doWork)
  q   <- Queue.bounded[IO, Int](100)
  _   <- q.offer(42)
  v3  <- q.take
} yield ()
```

## Common Patterns

### Sequential vs Parallel

For-comprehensions run sequentially. Use `zipPar` / `parTupled` for parallel execution.

```scala
// Sequential (ZIO)
for { a <- fa; b <- fb } yield (a, b)
// Parallel (ZIO)
fa.zipPar(fb)

// Sequential (CE)
for { a <- fa; b <- fb } yield (a, b)
// Parallel (CE)
(fa, fb).parTupled
```

### Timeouts, Racing, Retrying

```scala
// ZIO
val timed: ZIO[Any, Nothing, Option[Int]] = effect.timeout(1.second)
val raced: ZIO[Any, Nothing, Int] = fa.race(fb)  // first to complete wins
val retried = effect.retry(Schedule.exponential(1.second).whileOutput(_ < 1.minute))

// Cats Effect
val timed: IO[Option[Int]] = effect.timeout(1.second)
val raced: IO[Int] = fa.race(fb)
val retried = effect.retry(RetryPolicies.exponentialBackoff(1.second))
```

### Fibers

Fibers are lightweight threads managed by the runtime. Fork to start, join to await, interrupt/cancel to stop.

```scala
// ZIO
for {
  fiber <- ZIO.succeed(compute()).fork
  result <- fiber.join           // await result
  // or: fiber.interrupt         // cancel
} yield result

// Cats Effect
for {
  fiber <- IO.pure(compute()).start
  result <- fiber.join
  // or: fiber.cancel
} yield result
```

## Advanced Patterns

### Supervisor — Managed Background Fibers

Supervisors automatically cancel background fibers when the supervisor scope closes. Use this instead of fire-and-forget `forkDaemon`.

```scala
// ZIO
val app: ZIO[Any, Nothing, Unit] =
  Supervisor[IO].use { supervisor =>
    for {
      _ <- supervisor.supervise(backgroundTask1)
      _ <- supervisor.supervise(backgroundTask2)
      _ <- mainLogic  // when this completes, all supervised fibers cancel
    } yield ()
  }

// Cats Effect
val app: IO[Unit] =
  Supervisor[IO].use { supervisor =>
    for {
      _ <- supervisor.supervise(IO.println("background").foreverM)
      _ <- IO.sleep(5.seconds)
    } yield ()  // supervised fibers cancel here
  }
```

### State Encapsulation

Wrap mutable state behind trait boundaries so callers can't access the Ref directly. This enables testing with mock implementations.

```scala
trait Counter[F[_]] {
  def incr: F[Unit]
  def get: F[Int]
}

object Counter {
  def make[F[_]: Ref.Make]: F[Counter[F]] =
    Ref.of[F, Int](0).map { ref =>
      new Counter[F] {
        def incr: F[Unit] = ref.update(_ + 1)
        def get: F[Int] = ref.get
      }
    }
}
```

### Middleware — Composing Effect Wrappers

```scala
// ZIO logging middleware
def logMiddleware[R, E, A](zio: ZIO[R, E, A]): ZIO[R, E, A] =
  zio.timed.flatMap { case (duration, result) =>
    ZIO.logDebug(s"Operation took $duration").as(result)
  }

// ZIO retry middleware
def retryMiddleware[R, E >: Throwable, A](maxRetries: Int, zio: ZIO[R, E, A]): ZIO[R, E, A] =
  zio.retry(Schedule.recurs(maxRetries).addDelay(Schedule.exponential(1.second)))
```

### Uncancellable Regions (Cats Effect)

```scala
val critical: IO[Int] = IO.uncancelable { poll =>
  acquireResource.flatMap { r =>
    poll(useResource(r))  // only the poll-wrapped section is cancellable
  }
}
```

### Effect Conversion Between ZIO and Cats Effect

When interop is needed, convert between effect types. This is useful when integrating libraries from different ecosystems.

```scala
// Cats Effect IO → ZIO
def ioToZio[A](io: IO[Throwable, A]): Task[A] =
  ZIO.asyncInterrupt { cb =>
    io.unsafeRunAsync {
      case Left(e)  => cb(ZIO.fail(e))
      case Right(a) => cb(ZIO.succeed(a))
    }
  }

// ZIO → Cats Effect IO
def zioToIo[A](zio: Task[A]): IO[A] =
  IO.async { cb =>
    zio.unsafeRun {
      case Exit.Success(a)     => cb(Right(a))
      case Exit.Failure(cause) => cb(Left(cause.squash))
    }
  }
```

## Error Handling Best Practices

- Never call `unsafeRun` / `unsafeRunSync` outside of `main` — use `IOApp` or `ZIOAppDefault`
- Use `Resource` / `Scope` for anything that must be closed or cleaned up
- Never hard-block a thread outside of `blocking` / `attemptBlocking`
- Handle all error paths explicitly — don't let `Throwable` propagate silently
- Prefer `redeem` / `fold` over `handleErrorWith` when you need to handle both success and failure

## Dependencies

```scala
// ZIO — check for latest version
libraryDependencies += "dev.zio" %% "zio" % "2.1.+"
libraryDependencies += "dev.zio" %% "zio-test" % "2.1.+" % Test
libraryDependencies += "dev.zio" %% "zio-test-sbt" % "2.1.+" % Test

// Cats Effect — check for latest version
libraryDependencies += "org.typelevel" %% "cats-effect" % "3.6.+"
libraryDependencies += "org.typelevel" %% "cats-effect-std" % "3.6.+"
```

## Related Skills

- **scala-streaming** — when combining async effects with fs2 stream processing
- **scala-json-circe** — when encoding/decoding JSON inside effect types
- **scala-database** — when wrapping database operations in ZIO or cats-effect
- **scala-fp-patterns** — for tagless final, MTL patterns, and effect polymorphism

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/zio.md** — Complete ZIO API reference: type parameters, effect creation, error management, concurrency primitives, resource management, fibers, schedules, services/layers, testing
- **references/cats-effect.md** — Complete cats-effect API reference: IO creation, error management, concurrency primitives, Resource, fibers, cancellation, temporal operations, testing
- **references/advanced-patterns.md** — State encapsulation patterns, capability traits, supervisor deep dive, retry policy composition, MTL patterns, middleware composition, effect conversion, ecosystem integration (log4cats, natchez, redis4cats)
