# MUnit Fixtures and Cats Effect Integration

## FunFixture — Test-Local Composable Fixtures

`FunFixture[T]` provides setup/teardown that runs around each test. Fixtures compose
via `.map2` and `.map3` for combining multiple independent fixtures.

```scala
import munit.FunFixture
import java.nio.file.{Files, Path}

class FunFixtureSuite extends munit.FunSuite {

  // Basic fixture: temporary directory per test
  val tempDir: FunFixture[Path] = FunFixture[Path](
    setup = { test => Files.createTempDirectory(s"${test.name}-") },
    teardown = { path =>
      Files.walk(path).sorted(java.util.Comparator.reverseOrder()).forEach(Files.delete)
    }
  )

  // Fixture with configuration
  case class Config(name: String, retries: Int)
  val config: FunFixture[Config] = FunFixture[Config](
    setup = { test => Config(test.name, retries = 3) },
    teardown = { _ => () }
  )

  // Database fixture
  case class TestDb(conn: Connection, cleanUp: () => Unit)
  val database: FunFixture[TestDb] = FunFixture[TestDb](
    setup = { test =>
      val conn = DriverManager.getConnection("jdbc:h2:mem:test")
      migrate(conn)
      TestDb(conn, () => conn.close())
    },
    teardown = { db => db.cleanUp() }
  )

  // Compose two fixtures
  val dirWithConfig: FunFixture[(Path, Config)] = tempDir.map2(config)

  // Compose three fixtures
  val allThree: FunFixture[(Path, Config, TestDb)] = tempDir.map3(config, database)

  // Single fixture test
  tempDir.test("create file in temp dir") { dir =>
    val file = dir.resolve("test.txt")
    Files.writeString(file, "hello")
    assertEquals(Files.readString(file), "hello")
  }

  // Composed fixture test
  dirWithConfig.test("config has test name") { case (dir, cfg) =>
    assert(cfg.name.nonEmpty)
    assertEquals(Files.exists(dir), true)
  }

  // Three-way composition
  allThree.test("full integration") { case (dir, cfg, db) =>
    assert(cfg.retries == 3)
    val result = db.conn.prepareStatement("SELECT 1").executeQuery()
    assert(result.next())
    assertEquals(result.getInt(1), 1)
  }
}
```

### FunFixture.map and FunFixture.mapThunk

```scala
// Transform a fixture's output
val tempFile: FunFixture[Path] = tempDir.map { dir =>
  Files.createFile(dir.resolve("test.dat"))
}

// Lazy transformation (setup not called until test runs)
val lazyConfig: FunFixture[Config] = config.mapThunk { cfg =>
  cfg.copy(name = cfg.name.toUpperCase)
}

tempFile.test("file exists") { file =>
  assertEquals(Files.exists(file), true)
}
```

## Fixture[T] — Reusable Lifecycle Fixtures

`Fixture[T]` gives full control over setup/teardown timing with lifecycle hooks:
`beforeAll`, `afterAll`, `beforeEach`, `afterEach`.

```scala
import munit.{Fixture, FunSuite}

class FixtureSuite extends FunSuite {

  // Suite-scoped fixture: setup once, shared across all tests
  val server: Fixture[HttpServer] = new Fixture[HttpServer]("server") {
    private var instance: HttpServer = _

    def apply(): HttpServer = instance

    override def beforeAll(): Unit = {
      instance = HttpServer.start(0) // random port
    }

    override def afterAll(): Unit = {
      instance.stop()
    }
  }

  // Test-scoped fixture: fresh instance per test
  val repository: Fixture[Repository] = new Fixture[Repository]("repository") {
    private var repo: Repository = _

    def apply(): Repository = repo

    override def beforeEach(context: BeforeEach): Unit = {
      repo = Repository.inMemory()
    }

    override def afterEach(context: AfterEach): Unit = {
      repo.clear()
    }
  }

  // Register fixtures so MUnit manages their lifecycle
  override def munitFixtures: Seq[Fixture[_]] = List(server, repository)

  test("server is running") {
    val port = server().port
    assert(port > 0)
    assertEquals(HttpClient.get(s"http://localhost:$port/health"), 200)
  }

  test("repository starts empty") {
    assertEquals(repository().findAll(), List.empty)
  }

  test("repository insert and find") {
    val repo = repository()
    repo.insert(User("Alice", 30))
    assertEquals(repo.findAll().length, 1)
  }
}
```

### Fixture Lifecycle Hooks

```scala
trait FixtureLifecycle {
  // Suite level — run once
  def beforeAll(): Unit = ()
  def afterAll(): Unit = ()

  // Test level — run for each test
  def beforeEach(context: BeforeEach): Unit = ()
  def afterEach(context: AfterEach): Unit = ()

  // Access test metadata
  // BeforeEach contains: test: Test, annotations: List[Any]
  // AfterEach  contains: test: Test, result: Either[Throwable, Any]
}
```

## FutureFixture (MUnit 1.0+)

Async setup and teardown for non-Cats-Effect projects.

```scala
import munit.FutureFixture
import scala.concurrent.Future

class AsyncFixtureSuite extends munit.FunSuite {
  override val munitTimeout: FiniteDuration = 10.seconds

  val asyncResource: FutureFixture[ApiClient] = FutureFixture[ApiClient](
    "api-client",
    setup = { test =>
      Future(ApiClient.connect("http://api.example.com"))
    },
    teardown = { client =>
      Future(client.close())
    }
  )

  override def munitFixtures: Seq[Fixture[_]] = List(asyncResource)

  test("api returns data") {
    val client = asyncResource()
    assertEquals(client.fetch("/users").length > 0, true)
  }
}
```

## Cats Effect Integration

### Setup

```scala
// build.sbt
libraryDependencies += "org.typelevel" %% "munit-cats-effect" % "2.0.0" % Test
```

### CatsEffectSuite — Base Class

```scala
import munit.CatsEffectSuite
import cats.effect.IO

class BasicIOSuite extends CatsEffectSuite {

  // Tests return IO[Unit] instead of Unit
  test("IO evaluation") {
    IO(1 + 1).assertEquals(2)
  }

  test("IO chaining") {
    for {
      x <- IO(1)
      y <- IO(2)
      _ <- IO(assertEquals(x + y, 3))
    } yield ()
  }

  test("IO failure") {
    IO.raiseError[Unit](new RuntimeException("boom"))
      .attempt
      .map(_.isLeft)
      .assert(b => b == true)
  }
}
```

### IO Assertion Extensions

```scala
class IOAssertionsSuite extends CatsEffectSuite {

  // assertEquals on IO
  test("IO.assertEquals") {
    IO(List(1, 2, 3).sum).assertEquals(6)
  }

  // assertIO shorthand
  test("assertIO") {
    val io = IO("hello world")
    assertIO(io, "hello world")
  }

  // assertIO_ for IO[Unit] with assertion inside
  test("assertIO_") {
    assertIO_(IO(assertEquals(1, 1)))
  }

  // interceptIO
  test("interceptIO") {
    interceptIO[IllegalArgumentException] {
      IO.raiseError(new IllegalArgumentException("bad"))
    }
  }

  // interceptMessageIO
  test("interceptMessageIO") {
    interceptMessageIO[IllegalArgumentException]("expected") {
      IO.raiseError(new IllegalArgumentException("expected"))
    }
  }

  // IO-based clue
  test("IO with clue") {
    val result = IO(42)
    result.map(clue(_)).assertEquals(42)
  }
}
```

### ResourceSuiteLocalFixture — Suite-Scoped Resource

Setup runs once before all tests. Teardown runs after all tests complete. Shared state
across all tests in the suite.

```scala
import cats.effect.{IO, Resource}
import munit.CatsEffectSuite

class SharedResourceSuite extends CatsEffectSuite {

  val postgres: ResourceSuiteLocalFixture[Transactor[IO]] =
    ResourceSuiteLocalFixture(
      "postgres",
      for {
        container <- PostgreSQLContainer.resource[IO]()
        xa <- Resource.eval {
          val cfg = container.jdbcUrl
          Transactor.fromConnectionString[IO](cfg)
        }
      } yield xa
    )

  override def munitFixtures: Seq[Fixture[_]] = List(postgres)

  test("table exists") {
    val xa = postgres()
    assertIO(sql"SELECT 1".query[Int].unique.transact(xa), 1)
  }

  test("insert and query") {
    val xa = postgres()
    for {
      _ <- insertUser(xa, User("Alice", 30))
      count <- countUsers(xa)
      _ <- IO(assertEquals(count, 1))
    } yield ()
  }
}
```

### ResourceTestLocalFixture — Test-Scoped Resource

Fresh resource for each test. Setup before, teardown after every test.

```scala
class PerTestResourceSuite extends CatsEffectSuite {

  val testDb: ResourceTestLocalFixture[Transactor[IO]] =
    ResourceTestLocalFixture(
      "test-db",
      Resource.make {
        IO {
          val xa = Transactor.fromConnectionString[IO]("jdbc:h2:mem:test")
          runMigrations(xa)
          xa
        }
      } { xa =>
        IO(xa.close())
      }
    )

  override def munitFixtures: Seq[Fixture[_]] = List(testDb)

  test("starts with empty table") {
    val xa = testDb()
    assertIO(countUsers(xa), 0)
  }

  test("previous test data is gone") {
    val xa = testDb()
    assertIO(countUsers(xa), 0) // fresh database
  }
}
```

### ResourceFunFixture — Resource + FunFixture Composition

Combines `Resource[IO, T]` with `FunFixture[T]` semantics. Composable via `.map2`.

```scala
class ResourceFunFixtureSuite extends CatsEffectSuite {

  val kvStore: FunFixture[KVStore] = ResourceFunFixture(
    Resource.make(IO(KVStore.inMemory()))(store => IO(store.clear()))
  )

  val cache: FunFixture[Cache] = ResourceFunFixture(
    Resource.make(IO(Cache.create()))(c => IO(c.invalidateAll()))
  )

  val both: FunFixture[(KVStore, Cache)] = kvStore.map2(cache)

  both.test("use both store and cache") { case (store, cache) =>
    for {
      _ <- IO(store.put("key", "value"))
      _ <- IO(cache.put("key", "value"))
      _ <- IO(assertEquals(store.get("key"), Some("value")))
      _ <- IO(assertEquals(cache.get("key"), Some("value")))
    } yield ()
  }
}
```

### Timeout Configuration

```scala
class TimeoutSuite extends CatsEffectSuite {

  // Timeout for IO-based tests (Cats Effect)
  // Default: 10 seconds
  override val munitIOTimeout: FiniteDuration = 30.seconds

  // Timeout for synchronous tests
  // Default: 30 seconds
  override val munitTimeout: FiniteDuration = 60.seconds

  test("long-running IO respects munitIOTimeout") {
    IO.sleep(5.seconds) *> IO(assertEquals(1, 1))
  }

  // Per-test timeout override (not built-in; use IO.race)
  test("custom per-test timeout") {
    val work = IO.sleep(1.second) *> IO(42)
    val timeout = IO.sleep(100.millis) *> IO.raiseError(new TimeoutException)
    IO.race(work, timeout).map {
      case Left(result)  => assertEquals(result, 42)
      case Right(_)      => fail("timed out")
    }
  }
}
```

### Environment Variable: MUNIT_IO_TIMEOUT

```bash
# Global timeout override for IO tests
MUNIT_IO_TIMEOUT=60s sbt test
```

## Suite Lifecycle Hooks

Beyond fixtures, MUnit provides hooks for suite-level setup/teardown:

```scala
class LifecycleSuite extends munit.FunSuite {
  override def beforeAll(): Unit = {
    // Run once before all tests
    println("Suite starting")
  }

  override def afterAll(): Unit = {
    // Run once after all tests
    println("Suite finished")
  }

  override def beforeEach(context: BeforeEach): Unit = {
    // Run before each test
    println(s"Starting: ${context.test.name}")
  }

  override def afterEach(context: AfterEach): Unit = {
    // Run after each test
    context.result match {
      case Right(_) => println(s"Passed: ${context.test.name}")
      case Left(e)  => println(s"Failed: ${context.test.name}: ${e.getMessage}")
    }
  }

  test("example") {
    assertEquals(1, 1)
  }
}
```

### Ordering: Fixture vs Hook Execution

For a suite with both fixtures and hooks, execution order is:

```
beforeAll()                    — suite hook
  fixture.beforeAll()          — per-fixture
    beforeEach()               — suite hook
      fixture.beforeEach()     — per-fixture
        test body
      fixture.afterEach()      — per-fixture
    afterEach()                — suite hook
  fixture.afterAll()           — per-fixture
afterAll()                     — suite hook
```

Fixtures registered in `munitFixtures` are set up in declaration order and torn down
in reverse order.
