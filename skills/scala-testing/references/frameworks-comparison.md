# Testing Frameworks Comparison

## Detailed Comparison

### Assertion Mapping Table

| Operation | specs2 | MUnit | Weaver |
|-----------|--------|-------|--------|
| Equality | `a must be equalTo b` | `assertEquals(a, b)` | `expect.eql(a, b)` |
| Boolean true | `a must beTrue` | `assert(a)` | `expect(a)` |
| Boolean false | `a must beFalse` | `assert(!a)` | `expect(!a)` |
| Not equal | `a must not be equalTo b` | `assertNotEquals(a, b)` | `not(expect.eql(a, b))` |
| Greater than | `a must be greaterThan(b)` | `assert(a > b)` | `expect(a > b)` |
| Less than | `a must be lessThan(b)` | `assert(a < b)` | `expect(a < b)` |
| Between | `a must be between(b, c)` | `assert(a >= b && a <= c)` | `expect(a >= b) and expect(a <= c)` |
| Contains | `list must contain(x)` | `assert(list.contains(x))` | `expect(list.contains(x))` |
| Size | `list must have size n` | `assertEquals(list.size, n)` | `expect.eql(list.size, n)` |
| Throws | `expr must throwA[E]` | `intercept[E](expr)` | `IO(expr).attempt.map { case Left(_: E) => success }` |
| Some | `opt must beSome(v)` | `assertEquals(opt, Some(v))` | `expect.eql(opt, Some(v))` |
| None | `opt must beNone` | `assertEquals(opt, None)` | `expect.eql(opt, None)` |
| Type check | `a must beAnInstanceOf[T]` | `assert(a.isInstanceOf[T])` | `expect(a.isInstanceOf[T])` |
| String starts | `s must startWith(p)` | `assert(s.startsWith(p))` | `expect(s.startsWith(p))` |
| String regex | `s must beMatching(r)` | `assert(s.matches(r))` | `expect(s.matches(r))` |
| Match | `a must beLike { case ... }` | `a match { case ... => () }` | `a match { case ... => success; case _ => failure("...") }` |

### Migration: specs2 → MUnit

```scala
// specs2
class UserSpec extends Specification {
  "User" should {
    "create with name" in {
      val user = User("Alice")
      user.name must be equalTo "Alice"
      user.age must be greaterThan(0)
    }
  }
}

// MUnit equivalent
class UserSpec extends FunSuite {
  test("create with name") {
    val user = User("Alice")
    assertEquals(user.name, "Alice")
    assert(user.age > 0)
  }
}
```

### Migration: MUnit → Weaver

```scala
// MUnit
class UserServiceSpec extends CatsEffectSuite {
  test("create user") {
    UserService.create("Alice").map { user =>
      assertEquals(user.name, "Alice")
    }
  }
}

// Weaver equivalent
object UserServiceSpec extends SimpleIOSuite {
  test("create user") {
    UserService.create("Alice").map { user =>
      expect.eql(user.name, "Alice")
    }
  }
}
```

### Migration: ScalaTest → MUnit

```scala
// ScalaTest (FlatSpec)
class UserSpec extends AnyFlatSpec with Matchers {
  "User" should "create with name" in {
    val user = User("Alice")
    user.name shouldBe "Alice"
  }
}

// MUnit equivalent
class UserSpec extends FunSuite {
  test("User should create with name") {
    val user = User("Alice")
    assertEquals(user.name, "Alice")
  }
}
```

## Ecosystem Integration

### Play Framework Testing

```scala
// MUnit with Play
import play.api.test._
import play.api.test.Helpers._
import munit.FunSuite

class PlayControllerSpec extends FunSuite with PlaySpec {
  test("GET / returns OK") {
    val result = route(app, FakeRequest(GET, "/")).get
    assertEquals(status(result), OK)
  }
}
```

### http4s Testing

```scala
// Weaver with http4s
import weaver.IOSuite
import org.http4s._
import org.http4s.implicits._

object RoutesSpec extends SimpleIOSuite {
  val routes = MyRoutes.routes

  test("GET /health returns 200") {
    val request = Request[IO](Method.GET, uri"/health")
    routes.run(request).value.map {
      case Some(response) => expect.eql(response.status, Status.Ok)
      case None => failure("no response")
    }
  }
}
```

### doobie Testing

```scala
// MUnit + doobie
import munit.CatsEffectSuite
import doobie.Transactor
import doobie.implicits._

class RepositorySpec extends CatsEffectSuite {
  val xa = Transactor.fromDriverManager[IO](
    "org.postgresql.Driver",
    "jdbc:postgresql:test",
    "user", "pass"
  )

  test("insert and retrieve") {
    sql"SELECT 1".query[Int].unique.transact(xa).map { result =>
      assertEquals(result, 1)
    }
  }
}
```

## Performance Characteristics

| Framework | Startup Time | Test Overhead | Parallel Suites | Parallel Tests |
|-----------|-------------|---------------|-----------------|----------------|
| specs2 | Medium | Medium | Yes (configurable) | No (default) |
| MUnit | Fast | Low | Yes | No (within suite) |
| Weaver | Fast | Low | Yes | Yes (default) |

## sbt Configuration Per Framework

```scala
// specs2
Test / testOptions += Tests.Argument(TestFrameworks.Specs2, "excluded", "Slow")
Test / testOptions += Tests.Argument(TestFrameworks.Specs2, "sequential", "true")

// MUnit
Test / testOptions += Tests.Argument(TestFrameworks.MUnit, "--verbose")

// Weaver — register the framework
testFrameworks += new TestFramework("weaver.framework.CatsEffect")
Test / testOptions += Tests.Argument(TestFrameworks.Weaver, "--batch-mode")
```
