# Advanced Patterns Reference

State encapsulation, supervisor patterns, retry policies, MTL, middleware, effect conversion, and ecosystem integration. Load this when working on production-grade concurrent systems, complex resource lifecycles, or cross-library interop.

## Table of Contents
- [State Encapsulation](#state-encapsulation)
- [Supervisor Pattern](#supervisor-pattern)
- [Retry Policy Composition](#retry-policy-composition)
- [MTL Patterns](#mtl-patterns)
- [Middleware Composition](#middleware-composition)
- [Effect Conversion](#effect-conversion)
- [Ecosystem Integration](#ecosystem-integration)

---

## State Encapsulation

### Counter Pattern — Smart Constructor

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

### Capability Traits

```scala
trait Background[F[_]] {
  def schedule[A](fa: F[A], duration: FiniteDuration): F[Unit]
}

implicit def forSupervisorTemporal[F[_]](
  implicit S: Supervisor[F], T: Temporal[F]
): Background[F] = new Background[F] {
  def schedule[A](fa: F[A], duration: FiniteDuration): F[Unit] =
    S.supervise(T.sleep(duration) *> fa).void
}
```

### Regions of Sharing

Scope shared resources (semaphores, refs) to a flatMap block so they're automatically released.

```scala
def sharedStateExample: IO[Unit] =
  Supervisor[IO].use { s =>
    Semaphore[IO](1).flatMap { sem =>
      // sem is scoped to this block — both fibers see it
      s.supervise(process1(sem)).foreverM.void *>
      s.supervise(process2(sem)).foreverM.void *>
      IO.sleep(5.seconds).void
    }
  }
```

### Anti-Pattern: Leaky State

```scala
// WRONG — global mutable state
lazy val globalRef: Ref[IO, Int] = Ref[IO].of(0).unsafeRunSync() // DANGEROUS!

// RIGHT — scoped resources
def safeExample: IO[Unit] =
  Ref[IO].of(0).flatMap { ref =>
    // ref is local to this scope
    ref.update(_ + 1) *> ref.get.flatMap(IO.println)
  }
```

---

## Supervisor Pattern

Supervisors manage fiber lifecycles — all supervised fibers are cancelled when the supervisor scope closes. Use instead of raw `forkDaemon`.

### Cats Effect

```scala
val app: IO[Unit] =
  Supervisor[IO].use { supervisor =>
    for {
      _ <- supervisor.supervise(IO.println("heartbeat").foreverM)
      _ <- supervisor.supervise(IO.println("metrics").foreverM)
      _ <- IO.sleep(30.seconds)  // main logic
    } yield ()  // heartbeat and metrics fibers cancel here
  }
```

### ZIO

```scala
val app: ZIO[Any, Nothing, Unit] =
  Supervisor[IO].use { supervisor =>
    for {
      _ <- supervisor.supervise(backgroundTask1)
      _ <- supervisor.supervise(backgroundTask2)
      _ <- mainLogic
    } yield ()
  }
```

---

## Retry Policy Composition

### Building Blocks

```scala
import retry.RetryPolicies._

def limitRetries[F[_]](max: Int): RetryPolicy[F] = RetryPolicies.limitRetries[F](max)
def exponentialBackoff[F[_]](base: FiniteDuration): RetryPolicy[F] = RetryPolicies.exponentialBackoff[F](base)
def constantDelay[F[_]](delay: FiniteDuration): RetryPolicy[F] = RetryPolicies.constantDelay[F](delay)
def fibonacciBackoff[F[_]](base: FiniteDuration): RetryPolicy[F] = RetryPolicies.fibonacciBackoff[F](base)
```

### Composing Policies

```scala
// Combine using Semigroup — both must agree to retry
import cats.Semigroup

implicit val retryPolicySemigroup: Semigroup[RetryPolicy[F]] = (p1, p2) => p1 |+| p2

// Limit retries AND use exponential backoff
val policy = limitRetries[F](5) |+| exponentialBackoff[F](100.millis)
```

### Retry with Logging

```scala
def resilientOperation[F[_]: Temporal: Functor](implicit logger: Logger[F]): F[Int] =
  retryingOnAllErrors[Int](
    policy = limitRetries[F](5) |+| exponentialBackoff[F](100.millis),
    onError = (err: Throwable, details: RetryDetails) => details match {
      case WillDelayAndRetry(_, retriesSoFar, _) =>
        logger.error(s"Retrying (attempt $retriesSoFar): ${err.getMessage}")
      case GivingUp(totalRetries, _) =>
        logger.error(s"Giving up after $totalRetries retries: ${err.getMessage}")
    }
  )(fetchRemoteData[F]())
```

---

## MTL Patterns

### Ask — Read from Environment

```scala
import cats.mtl.Ask

trait Config { def timeout: Int; def apiKey: String }

def readTimeout[F[_]](implicit ask: Ask[F, Config]): F[Int] =
  ask.reader(_.timeout)
```

### Raise — Typed Errors

```scala
import cats.mtl.Raise

def validate[F[_]](input: String)(implicit raise: Raise[F, String]): F[Int] =
  if (input.isEmpty) raise.raise("empty input")
  else input.toInt.pure[F]
```

### Stateful — State Management

```scala
import cats.mtl.Stateful

def increment[F[_]](implicit state: Stateful[F, Int]): F[Unit] =
  state.modify(n => (n + 1, ()))
```

### Local — Scoped Environment

```scala
import cats.mtl.Local

def withOverride[F[_]](implicit local: Local[F, Config]): F[Unit] =
  local.scope(Config(timeout = 999, apiKey = "test")) {
    // runs with overridden config
    readTimeout[F]
  }
```

---

## Middleware Composition

Stack effect wrappers to add cross-cutting concerns:

```scala
// ZIO middleware
def logging[R, E, A](zio: ZIO[R, E, A]): ZIO[R, E, A] =
  zio.timed.flatMap { case (d, result) =>
    ZIO.logDebug(s"took $d").as(result)
  }

def retrying[R, E >: Throwable, A](max: Int, zio: ZIO[R, E, A]): ZIO[R, E, A] =
  zio.retry(Schedule.recurs(max).addDelay(Schedule.exponential(1.second)))

def timing[R, E, A](timeout: Duration, zio: ZIO[R, E, A]): ZIO[R, E, A] =
  zio.timeoutFail(timeout)(new TimeoutException("timed out"))

// Compose: logging + retry + timeout
val service: ZIO[Any, Throwable, Int] =
  timing(5.seconds, retrying(3, logging(fetchData)))
```

---

## Effect Conversion

### Cats Effect IO → ZIO

```scala
def ioToZio[A](io: IO[Throwable, A]): Task[A] =
  ZIO.asyncInterrupt { cb =>
    val cancel = io.unsafeRunAsyncCancelable {
      case Left(e)  => cb(ZIO.fail(e))
      case Right(a) => cb(ZIO.succeed(a))
    }
    Left(ZIO.succeed(cancel()))
  }
```

### ZIO → Cats Effect IO

```scala
def zioToIo[A](zio: Task[A]): IO[A] =
  IO.async { cb =>
    zio.unsafeRun {
      case Exit.Success(a)     => cb(Right(a))
      case Exit.Failure(cause) => cb(Left(cause.squash))
    }
  }
```

---

## Ecosystem Integration

### Logging — log4cats

```scala
import org.typelevel.log4cats._
import org.typelevel.log4cats.slf4j.Slf4jFactory

def program: IO[Unit] = for {
  logger <- Slf4jFactory[IO].getLogger
  _      <- logger.info("Starting up")
  result <- IO.pure(42)
  _      <- logger.info(s"Result: $result")
} yield ()
```

### Tracing — natchez

```scala
import natchez._

def traced: IO[Int] =
  Trace[IO].span("operation") {
    for {
      _ <- Trace[IO].put("key" -> "value")
      r <- IO.pure(42)
    } yield r
  }
```

### Redis — redis4cats

```scala
import dev.profunktor.redis4cats.Redis

val redis: Resource[IO, RedisCommands[IO, String, String]] =
  Redis[IO].utf8("redis://localhost:6379")

def cacheGet(key: String): IO[Option[String]] =
  redis.use(_.get(key))

def cacheSet(key: String, value: String): IO[Unit] =
  redis.use(_.set(key, value))
```
