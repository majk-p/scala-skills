---
name: scala-testing-weaver
description: Use this skill when writing tests with Weaver in Scala. Covers IOSuite, SimpleIOSuite, FunSuite, expect/expect.eql assertions, shared resources with cats-effect Resource, global resources, parallel test execution, ScalaCheck integration, Discipline law checking, logging, fail-fast expectations, and test tagging. Weaver is a Typelevel test framework that is effect-native (IO-first), runs tests in parallel by default, and uses composable pure Expectations instead of throw-based assertions. Trigger when the user mentions Weaver, weaver-test, IOSuite, SimpleIOSuite, effect testing, cats-effect testing, Typelevel testing, or needs to write tests in a pure functional style.
---

# Effect-Native Testing with Weaver

Weaver is a Typelevel test framework built on cats-effect. Tests run in parallel
by default, expectations are **pure composable values** (not throw-based
assertions), and resource lifecycle uses `cats.effect.Resource` natively.

## Quick Start

### SimpleIOSuite — IO tests, no shared resource

```scala
import weaver.SimpleIOSuite
import cats.effect.IO

object MySuite extends SimpleIOSuite {
  test("addition works") {
    IO.pure(expect(1 + 1 == 2))
  }

  test("list head") {
    IO.delay {
      expect(List(1, 2, 3).head == 1)
    }
  }
}
```

### IOSuite — IO tests with shared Resource

```scala
import weaver.IOSuite
import cats.effect.{IO, Resource}
import java.sql.Connection

object DatabaseSuite extends IOSuite {
  override type Res = Connection

  override def sharedResource: Resource[IO, Connection] =
    Resource.make(IO.blocking(createConnection()))(conn => IO.blocking(conn.close()))

  test("query returns rows") { conn =>
    IO.blocking {
      val rs = conn.createStatement().executeQuery("SELECT 1")
      rs.next()
      expect(rs.getInt(1) == 1)
    }
  }
}
```

### FunSuite — pure synchronous tests

```scala
import weaver.FunSuite

object PureSuite extends FunSuite {
  test("string ops") {
    expect("hello".toUpperCase == "HELLO") and
      expect("hello".length == 5)
  }
}
```

## Suite Types

| Suite            | Effect  | Shared Resource | Parallelism    |
|------------------|---------|-----------------|----------------|
| `SimpleIOSuite`  | `IO`    | No              | Parallel       |
| `IOSuite`        | `IO`    | Yes             | Parallel       |
| `FunSuite`       | None    | No              | Sequential     |

**When to use which:**
- `SimpleIOSuite` — most common starting point; IO-based tests without shared setup
- `IOSuite` — tests that need a shared resource (database, HTTP client, temp dir)
- `FunSuite` — pure synchronous tests; also used for Discipline law checking

## Expectations API

Weaver expectations are values of type `Expectations`. They compose with
`and`, `or`, `xor`, and `expect.all(...)`.

### Core assertions

```scala
// Boolean assertion
expect(condition)

// Structural equality with diff on failure
expect.eql(expected, actual)

// Reference equality
expect.same(expected, actual)
```

### Composition

```scala
// All must pass
expect.all(
  expect(a == 1),
  expect(b == 2),
  expect(c == 3)
)

// Logical combinators
val combined = expect(x > 0) and expect(x < 100)
val either   = expect(a == 1) or expect(a == 2)
val xor      = expect(flag1) xor expect(flag2)
```

### Collections

```scala
// Every element must satisfy
forEach(List(1, 2, 3)) { n => expect(n > 0) }

// At least one element must satisfy
exists(List(1, 2, 3)) { n => expect(n == 2) }
```

### Pattern matching

```scala
// Match a pattern
import weaver.scalacheck.*
matches(result) { case Right(value) => expect(value > 0) }

// Unwrap Success case
whenSuccess(computationResult) { value => expect(value.nonEmpty) }
```

### Fail-fast

```scala
// Short-circuit on first failure — later expectations not evaluated
expect(condition1).failFast and
  expect(condition2).failFast and
  expect(condition3).failFast
```

### Clue — diagnostic context

```scala
val user = fetchUser(id)
expect(user.age > 0).clue(s"User age was ${user.age} for id=$id")
```

### Constants

```scala
success  // Always passes
failure  // Always fails
```

See [references/expectations.md](references/expectations.md) for the full API.

## Shared Resources

### Per-suite resource (IOSuite)

```scala
object MySuite extends IOSuite {
  type Res = HttpClient

  def sharedResource: Resource[IO, HttpClient] =
    Resource.make(IO(HttpClient.create()))(c => IO(c.shutdown()))

  test("GET /health") { client =>
    IO.fromFuture(IO(client.get("/health"))).map { resp =>
      expect(resp.status == 200)
    }
  }
}
```

### GlobalResource — cross-suite sharing (JVM only)

```scala
import weaver.GlobalResource

object SharedServer extends GlobalResource {
  override def sharedResource(global: GlobalResource.Read): Resource[IO, Server] =
    Resource.make(IO(startServer()))(s => IO(s.stop()))
}
```

Access from an `IOSuite`:

```scala
object ApiSuite extends IOSuite {
  type Res = Server

  override def sharedResource(global: GlobalResource.Read): Resource[IO, Server] =
    global.getOrFail[Server]()

  test("server responds") { server =>
    IO.blocking(server.isRunning).map(expect(_))
  }
}
```

See [references/suites-and-resources.md](references/suites-and-resources.md) for
lifecycle details and resource composition patterns.

## Parallelism Control

Tests run in parallel by default within a suite. To run sequentially:

```scala
object SequentialSuite extends SimpleIOSuite {
  override def maxParallelism: Int = 1

  test("step 1") { IO.pure(expect(true)) }
  test("step 2") { IO.pure(expect(true)) }
}
```

Override `maxParallelism` to any positive integer to cap concurrency.

## Logging

Weaver uses lazy logging — log output is only shown when a test fails.

```scala
import weaver.SimpleIOSuite
import cats.effect.IO

object LoggedSuite extends SimpleIOSuite {
  loggedTest("with logging") { log =>
    for {
      _    <- log.info("Starting test")
      result <- IO(42)
      _    <- log.debug(s"Got result: $result")
    } yield expect(result == 42)
  }
}
```

Available methods: `log.info`, `log.warn`, `log.error`, `log.debug`.

## ScalaCheck Integration

Add `weaver-scalacheck` to dependencies, then mix in `Checkers`:

```scala
import weaver.SimpleIOSuite
import weaver.scalacheck.Checkers
import org.scalacheck.Gen

object PropertySuite extends SimpleIOSuite with Checkers {
  test("positive numbers are positive") {
    forall(Gen.posNum[Int]) { a =>
      expect(a > 0)
    }
  }

  test("addition commutes (arbitrary)") {
    forall { (a: Int, b: Int) =>
      expect.eql(a + b, b + a)
    }
  }
}
```

## Discipline Law Checking

Add `weaver-discipline` to dependencies. Use `FunSuite` as the base:

```scala
import weaver.FunSuite
import weaver.discipline.Discipline
import cats.kernel.laws.discipline.EqTests
import cats.instances.int._

object EqLawSuite extends FunSuite with Discipline {
  checkAll("Int", EqTests[Int].eqv)
}
```

## Test Tags and Filtering

```scala
object TaggedSuite extends SimpleIOSuite {
  test("critical path").only {
    IO.pure(expect(true))
  }

  test("known bug").ignore {
    IO.pure(expect(false))
  }

  // Conditional ignore
  test("CI only").only {
    if (sys.env.get("CI").isEmpty) success
    else IO.pure(expect(false))
  }
}
```

- `.only` — run only this test (others skipped)
- `.ignore` — skip this test entirely

## Custom Test Functions

### timedTest pattern

```scala
import weaver.SimpleIOSuite
import cats.effect.IO
import scala.concurrent.duration._

object TimedSuite extends SimpleIOSuite {
  def timedTest(name: String, limit: FiniteDuration)(run: => IO[Expectations]): IO[Expectations] = {
    registerTest(name) {
      run.timeoutTo(
        limit,
        IO.pure(failure.clue(s"Test timed out after $limit"))
      )
    }
  }

  timedTest("fast enough", 1.second) {
    IO.sleep(500.millis).map(_ => expect(true))
  }
}
```

### registerTest — custom registration

```scala
// registerTest lets you build custom test entry points
registerTest("dynamic test") {
  IO.pure(expect(true))
}
```

## Error Reporting

Source locations are captured automatically via `SourceLocation` implicits.
Failure messages include:

- File name and line number
- The expectation that failed
- Any attached `clue` strings
- Diff output for `expect.eql` mismatches

```scala
// Example failure output:
// [error] MySuite.scala:12: assertion failed
// [error]   expected: 3
// [error]   received: 2
// [error]   clue: user count for page=1
```

## Dependencies

### build.sbt (SBT)

```scala
libraryDependencies ++= Seq(
  "com.disneystreaming" %% "weaver-core"   % "0.9.0"  % Test,
  "com.disneystreaming" %% "weaver-cats"   % "0.9.0"  % Test,
  // For ScalaCheck integration:
  "com.disneystreaming" %% "weaver-scalacheck" % "0.9.0" % Test,
  // For Discipline law checking:
  "com.disneystreaming" %% "weaver-discipline" % "0.9.0" % Test,
)

testFrameworks += new TestFramework("weaver.framework.CatsEffect")
```

### scala-cli

```scala
//> using testFramework "weaver.framework.CatsEffect"
//> using dep "com.disneystreaming::weaver-cats::0.9.0"
```

> Check Maven Central for the latest version — the version shown above is
> illustrative.

## Related Skills

- **scala-testing** — general Scala testing patterns and frameworks
- **scala-testing-property** — property-based testing with ScalaCheck
- **cats-effect** — understanding IO and Resource fundamentals
- **type-classes** — type class laws and Discipline integration

## References

- [references/expectations.md](references/expectations.md) — Full expectations
  API with all combinators, clue system, fail-fast, pattern matching, and
  composition operators
- [references/suites-and-resources.md](references/suites-and-resources.md) —
  Complete suite types, shared resources, global resources, parallelism,
  lifecycle, custom suite base classes, standalone runner
