---
name: scala-testing-specs2
description: Use this skill when writing BDD-style tests with specs2 in Scala. Covers Specification structure, matchers DSL, Given-When-Then syntax, table-driven tests, JSON testing, HTTP testing, Cats Effect integration, and error handling. Trigger when the user mentions specs2, BDD testing, Specification, matchers, table-driven tests, or needs to write tests using specs2's expressive DSL.
---

# BDD-Style Testing with specs2

specs2 is a comprehensive BDD-style testing framework for Scala with expressive syntax, powerful matchers, and integration with ScalaCheck for property-based testing.

## Quick Start

```scala
import org.specs2.mutable.Specification

class CalculatorSpec extends Specification {
  val calc = new Calculator

  "Calculator" should {
    "add two numbers" in {
      calc.add(2, 3) must be equalTo 5
    }

    "subtract two numbers" in {
      calc.subtract(5, 2) must be equalTo 3
    }
  }
}

class Calculator {
  def add(a: Int, b: Int): Int = a + b
  def subtract(a: Int, b: Int): Int = a - b
  def multiply(a: Int, b: Int): Int = a * b
  def divide(a: Int, b: Int): Int = a / b
}
```

## Core Concepts

### Test Structure

specs2 uses `should` / `must` / `can` to group expectations:

```scala
class MySpec extends Specification {
  "My feature" should {
    "do something" in {
      true must beTrue
    }
  }

  "Another feature" must {
    "also pass" in {
      2 + 2 must equal(4)
    }
  }
}
```

### Matchers DSL

#### Comparison

```scala
result must be equalTo 10
result must not be equalTo 6
result must be greaterThan(0)
result must be lessThan(20)
result must be between(9, 11)
```

#### Collections

```scala
numbers must have size 5
numbers must contain(3)
numbers must containAllOf(Seq(1, 2, 3))
numbers must beSorted
List(1, 2, 3) must not contain 4
```

#### Strings

```scala
"hello" must have length 5
"hello" must startWith("he")
"hello" must endWith("lo")
"hello" must contain("ell")
"hello" must be like "h.*o"
```

#### Options and Results

```scala
Some(5) must beSome
Some(5) must beSome(5)
None must beNone
Some(5) must beDefined
None must not beDefined
Success(5) must beSuccessful
Failure("error") must beFailed
```

#### Types and Null

```scala
"hello" must beAnInstanceOf[String]
5 must beAnInstanceOf[Int]
null must beNull
value must not beNull
```

### Custom Matchers

```scala
import org.specs2.matcher.Matcher
import org.specs2.matcher.MatchResult

def beWithin(x: Int, y: Int): Matcher[Int] = new Matcher[Int] {
  def apply(value: Int): MatchResult =
    MatchResult(
      value >= x && value <= y,
      s"$value is not between $x and $y",
      s"$value is between $x and $y"
    )
}

// Usage
val score = 85
score must beWithin(0, 100)
```

Matcher composition:

```scala
// Compose matchers with and
result must be greaterThan(0) and be lessThan(10)
```

## Common Patterns

### BDD-Style with Given-When-Then

```scala
class UserSpec extends Specification {
  "User management" should {
    "create a new user" in {
      val user = User("John", "john@example.com")
      user must not be null
      user.name must be equalTo "John"
      user.email must be equalTo "john@example.com"
    }

    "validate email format" in {
      val user = User("John", "invalid-email")
      user.email must not(beMatching(".*@.*"))
    }
  }
}

case class User(name: String, email: String)
```

### Table-Driven Tests

```scala
import org.specs2.mutable.Specification
import org.specs2.specification.dsl.Tables

class TableDrivenSpec extends Specification with Tables {
  "Email validation" should {
    "work with various formats" in {
      val testCases = Table(
        "email"              -> "valid",
        "alice@example.com"  -> "valid",
        "bob@company.org"    -> "valid",
        "charlie@test.com"   -> "valid"
      )

      forAll(testCases) { email: String =>
        email must contain("@")
      }
    }

    "validate password complexity" in {
      val passwords = Table(
        "password"   -> "should fail",
        "123"        -> "too short",
        "abc"        -> "too short"
      )

      forAll(passwords) { password: String =>
        password.length must be greaterThan(5)
      }
    }
  }
}
```

### JSON Testing

```scala
import io.circe.generic.auto._
import io.circe.parser._

case class User(id: Long, name: String, email: String)

class JsonSpec extends Specification {
  "JSON handling" should {
    "parse valid JSON" in {
      val json = """{"id":1,"name":"Alice","email":"alice@example.com"}"""
      decode[User](json) must beLike {
        case Right(user) => user must be equalTo User(1, "Alice", "alice@example.com")
      }
    }

    "handle invalid JSON" in {
      val json = """{"id":1,"name":"Alice"}"""
      decode[User](json) must beLike {
        case Left(error) => error must not beNull
      }
    }
  }
}
```

### Testing HTTP Clients

```scala
import sttp.client4._

class HttpClientSpec extends Specification {
  val backend = DefaultSyncBackend()

  "HTTP client" should {
    "GET request" in {
      val response = basicRequest
        .get(uri"http://httpbin.org/get")
        .send(backend)

      response.code must be equalTo 200
    }

    "POST request" in {
      val json = """{"name":"test","value":42}"""
      val response = basicRequest
        .post(uri"http://httpbin.org/post")
        .body(json)
        .send(backend)

      response.code must be equalTo 200
    }
  }
}
```

### Cats Effect Integration

```scala
import cats.effect._
import scala.concurrent.Future
import scala.concurrent.ExecutionContext.Implicits.global

class CatsEffectSpec extends Specification {
  "Cats Effect integration" should {
    "run IO in spec" in {
      val io = IO.pure(5 + 5)
      io.unsafeRunSync() must be equalTo 10
    }

    "handle async operations" in {
      val asyncResult = IO.fromFuture {
        IO(Future { Thread.sleep(100); 42 })
      }
      asyncResult.unsafeRunSync() must be equalTo 42
    }
  }
}
```

### Testing Play Framework

```scala
import play.api.mvc._
import play.api.test._
import play.api.test.Helpers._

class PlayControllerSpec extends Specification {
  "Play Controller" should {
    "respond to GET request" in {
      val controller = new MyController(testApplication().injector.instanceOf[ControllerComponents])
      val request = FakeRequest(GET, "/")
      val result = controller.index.apply(request)

      status(result) must be equalTo OK
      contentType(result) must beSome("text/html")
    }
  }
}
```

## Error Handling

```scala
class ErrorHandlerSpec extends Specification {
  "Error handling" should {
    "catch and validate exceptions" in {
      try {
        throw new RuntimeException("Test error")
      } catch {
        case e: RuntimeException =>
          e.getMessage must be equalTo "Test error"
      }
    }

    "expect values to equal" in {
      val result = 10 / 2
      result must be equalTo 5
    }

    "expect values not to equal" in {
      val result = 10 / 2
      result must not be equalTo 6
    }
  }
}
```

## Dependencies

```scala
// specs2 core — check for latest version
libraryDependencies += "org.specs2" %% "specs2-core" % "5.7.+"
libraryDependencies += "org.specs2" %% "specs2-matcher-extra" % "5.7.+"

// Optional integrations
libraryDependencies += "org.specs2" %% "specs2-scalacheck" % "5.7.+" % Test  // property testing
libraryDependencies += "org.specs2" %% "specs2-junit" % "5.7.+" % Test        // JUnit
libraryDependencies += "org.specs2" %% "specs2-mockito" % "5.7.+" % Test      // Mockito
```

## Common Pitfalls

1. **Result type**: specs2 returns `Result`, not `Unit` — don't use `assert`
2. **Import statements**: Always import the necessary specs2 modules
3. **Test isolation**: Ensure each test is independent
4. **Shared mutable state**: Avoid sharing mutable state between tests
5. **Timeouts**: Tests can hang if they block indefinitely

## Related Skills

- **scala-testing-property** — property-based testing with ScalaCheck and law checking with discipline
- **scala-type-classes** — type class patterns that specs2 law checking verifies
- **scala-build-tools** — sbt test configuration

## References

Load these when you need exhaustive matcher details:

- **references/bdd-reference.md** — Complete matcher reference (comparison, collections, strings, Options, custom matchers, pattern matchers, composition)
