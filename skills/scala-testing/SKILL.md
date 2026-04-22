---
name: scala-testing
description: Use this skill when writing tests in Scala and choosing a testing framework. Covers specs2 (BDD-style with matchers DSL), MUnit (minimal, IDE-friendly with rich diffs), and Weaver (effect-native, Typelevel ecosystem, parallel by default). Also covers property-based testing with ScalaCheck and law checking with Discipline. Trigger when the user mentions testing, unit tests, integration tests, test framework, specs2, MUnit, Weaver, ScalaTest, ScalaCheck, discipline, assertions, matchers, test suites, or needs to write any kind of test in Scala — even if they don't explicitly name the framework.
---

# Testing Frameworks in Scala

Scala has four dominant testing approaches: **specs2** (BDD-style with expressive matchers DSL), **MUnit** (minimal boilerplate, IDE-friendly diffs via JUnit), **Weaver** (effect-native for cats-effect, parallel by default), and **ScalaTest** (most established, many styles). For property-based testing, **ScalaCheck** generates random inputs and **Discipline** verifies type class laws — both integrate with all frameworks.

This skill covers all four. When the user's codebase uses one, focus on that framework. When the choice is open, recommend based on project needs: MUnit for general-purpose testing, specs2 for BDD requirements, Weaver for pure FP projects with cats-effect.

## Quick Start

### specs2

```scala
import org.specs2.mutable.Specification

class CalculatorSpec extends Specification {
  "Calculator" should {
    "add two numbers" in {
      val result = 2 + 3
      result must be equalTo 5
    }

    "handle negative numbers" in {
      val result = -1 + 1
      result must be equalTo 0
    }

    "compare strings" in {
      "hello" must have length 5
      "hello" must startWith("he")
    }
  }
}
```

### MUnit

```scala
import munit.FunSuite

class CalculatorSpec extends FunSuite {
  test("add two numbers") {
    val result = 2 + 3
    assertEquals(result, 5)
  }

  test("handle negative numbers") {
    val result = -1 + 1
    assertEquals(result, 0)
  }

  test("compare strings") {
    assertEquals("hello".length, 5)
    assert("hello".startsWith("he"))
  }
}
```

### Weaver

```scala
import weaver.IOSuite
import weaver.scalacheck.Checkers

object CalculatorSpec extends SimpleIOSuite {
  test("add two numbers") {
    val result = 2 + 3
    expect.eql(result, 5)
  }

  test("handle negative numbers") {
    val result = -1 + 1
    expect.eql(result, 0)
  }

  test("compare strings") {
    expect.eql("hello".length, 5) and expect("hello".startsWith("he"))
  }
}
```

## Framework Comparison

| Aspect | specs2 | MUnit | Weaver |
|--------|--------|-------|--------|
| **Style** | BDD with matchers DSL | Minimal JUnit-style | Effect-native (IO-first) |
| **Assertions** | `must be equalTo`, matchers | `assertEquals`, `assert` | `expect.eql`, `expect` |
| **CE Integration** | Via specs2-ce | Via munit-cats-effect | Built-in |
| **Parallelism** | Sequential | Suite-level | Test-level (default) |
| **IDE Support** | Good | Excellent (JUnit) | Good |
| **Boilerplate** | Medium | Minimal | Minimal |
| **Ecosystem** | Broad | Broad | Typelevel |
| **Learning Curve** | Medium | Low | Low |
| **Test Object** | `class ... extends Specification` | `class ... extends FunSuite` | `object ... extends SimpleIOSuite` |
| **Async** | `Action { ... }.await` | `test("name") { IO { ... } }` | IO-native |
| **Fixtures** | Step-wise, mutable specs | `Fixtures` trait | `SharedResource` module |

### When to Use Each

**specs2** — projects that need BDD-style test structure, expressive matchers DSL, Given-When-Then syntax, table-driven tests, or detailed failure reporting. Good fit when tests serve as living documentation. The mutable `Specification` variant supports familiar `should` / `in` blocks. Widely adopted in the Play ecosystem.

**MUnit** — general-purpose testing where minimal learning curve and excellent IDE integration matter most. JUnit-based runner means IntelliJ and VS Code show test results natively with clickable stack traces and diff highlights. Cross-platform (JVM, Scala.js, Scala Native). Best default choice for new projects that don't need BDD syntax.

**Weaver** — pure FP projects built on cats-effect. Tests are `IO` values, so resource management (database connections, HTTP clients) integrates naturally via `cats.effect.Resource`. Tests run in parallel by default, reducing suite runtime. Fits the Typelevel ecosystem (http4s, skunk, doobie). Less ideal if the team isn't committed to cats-effect.

**ScalaTest** — legacy codebases or teams with Java/JUnit familiarity. Provides multiple testing styles (`FlatSpec`, `FunSuite`, `WordSpec`, `FeatureSpec`, `PropSpec`) in one framework. Most mature and widely adopted, but higher boilerplate than MUnit for equivalent tests. Not detailed further here — recommend MUnit or specs2 for new projects.

## Core Patterns

### Basic Assertions

```scala
// specs2 — matchers DSL
result must be equalTo 5
result must be greaterThan(0)
result must be between(1, 10)
Some(result) must beSome(5)
List(1, 2, 3) must contain(2)

// MUnit — standard assertions
assertEquals(result, 5)
assert(result > 0)
assert(result >= 1 && result <= 10, s"$result not in range [1, 10]")
assertEquals(Some(result), Some(5))
assert(List(1, 2, 3).contains(2))

// Weaver — expect-based
expect.eql(result, 5)
expect(result > 0)
expect(result >= 1) and expect(result <= 10)
expect.eql(Some(result), Some(5))
```

### Testing Effects (cats-effect IO)

```scala
// specs2 + cats-effect
import cats.effect.IO
import org.specs2.mutable.Specification
import org.specs2.execute.AsResult

class IoSpec extends Specification {
  "IO operations" should {
    "run and assert" in {
      val io = IO.pure(42)
      io.unsafeRunSync() must be equalTo 42
    }
  }
}

// MUnit + cats-effect
import cats.effect.IO
import munit.CatsEffectSuite

class IoSpec extends CatsEffectSuite {
  test("run and assert") {
    val io = IO.pure(42)
    io.map(result => assertEquals(result, 42))
  }
}

// Weaver — IO is the default
import weaver.IOSuite

object IoSpec extends SimpleIOSuite {
  test("run and assert") {
    val io = IO.pure(42)
    io.map(result => expect.eql(result, 42))
  }
}
```

### Resource Management

```scala
// MUnit — fixture via munit-cats-effect
import cats.effect.{IO, Resource}
import munit.CatsEffectSuite

class DbSpec extends CatsEffectSuite {
  override val munitFixtures = List(database)

  private val database = ResourceSuiteLocalFixture("db", Resource.eval(IO.pure(new MockDb)))

  test("use database") {
    val db = database()
    db.query("SELECT 1").map(result => assertEquals(result, 1))
  }
}

// Weaver — shared resources via IOSuite
import cats.effect.{IO, Resource}
import weaver.IOSuite
import weaver.Resource

object DbSpec extends IOSuite {
  type Res = MockDb
  def sharedResource: Resource[IO, MockDb] =
    Resource.eval(IO.pure(new MockDb))

  test("use database") { db =>
    db.query("SELECT 1").map(result => expect.eql(result, 1))
  }
}
```

### Exception Testing

```scala
// specs2
result must throwA[IllegalArgumentException]
result must throwA[RuntimeException]("error message")

// MUnit
intercept[IllegalArgumentException] {
  throw new IllegalArgumentException("bad")
}

// Weaver (via IO)
test("catch exceptions") {
  IO.raiseError(new IllegalArgumentException("bad")).attempt.map {
    case Left(e: IllegalArgumentException) => success
    case other => failure(s"Unexpected: $other")
  }
}
```

### Table-Driven Tests

```scala
// specs2 — Tables DSL
import org.specs2.mutable.Specification
import org.specs2.specification.dsl.Tables

class TableSpec extends Specification with Tables {
  "addition" should {
    "work for various inputs" in {
      val cases = Table(
        ("a", "b", "expected"),
        (1,   2,   3),
        (0,   0,   0),
        (-1,  1,   0),
        (10,  20,  30)
      )
      forAll(cases) { (a, b, expected) =>
        a + b must be equalTo expected
      }
    }
  }
}

// MUnit — tests as values
class TableSpec extends FunSuite {
  val cases = List(
    (1, 2, 3),
    (0, 0, 0),
    (-1, 1, 0),
    (10, 20, 30)
  )

  cases.foreach { case (a, b, expected) =>
    test(s"$a + $b = $expected") {
      assertEquals(a + b, expected)
    }
  }
}

// Weaver — test registration in loop
object TableSpec extends SimpleIOSuite {
  val cases = List(
    (1, 2, 3),
    (0, 0, 0),
    (-1, 1, 0),
    (10, 20, 30)
  )

  cases.foreach { case (a, b, expected) =>
    test(s"$a + $b = $expected") {
      expect.eql(a + b, expected)
    }
  }
}
```

## Property-Based Testing

ScalaCheck generates random inputs to verify properties that hold for all valid values. Discipline verifies type class laws (Monoid, Functor, Monad, etc.) via ScalaCheck properties. Both integrate with specs2, MUnit, and Weaver.

```scala
// MUnit + ScalaCheck
import munit.ScalaCheckSuite
import org.scalacheck.Prop.forAll

class PropertySpec extends ScalaCheckSuite {
  property("list reverse is idempotent") {
    forAll { (l: List[Int]) =>
      l.reverse.reverse == l
    }
  }
}

// MUnit + Discipline (law checking)
import munit.DisciplineSuite
import cats.kernel.laws.discipline.MonoidTests

class MonoidSpec extends DisciplineSuite {
  checkAll("List[Int].monoid", MonoidTests[List[Int]].monoid)
}
```

For full property-based testing and law checking documentation, see **scala-testing-property** in Related Skills.

## Dependencies

```scala
// specs2 — check for latest version
libraryDependencies ++= Seq(
  "org.specs2" %% "specs2-core" % "5.7.+" % Test,
  "org.specs2" %% "specs2-matcher-extra" % "5.7.+" % Test
)
// Optional: cats-effect integration
libraryDependencies += "org.specs2" %% "specs2-cats-effect" % "5.7.+" % Test
// Optional: ScalaCheck integration
libraryDependencies += "org.specs2" %% "specs2-scalacheck" % "5.7.+" % Test

// MUnit — check for latest version
libraryDependencies ++= Seq(
  "org.scalameta" %% "munit" % "1.2.+" % Test
)
// Optional: cats-effect integration
libraryDependencies += "org.typelevel" %% "munit-cats-effect" % "2.0.+" % Test
// Optional: ScalaCheck integration
libraryDependencies += "org.scalameta" %% "munit-scalacheck" % "1.2.+" % Test
// Optional: Discipline law checking
libraryDependencies += "org.typelevel" %%% "discipline-munit" % "2.0.+" % Test

// Weaver — check for latest version
libraryDependencies ++= Seq(
  "com.disneystreaming" %% "weaver-cats" % "0.9.+" % Test
)
// Optional: ScalaCheck integration
libraryDependencies += "com.disneystreaming" %% "weaver-scalacheck" % "0.9.+" % Test
// Optional: Discipline integration
libraryDependencies += "com.disneystreaming" %% "weaver-discipline" % "0.9.+" % Test

// ScalaTest — check for latest version (legacy)
libraryDependencies += "org.scalatest" %% "scalatest" % "3.2.+" % Test

// ScalaCheck (works with all frameworks)
libraryDependencies += "org.scalacheck" %% "scalacheck" % "1.19.+" % Test
```

## Common Pitfalls

1. **specs2 returns Result, not Unit** — never use `assert()` inside specs2; always use matchers (`must`, `should`)
2. **Weaver uses `object`, not `class`** — test suites are singleton objects, not instantiable classes
3. **MUnit JUnit dependency** — MUnit requires JUnit on the classpath; add `"junit" % "junit" % "4.13" % Test`
4. **Parallel execution** — specs2 runs sequentially by default; Weaver runs tests in parallel; MUnit runs suites in parallel but tests sequentially within a suite
5. **Async in specs2** — must use `Action { ... }.await` or `unsafeRunSync()` for effectful tests; prefer the `specs2-cats-effect` module
6. **Assertion argument order** — `assertEquals(actual, expected)` in MUnit vs `expect.eql(expected, actual)` confusion — both use `(actual, expected)`, but double-check

## Related Skills

- **scala-testing-specs2** — deep dive into specs2: matchers DSL, Given-When-Then, table-driven tests, JSON testing, HTTP testing, Cats Effect integration
- **scala-testing-munit** — deep dive into MUnit: fixtures, FunSuite, CatsEffectSuite, ScalaCheckSuite, DisciplineSuite, cross-platform testing
- **scala-testing-weaver** — deep dive into Weaver: IOSuite, shared resources, parallel execution, effect-native patterns, Typelevel integration
- **scala-testing-property** — ScalaCheck generators, shrinking, conditional properties, Discipline law checking (Monoid, Functor, Monad laws)

## References

Load these when you need exhaustive details or patterns not shown above:

- **references/frameworks-comparison.md** — Detailed framework comparison: specs2 vs MUnit vs Weaver vs ScalaTest, migration guides, assertion mapping table, ecosystem integration, performance benchmarks, sbt configuration for each framework
