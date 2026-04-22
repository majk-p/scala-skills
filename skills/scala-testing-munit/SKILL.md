---
name: scala-testing-munit
description: Use this skill when writing tests with MUnit in Scala. Covers FunSuite, assertions (assertEquals, assert, intercept, assertNoDiff), FunFixture composition, tagging and filtering, test transformations, flaky tests, ScalaCheck property testing, Cats Effect integration via munit-cats-effect, ResourceSuiteLocalFixture, cross-platform testing (JVM/JS/Native), compileErrors for macro testing, and custom diff printers. MUnit is a minimal testing framework by Scalameta with IDE-friendly stack traces, rich diffs, and zero Scala dependencies. Trigger when the user mentions MUnit, munit, FunSuite, assertEquals, FunFixture, munit-cats-effect, or needs to write tests with minimal boilerplate and good IDE integration.
---

# Minimal Testing with MUnit

MUnit is a minimal Scala testing framework by the Scalameta team. It produces IDE-friendly
stack traces with file:line column information, rich unified diffs for assertion failures,
and has zero Scala library dependencies beyond the standard library. It supports JVM,
Scala.js, and Scala Native out of the box.

## Quick Start

```scala
// build.sbt
libraryDependencies += "org.scalameta" %% "munit" % "1.1.0" % Test
testFrameworks += new TestFramework("munit.Framework")
```

```scala
class MySuite extends munit.FunSuite {
  test("addition") {
    assertEquals(1 + 1, 2)
  }

  test("string contains") {
    assert("hello world".contains("world"))
  }

  test("exception expected") {
    intercept[IllegalArgumentException] {
      throw new IllegalArgumentException("boom")
    }
  }
}
```

Test classes must reside under `src/test/scala` and extend `munit.FunSuite`. Each `test(...)`
call registers a test case. Tests run in declaration order by default.

## Assertions API

MUnit provides a focused set of assertions. All produce rich diffs on failure. See
[references/assertions.md](references/assertions.md) for the complete API with examples.

| Assertion | Purpose |
|---|---|
| `assertEquals(obtained, expected)` | Type-safe equality with rich diffs |
| `assert(condition, clue)` | Boolean assertion with optional clue |
| `assertNotEquals(a, b)` | Negative equality assertion |
| `assertNoDiff(obtained, expected)` | Multiline string comparison |
| `assertMatches(value)(PartialFunction)` | Pattern matching assertion |
| `intercept[T](body)` | Expect exception of type T |
| `interceptMessage[T](msg)(body)` | Expect exception with exact message |
| `assume(condition)` | Skip test if condition is false |
| `fail(message)` / `failSuite(message)` | Explicit failure |
| `compileErrors(code)` | Test compiler error messages (macros) |
| `assertEqualsDouble(a, b, delta)` | Floating point comparison with tolerance |

## The clue() System

`clue(x)` captures both the variable name and its value, printing them in the test output
when an assertion fails. Useful for diagnostics without println debugging.

```scala
test("clue captures name and value") {
  val userName = "Alice"
  val age = 30
  // On failure, prints: userName = "Alice", age = 30
  assertEquals(clue(userName), "Bob")
  assertEquals(clue(age), 30)
}

test("multiple clues at once") {
  val x = 1
  val y = 2
  clues(x, y) // prints both on failure
  assertEquals(x + y, 3)
}
```

`clue` works inside any expression: `assertEquals(clue(computeResult), expected)`.

## Test Modifiers

Every test call returns a `Test` object that supports chainable modifiers:

```scala
test("focus only this").only {
  assertEquals(1, 1)
}

test("skip this").ignore {
  fail("never runs")
}

test("expected to fail").fail {
  assertEquals(1, 2) // passes the suite because .fail inverts result
}

test("flaky test".flaky) {
  // retries up to 3 times, succeeds if any attempt passes
  assertEquals(unstableNetworkCall(), "ok")
}

test("not yet implemented".pending) {
  // always reports as "pending", never fails the suite
}
```

Modifier summary:
- `.only` — run only tests marked with `.only` (at most one per suite recommended)
- `.ignore` — skip the test entirely
- `.fail` — invert: the test passes if it fails, fails if it passes
- `.flaky` — retry up to `munitFlakyRetries` times (default 3)
- `.pending` — report as pending, does not fail the suite

## Fixture System

MUnit provides three fixture approaches. See [references/fixtures-and-ce.md](references/fixtures-and-ce.md)
for detailed patterns including Cats Effect integration.

### FunFixture — Test-Local, Composable

```scala
class FunFixtureSuite extends munit.FunSuite {
  val tempDir: FunFixture[Path] = FunFixture[Path](
    setup = { test => Files.createTempDirectory("munit") },
    teardown = { path => Files.deleteIfExists(path) }
  )

  val config: FunFixture[Config] = FunFixture[Config](
    setup = { test => Config(test.name) },
    teardown = { _ => () }
  )

  // Compose multiple fixtures with .map2, .map3
  val both: FunFixture[(Path, Config)] = tempDir.map2(config)

  both.test("uses both fixtures") { case (dir, conf) =>
    assertEquals(Files.exists(dir), true)
    assert(conf.name.nonEmpty)
  }
}
```

### Fixture[T] — Reusable, Suite or Test-Scoped

```scala
class FixtureSuite extends munit.FunSuite {
  val database: Fixture[Database] = new Fixture[Database]("database") {
    private var db: Database = _
    def apply(): Database = db
    override def beforeEach(context: BeforeEach): Unit = {
      db = Database.inMemory()
    }
    override def afterEach(context: AfterEach): Unit = {
      db.close()
    }
  }

  override def munitFixtures: Seq[Fixture[_]] = List(database)

  test("query database") {
    val result = database().query("SELECT 1")
    assertEquals(result, List(Row(1)))
  }
}
```

## Cats Effect Integration (munit-cats-effect)

Add the `munit-cats-effect` dependency for first-class `IO` support:

```scala
libraryDependencies += "org.typelevel" %% "munit-cats-effect" % "2.0.0" % Test
```

```scala
import munit.CatsEffectSuite
import cats.effect.{IO, Resource}

class IOSuite extends CatsEffectSuite {
  test("IO assertion") {
    IO("hello").assertEquals("hello")
  }

  test("IO with map") {
    val io = IO(1 + 1)
    assertIO(io, 2)
  }

  test("interceptIO") {
    interceptIO[IllegalArgumentException] {
      IO.raiseError(new IllegalArgumentException("boom"))
    }
  }
}
```

### Resource Fixtures with Cats Effect

```scala
class ResourceSuite extends CatsEffectSuite {
  // Suite-scoped: shared across all tests, setup once
  val dbFixture = ResourceSuiteLocalFixture(
    "database",
    Resource.eval(IO(Database.connect())).flatMap(db =>
      Resource.make(IO(db))(db => IO(db.close()))
    )
  )

  override def munitFixtures: Seq[Fixture[_]] = List(dbFixture)

  test("suite-scoped resource") {
    val db = dbFixture()
    assertIO(db.query("SELECT 1"), List(Row(1)))
  }
}
```

See [references/fixtures-and-ce.md](references/fixtures-and-ce.md) for `ResourceTestLocalFixture`,
`ResourceFunFixture`, and timeout configuration.

## Tagging and Filtering

```scala
object Slow extends munit.Tag("Slow")
object LinuxOnly extends munit.Tag("LinuxOnly")

class TaggedSuite extends munit.FunSuite {
  test("slow operation".tag(Slow)) {
    Thread.sleep(5000)
    assertEquals(1, 1)
  }

  test("linux-specific".tag(LinuxOnly)) {
    assume(Properties.isLinux)
    assertEquals(sys.props("os.name"), "Linux")
  }

  // Dynamic filtering: override munitTests
  override def munitTests(): Seq[Test] = {
    super.munitTests().filterNot(_.tags.contains(Slow))
  }
}
```

CLI filtering:
```bash
sbt test -- --include-tags=Slow
sbt test -- --exclude-tags=Slow
sbt "testOnly *TaggedSuite -- --include-tags=Slow"
```

Environment variable filtering:
```bash
MUNIT_INCLUDE_TAGS=Slow sbt test
MUNIT_EXCLUDE_TAGS=Slow sbt test
```

## Test Transformations

Customize how tests are executed via `munitTestTransforms` and `munitValueTransforms`:

```scala
class TransformSuite extends munit.FunSuite {
  // Transform test behavior globally
  override def munitTestTransforms: List[TestTransform] = List(
    new TestTransform("retry", { test =>
      test.withBody(() =>
        try test.body()
        catch {
          case e: AssertionError =>
            println(s"Retrying ${test.name}...")
            test.body()
        }
      )
    })
  )

  // Handle custom async types
  override def munitValueTransforms: List[ValueTransform] = List(
    new ValueTransform("MyTask", {
      case t: MyTask[_] => t.toFuture
    })
  )

  test("auto-retried") {
    assertEquals(sometimesFlaky(), "ok")
  }
}
```

### Flaky Test Configuration

```scala
class FlakySuite extends munit.FunSuite {
  override def munitFlakyRetries: Int = 5 // default is 3

  test("network call".flaky) {
    assertEquals(httpGet("https://api.example.com/health"), 200)
  }
}
```

Environment: `MUNIT_FLAKY_OK=true` to not count flaky test failures toward exit code.

## Cross-Platform Testing

Use `%%%` (three percent signs) in sbt for cross-platform dependency resolution:

```scala
libraryDependencies += "org.scalameta" %%% "munit" % "1.1.0" % Test
```

Platform-specific tests:

```scala
import scala.util.Properties

class PlatformSuite extends munit.FunSuite {
  test("JVM-specific") {
    assume(Properties.isJava)
    assertEquals(System.getProperty("java.version").nonEmpty, true)
  }

  test("JS-specific") {
    assume(Properties.isJava == false) // rough check
    // Scala.js specific test
  }
}
```

## Diff Reporting

MUnit automatically pretty-prints case classes, Maps, Lists, and other standard types
with unified diffs on assertion failure. For custom types, provide a `Printer`:

```scala
import munit.Printer

case class Money(amount: BigDecimal, currency: String)

object Money {
  implicit val moneyPrinter: Printer[Money] = Printer[Money] { m =>
    s"${m.amount} ${m.currency}"
  }
}

// In test:
test("money diff") {
  assertEquals(Money(100, "USD"), Money(200, "EUR"))
  // Shows: "obtained: 100 USD" vs "expected: 200 EUR"
}
```

Custom `Compare` typeclass for domain-specific equality:

```scala
import munit.Compare

case class Approx(value: Double)

object Approx {
  implicit val approxCompare: Compare[Approx] = Compare[Approx] { (obtained, expected) =>
    Math.abs(obtained.value - expected.value) < 0.01
  }
}
```

IntelliJ diff viewer integration works automatically via `ComparisonFailException`.

## ScalaCheck Integration

MUnit bundles ScalaCheck property testing. No extra dependency needed:

```scala
class PropertySuite extends munit.FunSuite {
  property("string concatenation length") {
    (a: String, b: String) =>
      assertEquals((a + b).length, a.length + b.length)
  }

  property("list reverse is involutory") {
    (xs: List[Int]) =>
      assertEquals(xs.reverse.reverse, xs)
  }
}
```

For custom generators, import `org.scalacheck.Gen` and `Arbitrary`:

```scala
import org.scalacheck.Gen
import org.scalacheck.Arbitrary

val genMoney: Gen[Money] = for {
  amount <- Gen.chooseNum(0.01, 100000.0).map(BigDecimal(_))
  currency <- Gen.oneOf("USD", "EUR", "GBP")
} yield Money(amount, currency)

implicit val arbMoney: Arbitrary[Money] = Arbitrary(genMoney)

property("money round-trip") { (m: Money) =>
  assertEquals(Money.parse(m.show), m)
}
```

## Dependencies

```scala
// Core MUnit (required)
libraryDependencies += "org.scalameta" %% "munit" % "1.1.0" % Test
testFrameworks += new TestFramework("munit.Framework")

// Cross-platform (use %%% instead of %%)
libraryDependencies += "org.scalameta" %%% "munit" % "1.1.0" % Test

// Cats Effect integration
libraryDependencies += "org.typelevel" %% "munit-cats-effect" % "2.0.0" % Test

// Scala.js
libraryDependencies += "org.scalameta" %%% "munit" % "1.1.0" % Test,
jsEnv := new org.scalajs.jsenv.nodejs.NodeJSEnv()
```

## Related Skills

- `scala-testing` — general Scala testing overview and framework comparison
- `scala-testing-property` — property-based testing with ScalaCheck
- `scala-testing-weaver` — Weaver test framework for Cats Effect

## References

- [assertions.md](references/assertions.md) — Complete assertion API: all methods, clue system,
  compileErrors, custom Compare typeclass, custom Printer, diff options, floating point
- [fixtures-and-ce.md](references/fixtures-and-ce.md) — FunFixture composition patterns,
  Fixture[T] lifecycle, Cats Effect integration, Resource fixtures, timeout configuration
