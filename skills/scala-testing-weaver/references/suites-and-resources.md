# Weaver Suite Types, Resources, and Lifecycle

## Suite Types

### SimpleIOSuite

The most common suite. Each test runs in `IO`. No shared resource.
Tests execute in parallel by default.

```scala
import weaver.SimpleIOSuite
import cats.effect.IO

object UserValidationSuite extends SimpleIOSuite {
  test("valid email passes") {
    IO.pure {
      expect(Validator.isEmail("a@b.com"))
    }
  }

  test("empty email fails") {
    IO.pure {
      expect(!Validator.isEmail(""))
    }
  }
}
```

- Test signature: `String => IO[Expectations]`
- No shared state between tests
- Parallel by default

### IOSuite

IO-based tests with a shared `Resource`. The resource is allocated once and
shared across all tests in the suite.

```scala
import weaver.IOSuite
import cats.effect.{IO, Resource}

object RepositorySuite extends IOSuite {
  // Define the shared resource type
  override type Res = Transactor[IO]

  // Allocate and release the resource
  override def sharedResource: Resource[IO, Transactor[IO]] = {
    Resource.make {
      IO.blocking {
        Transactor.fromConnectionString("jdbc:h2:mem:test")
      }
    } { xa =>
      IO.blocking(xa.kernel.close())
    }
  }

  // Tests receive the resource as a parameter
  test("insert and retrieve") { xa =>
    for {
      _     <- insertUser(xa, User("Alice", 30))
      found <- findUser(xa, "Alice")
    } yield expect(found.isDefined) and expect(found.get.age == 30)
  }
}
```

- Test signature: `Res => IO[Expectations]`
- Resource allocated once before tests, released after all complete
- Parallel by default (within the suite)

### FunSuite

Pure synchronous tests. No effect type, no shared resource.
Tests run **sequentially** — not in parallel.

```scala
import weaver.FunSuite

object MathSuite extends FunSuite {
  test("fibonacci base cases") {
    expect(Fib(0) == 0) and expect(Fib(1) == 1)
  }

  test("fibonacci recurrence") {
    expect(Fib(10) == 55)
  }
}
```

- Test signature: `=> Expectations` (no effect wrapper)
- Sequential execution
- Use for Discipline law checking: `extends FunSuite with Discipline`

## Shared Resources

### Resource Lifecycle

For `IOSuite`, the lifecycle is:

```
1. sharedResource allocated
2. All tests run (in parallel by default)
3. sharedResource released
4. Results reported
```

The resource is **not** re-allocated between tests. Tests must not mutate shared
state in ways that affect other tests.

### Resource Composition

Compose multiple resources using `Resource.mapN` or `for`-comprehensions:

```scala
import cats.effect.{IO, Resource}
import cats.implicits._

override type Res = (HttpClient, Database)

override def sharedResource: Resource[IO, (HttpClient, Database)] = {
  val client: Resource[IO, HttpClient] =
    Resource.make(IO(HttpClient.create()))(c => IO(c.close()))

  val db: Resource[IO, Database] =
    Resource.make(IO(Database.connect("jdbc:...")))(d => IO(d.close()))

  (client, db).tupled
}
```

Or with a case class wrapper:

```scala
case class TestEnv(client: HttpClient, db: Database, cache: Cache)

override type Res = TestEnv

override def sharedResource: Resource[IO, TestEnv] = {
  for {
    client <- mkClient
    db     <- mkDatabase
    cache  <- mkCache
  } yield TestEnv(client, db, cache)
}
```

### Per-Test Resources

For resources that need fresh instances per test, allocate inside the test
body instead of using `sharedResource`:

```scala
test("isolated temp directory") { _ =>
  Resource.make(IO(Files.createTempDirectory("test"))) { path =>
    IO {
      Files.walk(path).sorted.reverse.foreach(Files.delete)
    }
  }.use { tempDir =>
    IO.pure(expect(Files.exists(tempDir)))
  }
}
```

## GlobalResource (JVM Only)

`GlobalResource` shares a resource across multiple suites. Useful for expensive
resources like database containers or HTTP servers.

### Define a GlobalResource

```scala
import weaver.GlobalResource
import cats.effect.{IO, Resource}

object SharedPostgres extends GlobalResource {
  override def sharedResource(global: GlobalResource.Read): Resource[IO, PostgreSQLContainer] = {
    Resource.make(
      IO.blocking(PostgreSQLContainer.start())
    )(container => IO.blocking(container.stop()))
  }
}
```

### Consume from a suite

```scala
object UserRepoSuite extends IOSuite {
  override type Res = PostgreSQLContainer

  override def sharedResource(global: GlobalResource.Read): Resource[IO, PostgreSQLContainer] =
    global.getOrFail[PostgreSQLContainer]()

  test("can connect") { container =>
    IO.blocking {
      expect(container.jdbcUrl.nonEmpty)
    }
  }
}
```

### Global Resource Sharing Rules

- `GlobalResource` implementations are discovered via classpath scanning
- Resources are identified by type — `global.getOrFail[T]()` uses the type
  parameter to find the matching resource
- Use `global.getOrFail[T]()` — throws if resource not found
- Use `global.get[T]()` — returns `Option[Resource[IO, T]]`
- Lifecycle: allocated before any suite runs, released after all suites complete

## Parallelism Control

### Default Behavior

- `SimpleIOSuite` and `IOSuite`: tests run in **parallel** (unbounded)
- `FunSuite`: tests run **sequentially**

### Override maxParallelism

```scala
object SequentialSuite extends SimpleIOSuite {
  // Force sequential execution
  override def maxParallelism: Int = 1

  test("step 1") { IO.pure(expect(true)) }
  test("step 2") { IO.pure(expect(true)) }
}
```

### Cap to N concurrent tests

```scala
object LimitedParallelSuite extends IOSuite {
  override def maxParallelism: Int = 4
  // ...
}
```

### Why FunSuite is Sequential

`FunSuite` runs synchronously with no effect wrapper, so there is no natural
boundary for parallel execution. Use `SimpleIOSuite` or `IOSuite` for parallel
tests.

## Custom Suite Base Classes

### Creating a base suite with common imports and utilities

```scala
import weaver.IOSuite
import cats.effect.{IO, Resource}

abstract class BaseSuite extends IOSuite {
  // Common utilities available to all extending suites
  def withTempDir[A](use: Path => IO[A]): IO[A] = {
    Resource
      .make(IO(Files.createTempDirectory("suite")))(path =>
        IO(Files.walk(path).sorted.reverse.foreach(Files.delete))
      )
      .use(use)
  }

  // Shared configuration
  def testTimeout: FiniteDuration = 30.seconds
}
```

### Module-specific base suites

```scala
// For all repository tests
abstract class RepositorySuite extends IOSuite {
  override type Res = Transactor[IO]

  override def sharedResource: Resource[IO, Transactor[IO]] =
    TestDatabase.resource

  // Helper available in all extending suites
  def withCleanTable(xa: Transactor[IO])(test: => IO[Expectations]): IO[Expectations] = {
    sql"TRUNCATE TABLE users".update.run.transact(xa) *> test
  }
}

object UserRepoSuite extends RepositorySuite {
  test("insert user") { xa =>
    withCleanTable(xa) {
      for {
        _   <- insertUser(xa, User("Alice", 30))
        all <- findAllUsers(xa)
      } yield expect(all.size == 1)
    }
  }
}
```

## Standalone Runner

Run a single suite as an application (useful for debugging or CI scripting):

```scala
import weaver.IOSuite
import cats.effect.{IO, IOApp}

object Main extends IOApp.Simple {
  val run = MySuite.run
}
```

### sbt integration

```scala
// build.sbt
testFrameworks += new TestFramework("weaver.framework.CatsEffect")
```

Weaver auto-discovers suites on the classpath. Each suite is a test class.

### Filtering suites

```bash
# Run a single suite
sbt "testOnly com.example.MySuite"

# Run suites matching a pattern
sbt "testOnly com.example.*RepoSuite"
```

## Mixing Traits

Weaver suites can mix in additional functionality:

```scala
import weaver.SimpleIOSuite
import weaver.scalacheck.Checkers

// IO tests + ScalaCheck
object PropertySuite extends SimpleIOSuite with Checkers {
  test("reverse twice is identity") {
    forall { (xs: List[Int]) =>
      expect.eql(xs.reverse.reverse, xs)
    }
  }
}
```

```scala
import weaver.FunSuite
import weaver.discipline.Discipline
import cats.kernel.laws.discipline.MonoidTests
import cats.instances.string._

// Pure tests + Discipline
object StringMonoidLaws extends FunSuite with Discipline {
  checkAll("String Monoid", MonoidTests[String].monoid)
}
```

## Resource Cleanup Pitfalls

1. **Do not mutate shared resource state** — parallel tests will race
2. **Use per-test resource allocation** for stateful resources
3. **Prefer `Resource.make`** over try/finally in test bodies
4. **Release actions must not fail** silently — log or report cleanup failures
5. **GlobalResource is JVM-only** — not available on Scala.js or Scala Native
