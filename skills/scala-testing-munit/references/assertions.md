# MUnit Assertions — Complete API Reference

## assertEquals

The primary assertion. Type-safe equality comparison with rich diff output.

```scala
test("assertEquals basic") {
  assertEquals(1 + 1, 2)
  assertEquals("hello".toUpperCase, "HELLO")
  assertEquals(List(1, 2, 3), List(1, 2, 3))
}

test("assertEquals with case class diff") {
  case class User(name: String, age: Int, role: String)
  val obtained = User("Alice", 30, "admin")
  val expected = User("Bob", 25, "user")
  // Shows unified diff of fields:
  //   name: "Alice" => "Bob"
  //   age:  30 => 25
  //   role: "admin" => "user"
  assertEquals(obtained, expected)
}

test("assertEquals with Map") {
  val obtained = Map("a" -> 1, "b" -> 2, "c" -> 3)
  val expected = Map("a" -> 1, "b" -> 99, "d" -> 4)
  // Shows: b: 2 != 99, extra key c, missing key d
  assertEquals(obtained, expected)
}
```

## assert / assertNotEquals

```scala
test("assert with boolean") {
  assert(1 < 2)
  assert("hello".nonEmpty, "string should not be empty")
}

test("assert with clue") {
  val items = List(1, 2, 3)
  assert(items.length > 5, s"Expected more than 5 items, got ${items.length}")
}

test("assertNotEquals") {
  assertNotEquals(1, 2)
  assertNotEquals("abc", "def")
}
```

## assertNoDiff

Multiline string comparison. Shows line-by-line diff instead of single-line mismatch.

```scala
test("assertNoDiff for multiline strings") {
  val obtained = """
    |line 1
    |line 2
    |line 3
    |""".stripMargin

  val expected = """
    |line 1
    |line CHANGED
    |line 3
    |""".stripMargin

  // Shows:
  //   obtained:
  //     line 1
  //   - line 2
  //   + line CHANGED
  //     line 3
  assertNoDiff(obtained, expected)
}

test("assertNoDiff with case class toString") {
  case class Config(host: String, port: Int)
  val cfg = Config("localhost", 8080)
  assertNoDiff(cfg.toString, "Config(localhost,8080)")
}
```

## assertMatches

Pattern matching assertion using a `PartialFunction`. Fails if the value does not match.

```scala
test("assertMatches on sealed trait") {
  sealed trait Result
  case class Success(value: Int) extends Result
  case class Failure(msg: String) extends Result

  val result: Result = Success(42)
  assertMatches(result) { case Success(value) =>
    assertEquals(value, 42)
  }
}

test("assertMatches on Option") {
  val opt: Option[String] = Some("hello")
  assertMatches(opt) { case Some(s) =>
    assert(s.startsWith("h"))
  }
}

test("assertMatches fails on no match") {
  val opt: Option[String] = None
  // Fails: "value did not match partial function"
  assertMatches(opt) { case Some(s) => () }
}
```

## intercept / interceptMessage

```scala
test("intercept catches exception type") {
  intercept[IllegalArgumentException] {
    throw new IllegalArgumentException("bad argument")
  }
}

test("intercept fails if no exception thrown") {
  intercept[IllegalArgumentException] {
    // Fails: "expected IllegalArgumentException but no exception was thrown"
    val x = 1
  }
}

test("intercept fails if wrong exception type") {
  intercept[IllegalArgumentException] {
    // Fails: "expected IllegalArgumentException but IllegalStateException was thrown"
    throw new IllegalStateException("wrong")
  }
}

test("interceptMessage checks exact message") {
  interceptMessage[IllegalArgumentException]("expected message") {
    throw new IllegalArgumentException("expected message")
  }
}

test("interceptMessage fails on wrong message") {
  interceptMessage[IllegalArgumentException]("expected") {
    // Fails: "expected exception message 'expected' but got 'actual'"
    throw new IllegalArgumentException("actual")
  }
}
```

## assume

Skip a test conditionally. Useful for platform-specific or environment-dependent tests.

```scala
test("only on Linux") {
  assume(Properties.isLinux, "This test requires Linux")
  assertEquals(runNativeCommand(), 0)
}

test("requires env variable") {
  val apiKey = sys.env.get("API_KEY")
  assume(apiKey.isDefined, "API_KEY environment variable must be set")
  assertEquals(fetchData(apiKey.get), expected)
}

test("requires Java 11+") {
  val version = System.getProperty("java.version")
  assume(version.startsWith("11") || version.startsWith("17"))
  assertEquals(useNewJavaAPI(), "ok")
}
```

## fail / failSuite

```scala
test("explicit failure") {
  val result = parseInput("invalid")
  if (result.isLeft) {
    fail(s"Parse failed: ${result.left.get}")
  }
}

test("failSuite aborts the entire suite") {
  // Use when a shared resource cannot be initialized
  // Stops all subsequent tests in the suite
  failSuite("Database connection failed, aborting suite")
}
```

## compileErrors

Test that code produces expected compiler errors. Essential for macro testing.

```scala
test("compileErrors catches type errors") {
  assertEquals(
    compileErrors("1 + \"string\""),
    """|error:
       |1 + "string"
       |    ^
       |""".stripMargin
  )
}

test("compileErrors for macro validation") {
  assertEquals(
    compileErrors("""JsonCodec.encode[NoCodecType]"""),
    "error: could not find implicit for JsonCodec[NoCodecType]"
  )
}

test("compileErrors on valid code returns empty") {
  assertEquals(compileErrors("1 + 1"), "")
}
```

`compileErrors` is a macro that type-checks the given string and captures any errors.
The result is a `String` containing the compiler error messages.

## Floating Point Assertions

```scala
test("assertEqualsDouble with tolerance") {
  val result = 0.1 + 0.2
  assertEqualsDouble(result, 0.3, 0.0001)
}

test("assertEqualsFloat with tolerance") {
  val result: Float = 0.1f + 0.2f
  assertEqualsFloat(result, 0.3f, 0.0001f)
}

test("assertEqualsDouble zero delta requires exact match") {
  assertEqualsDouble(1.0, 1.0, 0.0)
}
```

## The clue() System

```scala
test("clue captures variable name and value") {
  val result = computeValue()
  // On failure, prints: result = 42 (or whatever value)
  assertEquals(clue(result), expected)
}

test("clue with expressions") {
  val items = fetchItems()
  assertEquals(clue(items.length), 10)
  assertEquals(clue(items.head.name), "first")
}

test("clues for multiple values") {
  val x = computeX()
  val y = computeY()
  val z = computeZ()
  clues(x, y, z) // prints all three on any subsequent failure
  assertEquals(x + y + z, 100)
}

test("clue inside map/flatMap") {
  val results = List(1, 2, 3).map { i =>
    val doubled = i * 2
    clue(doubled) // captures per-iteration value
    doubled
  }
  assertEquals(results, List(2, 4, 6))
}
```

## Custom Compare Typeclass

Override equality semantics for specific types without modifying the type itself.

```scala
import munit.Compare

case class Temperature(celsius: Double)

object Temperature {
  implicit val temperatureCompare: Compare[Temperature] =
    Compare[Temperature] { (obtained, expected) =>
      Math.abs(obtained.celsius - expected.celsius) < 0.001
    }
}

test("custom compare for Temperature") {
  val t1 = Temperature(36.6)
  val t2 = Temperature(36.6001)
  // Passes because custom Compare allows 0.001 tolerance
  assertEquals(t1, t2)
}
```

## Custom Printer

Control how values are displayed in diff output and error messages.

```scala
import munit.Printer

case class Money(amount: BigDecimal, currency: String)

object Money {
  implicit val moneyPrinter: Printer[Money] = Printer[Money] { m =>
    s"${m.amount.setScale(2)} ${m.currency}"
  }
}

test("custom printer for Money") {
  // Failure shows: obtained: 100.00 USD != expected: 200.00 EUR
  assertEquals(Money(100, "USD"), Money(200, "EUR"))
}

// Custom printer for collections
implicit val intListPrinter: Printer[List[Int]] = Printer[List[Int]] { list =>
  list.mkString("[", ", ", "]")
}
```

## Diff Options

Control diff rendering behavior via suite-level overrides:

```scala
import munit.diff.DiffOptions

class DiffOptionsSuite extends munit.FunSuite {
  // Disable ANSI colors in diff output
  override def munitDiffOptions: DiffOptions =
    DiffOptions.default.copy(ansiColors = false)

  // Or use system property: MUNIT_DIFF_ANSI_COLORS=false

  test("no color diffs") {
    assertEquals("abc", "xyz")
  }
}
```

The `DiffOptions` case class provides:
- `ansiColors: Boolean` — colorize diff output (default: true)
- `printEmptyLines: Boolean` — show empty lines in diff (default: false)

Environment variables for diff control:
- `MUNIT_DIFF_ANSI_COLORS` — set to `false` to disable colors
