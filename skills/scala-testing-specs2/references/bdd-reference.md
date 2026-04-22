# BDD Matchers Reference

Exhaustive catalog of specs2 matchers, custom matcher patterns, and composition operators.
The main SKILL.md covers basic examples; this file provides the full reference.

## Comparison Matchers

```scala
// Equality
value must be equalTo 5
value must not be equalTo 6
value must be_== 5          // alias for equalTo
value must be_!= 6          // alias for not equalTo
value must be_=== 5         // typed equality (same type required)

// Ordering
value must be greaterThan(0)
value must be lessThan(100)
value must be >= 5
value must be <= 10
value must be between(3, 7)          // exclusive bounds
value must be betweenInclusive(4, 6)  // inclusive bounds

// Numeric proximity
value must be closeTo(5.0, 0.01)      // within delta
```

## Boolean Matchers

```scala
true must beTrue
false must beFalse
```

## String Matchers

```scala
"hello" must have length 5
"hello" must haveLength(5)             // alternative syntax
"hello" must startWith("he")
"hello" must endWith("lo")
"hello" must contain("ell")
"hello" must containPattern(".*ll.*")
"hello" must be like "h.*o"            // regex match
"hello" must not be like "x.*"
"hello" must not contain "world"
"hello" must match { case s => s.startsWith("h") }
"hello" must not match { case s => s.isEmpty }
"hello" must beEmpty                   // empty string check
```

## Collection Matchers

```scala
// Size and emptiness
List(1, 2, 3) must have size 3
List(1, 2, 3) must beEmpty
List(1, 2, 3) must not beEmpty

// Containment
List(1, 2, 3) must contain(2)
List(1, 2, 3) must not contain 4
List(1, 2, 3) must containElements(1, 2, 3)
List(1, 2, 3) must containAllOf(List(1, 2))
List(1, 2, 3) must containOnly(1, 2, 3)
List(1, 2, 3) must containNoneOf(4, 5)

// Ordering
List(1, 2, 3) must beSorted

// Quantifiers — apply a matcher to each element
List(1, 2, 3) must all be > 0          // every element > 0
List(1, 2, 3) must all be < 10
List(1, 2, 3) must any be > 5          // at least one element > 5
```

## Option Matchers

```scala
Some(5) must beSome
Some(5) must beSome(5)                 // Some containing 5
Some(5) must beSomeValue(5)            // same as beSome(5)
Some(5) must beDefined                 // alias for beSome
None    must beNone
None    must not beDefined
```

## Either / Result Matchers

```scala
Right(5)   must beRight
Right(5)   must beRight(5)
Left("err") must beLeft
Left("err") must beLeft("err")

// scala.util.Try
Success(5)          must beSuccessful
Failure("error")    must beFailed

// Pattern matching on disjunctions
decode[User](json) must beLike {
  case Right(user) => user must be equalTo User(1, "Alice", "a@b.com")
}
decode[User](bad) must beLike {
  case Left(err) => err must not beNull
}
```

## Type and Null Matchers

```scala
"hello" must beAnInstanceOf[String]
5       must beAnInstanceOf[Int]
Some(5) must beAnInstanceOf[Option[_]]

null  must beNull
value must not beNull
```

## PartialFunction Matchers

```scala
val pf: PartialFunction[Int, String] = { case x if x > 0 => "positive" }

pf must beDefinedAt(1)
pf must not beDefinedAt(-1)
```

## Matcher Composition

```scala
// Conjunction — both must pass
result must be greaterThan(0) and be lessThan(10)

// Disjunction — either must pass
result must be lessThan(0) or be greaterThan(10)

// Negation
result must not be equalTo(42)

// Chaining
result must be greaterThan(0) and be lessThan(100) and not be equalTo(50)
```

## Custom Matchers

### Basic Custom Matcher

```scala
import org.specs2.matcher.Matcher
import org.specs2.matcher.MatchResult

def beWithin(low: Int, high: Int): Matcher[Int] = new Matcher[Int] {
  def apply(value: Int): MatchResult =
    MatchResult(
      value >= low && value <= high,
      s"$value is not between $low and $high",
      s"$value is between $low and $high"
    )
}

// Usage
val score = 85
score must beWithin(0, 100)
```

### Implicit-Based Custom Matcher

```scala
def beNonEmpty[A](implicit ev: A => IterableOnce[_]): Matcher[A] = new Matcher[A] {
  def apply(value: A): MatchResult = {
    val isEmpty = value match {
      case seq: IterableOnce[_] => seq.iterator.isEmpty
      case str: CharSequence    => str.isEmpty
      case null                 => true
    }
    MatchResult(!isEmpty, s"$value is empty", s"$value is not empty")
  }
}

List(1, 2, 3) must beNonEmpty
Set()         must not beNonEmpty
```

### Transformation Matcher

```scala
def beLower: Matcher[String] = new Matcher[String] {
  def apply(value: String): MatchResult =
    MatchResult(
      value == value.toLowerCase,
      s"$value is not lowercase",
      s"$value is lowercase"
    )
}

"hello" must beLower
"HELLO" must not beLower
```

### Side-Effect Verifying Matcher

```scala
def verifySideEffect[A](f: A => Unit): Matcher[A] = new Matcher[A] {
  def apply(value: A): MatchResult =
    try {
      f(value)
      MatchResult(true, s"Side effect verification failed for $value")
    } catch {
      case _: Exception => MatchResult(false, "Side effect raised exception")
    }
}

var count = 0
5 must verifySideEffect((n: Int) => { count += n })
count must be equalTo 5
```

## Pattern Matching Matchers

```scala
// beLike — structural matching on results
result must beLike {
  case Right(user) => user.name must be equalTo "Alice"
  case Left(err)   => err must contain("not found")
}

// beMatching — regex pattern on strings
"hello@example.com" must beMatching(".*@.*")

// Custom pattern matcher
def beCaseOf[A, B](pf: PartialFunction[A, B]): Matcher[A] = new Matcher[A] {
  def apply(value: A): MatchResult =
    MatchResult(
      pf.isDefinedAt(value),
      s"$value not handled by pattern",
      s"$value handled by pattern"
    )
}

val pf: PartialFunction[String, Int] = { case s => s.length }
"hello" must beCaseOf(pf)
```

## Form Validation Matchers

```scala
case class User(name: String, email: String, age: Int)

// Validate individual fields
user.name  must not beEmpty
user.email must beMatching(".*@.*")
user.age   must be greaterThan(0)

// Validate with beLike for structured results
validateUser(user) must beLike {
  case Right(u) =>
    u.name  must be equalTo "Alice"
    u.email must contain("@")
  case Left(errors) =>
    errors must contain("email")
}
```

## JSON Matchers

```scala
import io.circe.parser._

// Parse and pattern match
val json = """{"id":1,"name":"Alice"}"""
decode[User](json) must beLike {
  case Right(user) => user.id must be equalTo 1
}

// Structural JSON checks with circe
val parsed = parse(json)
parsed must beRight
parsed.toOption.get.noSpaces must contain("Alice")

// Invalid JSON handling
val badJson = """{invalid}"""
parse(badJson) must beLeft
```

## Performance Tips

```scala
// Prefer composed matchers over multiple assertions
value must be greaterThan(0) and be lessThan(10)
// over:
// value must be greaterThan(0)
// value must be lessThan(10)

// Use specific type matchers over generic ones
5       must beAnInstanceOf[Int]   // good
5       must beAnInstanceOf[Any]   // too loose
```

## Given-When-Then Syntax

specs2 provides a `GivenWhenThen` trait for structuring tests in a readable
narrative style. This is especially useful for acceptance-style or
documentation-heavy specs.

### Basic GWT Example

```scala
import org.specs2.mutable.Specification
import org.specs2.specification.core.{Given, When, Then}
import org.specs2.specification.dsl.GWT

case class RegistrationForm(name: String, email: String, password: String)
case class User(id: Long, name: String, email: String)

class UserService {
  def register(form: RegistrationForm): Either[String, User] =
    if (form.email.contains("@")) Right(User(1, form.name, form.email))
    else Left("invalid email")
}

class UserFeatureSpec extends Specification with GWT {
  val userService = new UserService

  "User registration" should {
    "create a new user account" in {
      given("a valid registration form")
      val form = RegistrationForm("Alice", "alice@example.com", "password123")

      when("the user submits the form")
      val result = userService.register(form)

      then("the user should be created")
      result must beRight
    }

    "reject an invalid email" in {
      given("a registration form with bad email")
      val form = RegistrationForm("Bob", "not-an-email", "pass")

      when("the user submits the form")
      val result = userService.register(form)

      then("registration should fail")
      result must beLeft("invalid email")
    }
  }
}
```

### Organizing GWT Specs

Group related scenarios under a shared description for clarity:

```scala
class OrderFeatureSpec extends Specification with GWT {
  "Order processing" should {
    "apply discount for premium users" in {
      given("a premium user and an order over $100")
      val user  = User(1, "Alice", premium = true)
      val order = Order(items = List(Item("Widget", 120)))

      when("the order is processed")
      val total = OrderService.process(user, order)

      then("a 10%% discount is applied")
      total must be equalTo 108.0
    }

    "not apply discount for regular users" in {
      given("a regular user and an order over $100")
      val user  = User(2, "Bob", premium = false)
      val order = Order(items = List(Item("Widget", 120)))

      when("the order is processed")
      val total = OrderService.process(user, order)

      then("no discount is applied")
      total must be equalTo 120.0
    }
  }
}
```

### Sharing Fixtures in GWT

Extract common setup into helper methods or traits to keep scenarios focused:

```scala
trait UserFixtures {
  def validForm   = RegistrationForm("Alice", "alice@example.com", "password123")
  def invalidForm = RegistrationForm("Bob", "no-email", "pass")
}

class SharedFixtureSpec extends Specification with GWT with UserFixtures {
  val userService = new UserService

  "Registration" should {
    "succeed with valid data" in {
      given("a valid form")
      val form = validForm

      when("submitted")
      val result = userService.register(form)

      then("user is created")
      result must beRight
    }
  }
}
```

### Combining GWT with Matchers

GWT steps can contain full matcher expressions, not just simple assertions:

```scala
then("the response has correct structure")
result must beLike {
  case Right(user) =>
    user.name  must be equalTo "Alice"
    user.email must contain("@")
    user.id    must be greaterThan(0)
}
```

## Specification Scopes (Before / After / Around)

specs2 provides lifecycle traits for setup and teardown logic that runs around
each example.

### Before — Run Code Before Each Example

```scala
import org.specs2.mutable.Specification
import org.specs2.specification.Before

class DatabaseSpec extends Specification with Before {
  // Called before every example
  def before: Unit = {
    Database.initialize()
    Database.cleanAllTables()
  }

  "Database" should {
    "insert a record" in {
      Database.insert(User(1, "Alice"))
      Database.count must be equalTo 1
    }

    "find by id" in {
      Database.insert(User(1, "Bob"))
      Database.findById(1).map(_.name) must beSome("Bob")
    }
  }
}
```

### After — Run Code After Each Example

```scala
import org.specs2.specification.After

class TempFileSpec extends Specification with After {
  def after: Unit = {
    TempDir.cleanup()
  }

  "File operations" should {
    "write and read" in {
      TempDir.write("test.txt", "hello")
      TempDir.read("test.txt") must be equalTo "hello"
    }
  }
}
```

### Around — Wrap Examples with Setup/Teardown

```scala
import org.specs2.specification.Around
import org.specs2.execute.{Result, AsResult}

class TransactionalSpec extends Specification with Around {
  // Wrap each example in a transaction, roll back afterwards
  def around[T: AsResult](t: => T): Result = {
    val tx = Database.beginTransaction()
    try AsResult(t)
    finally tx.rollback()
  }

  "Transactional operations" should {
    "not persist data after rollback" in {
      Database.insert(User(1, "Temp"))
      Database.count must be equalTo 1 // visible inside the transaction
    }
  }
}
```

### ForEach[T] — Fresh Fixture Per Example

```scala
import org.specs2.specification.ForEach

case class TestContext(tempDir: Path, config: Config)

class ForEachSpec extends Specification with ForEach[TestContext] {
  // Provide a fresh fixture for each example
  def foreach[R: AsResult](f: TestContext => R): Result = {
    val ctx = TestContext(Files.createTempDirectory("test"), Config.test)
    try AsResult(f(ctx))
    finally Files.deleteIfExists(ctx.tempDir)
  }

  "With per-test fixture" should {
    "get a clean temp directory" in { ctx: TestContext =>
      Files.list(ctx.tempDir).count() must be equalTo 0
    }

    "write to isolated directory" in { ctx: TestContext =>
      Files.writeString(ctx.tempDir.resolve("out.txt"), "data")
      Files.readString(ctx.tempDir.resolve("out.txt")) must be equalTo "data"
    }
  }
}
```

### Scope — Mutable Fixture Sharing

```scala
import org.specs2.specification.Scope

class SharedStateSpec extends Specification {
  // Scope provides a mutable fixture shared within a single example group
  "With Scope" should {
    "use shared setup" in new WithUsers {
      // `users` is available here
      users must have size 3
      users.head.name must be equalTo "Alice"
    }
  }

  trait WithUsers extends Scope {
    val users = List(
      User(1, "Alice", "alice@test.com"),
      User(2, "Bob",   "bob@test.com"),
      User(3, "Carol", "carol@test.com")
    )
  }
}
```

### BeforeAll / AfterAll — Class-Level Setup

```scala
import org.specs2.specification.{BeforeAll, AfterAll}

class ExpensiveSetupSpec extends Specification with BeforeAll with AfterAll {
  def beforeAll(): Unit = {
    // Run once before all examples — start external services, etc.
    ExternalService.start()
  }

  def afterAll(): Unit = {
    // Run once after all examples
    ExternalService.stop()
  }

  "External service integration" should {
    "respond to ping" in {
      ExternalService.ping() must be equalTo "pong"
    }
  }
}
```

### Combining Lifecycle Traits

```scala
class CombinedLifecycleSpec extends Specification
  with BeforeAll with AfterAll with Around {

  def beforeAll(): Unit = Server.start()
  def afterAll(): Unit  = Server.stop()

  def around[T: AsResult](t: => T): Result = {
    val session = Server.newSession()
    try AsResult(t)
    finally session.close()
  }

  "Full lifecycle" should {
    "work with server and session" in {
      Server.healthCheck() must beTrue
    }
  }
}
```

## Mutable vs Immutable Specification

specs2 offers two styles of specification: **mutable** (imperative) and
**immutable** (functional). Choose based on your team's preference and test
complexity.

### Mutable Specification (Recommended for Most Cases)

```scala
import org.specs2.mutable.Specification

class MutableCalcSpec extends Specification {
  "Calculator" should {
    "add" in {
      1 + 1 must be equalTo 2
    }
    "subtract" in {
      5 - 3 must be equalTo 2
    }
  }
}
```

Characteristics:
- **Imperative style** — examples are defined as side effects in the constructor.
- **Easy to read** — familiar `should / in` block structure.
- **Mixes in traits easily** — `Before`, `Scope`, `Tables`, etc.
- **Use for**: unit tests, integration tests, most everyday specs.

### Immutable Specification (SpecificationStructure)

```scala
import org.specs2.Specification
import org.specs2.specification.core.{Fragment, Fragments}

class ImmutableCalcSpec extends Specification { def is = s2"""

  Calculator should
    add two numbers          $add
    subtract two numbers     $subtract

"""
  def add: Result =
    1 + 1 must be equalTo 2

  def subtract: Result =
    5 - 3 must be equalTo 2
}
```

Characteristics:
- **Functional style** — `is` returns an immutable `Fragments` tree.
- **Composable** — fragments can be assembled programmatically.
- **Referentially transparent** — no side effects in construction.
- **Use for**: generated test suites, acceptance specs, documentation-oriented specs.

### When to Choose Which

| Concern | Mutable | Immutable |
|---|---|---|
| Quick unit tests | ✅ Best | Works |
| Acceptance / documentation specs | Works | ✅ Best |
| Generated test suites | Hard | ✅ Natural |
| Learning curve | ✅ Lower | Higher |
| Composability | Limited | ✅ Full |

### Programmatic Fragment Assembly (Immutable)

```scala
class GeneratedSpec extends Specification { def is =

  // Programmatically build fragments
  Fragments.foreach(1 to 5) { i =>
    s"test case $i" ! {
      i must be greaterThan(0)
    }
  }
}
```

## Step Definitions and Acceptance Specs

For larger acceptance-style tests, specs2 supports organizing steps into
reusable definitions with clear narrative flow.

### Structured Acceptance Spec

```scala
import org.specs2.Specification
import org.specs2.specification.dsl.{GWT, BlockExample}

class CheckoutAcceptanceSpec extends Specification with GWT { def is = s2"""

  Checkout flow
    given a customer with items in cart     $checkoutHappy
    when the customer proceeds to payment   ${step(proceedToPayment)}
    then the order is confirmed             $verifyOrder

"""
  val cart     = mutable.ListBuffer[Item]()
  var orderId  = Option.empty[Long]

  def checkoutHappy: Result = {
    cart += Item("Book", 29.99)
    cart += Item("Pen", 3.50)
    cart must have size 2
  }

  def proceedToPayment: Unit = {
    orderId = Some(CheckoutService.pay(cart.toList))
  }

  def verifyOrder: Result = {
    orderId must beSome
    orderId.map(CheckoutService.status) must beSome("confirmed")
  }
}
```

### Shared Contexts

```scala
// Define reusable step groups in a trait
trait UserSteps extends Scope {
  val userRepo  = new InMemoryUserRepo
  val service   = new UserService(userRepo)

  def givenRegistered(name: String, email: String): User =
    service.register(RegistrationForm(name, email, "pass")) match {
      case Right(u) => u
      case Left(e)  => throw new RuntimeException(s"Registration failed: $e")
    }
}

class SharedContextSpec extends Specification {
  "User steps" should {
    "find registered user" in new UserSteps {
      val user = givenRegistered("Alice", "alice@test.com")
      service.findById(user.id) must beSome
    }
  }
}
```

## Tags and Selection

Use tags to group tests and run subsets selectively in sbt.

### Tagging Examples

```scala
import org.specs2.mutable.Specification
import org.specs2.specification.core.Tag

class TaggedSpec extends Specification {
  "Tagged examples" should {
    "fast unit test" in {
      1 must be equalTo 1
    }.tag("unit", "fast")

    "slow integration test" in {
      ExternalService.call() must beRight
    }.tag("integration", "slow")

    "database test" in {
      Database.query("SELECT 1") must be equalTo 1
    }.tag("integration", "database")
  }
}
```

### Running Tagged Subsets

```sbt
# Run only tests tagged "unit"
sbt "testOnly *TaggedSpec -- include unit"

# Run multiple tags
sbt "testOnly *TaggedSpec -- include unit,fast"

# Exclude slow tests
sbt "testOnly *TaggedSpec -- exclude slow"

# Combine include and exclude
sbt "testOnly *TaggedSpec -- include integration -- exclude database"
```

### Tagging Sections

Tag an entire group at once:

```scala
class SectionTaggedSpec extends Specification {
  "API tests" should {
    "list users" in { /* ... */ }
    "create user" in { /* ... */ }
    "delete user" in { /* ... */ }
  }.section("api")

  "Unit tests" should {
    "parse input" in { /* ... */ }
    "validate data" in { /* ... */ }
  }.section("unit")
}
```

### Using Arguments for Tag Selection

```scala
// Set default arguments in the spec itself
class ArgSpec extends Specification {
  // Only run "fast" tests by default
  override def arguments = super.arguments.include("fast")

  "fast test" in { ok }.tag("fast")
  "slow test" in { ok }.tag("slow")
}
```

## Pending and Skipped Examples

specs2 provides several ways to mark tests as not yet implemented or temporarily
disabled.

### pendingUntilFixed

Automatically passes a test once it starts succeeding — useful for tracking
known bugs that should be fixed:

```scala
class PendingSpec extends Specification {
  "Known issues" should {
    "be tracked until fixed" in {
      // Passes now because the assertion fails.
      // Once the bug is fixed, this will still pass (not flip to failure).
      BugTracker.status(42) must be equalTo "fixed"
    }.pendingUntilFixed

    "with a custom message" in {
      BugTracker.status(99) must be equalTo "resolved"
    }.pendingUntilFixed("Waiting for PR #1234")
  }
}
```

### Skipped Examples

```scala
class SkippedSpec extends Specification {
  "Skipped tests" should {
    "be explicitly skipped" in {
      skipped("Not implemented yet")
    }

    "skip conditionally" in {
      if (!ExternalService.isAvailable)
        skipped("External service not available")
      else
        ExternalService.ping() must be equalTo "pong"
    }

    "skip with a block" in {
      skipAllIf(!Config.integrationTestsEnabled) {
        Database.connect()
        Database.query("SELECT 1") must not beNull
      }
    }
  }
}
```

### Todo Trait

The `Todo` trait marks entire sections as pending:

```scala
import org.specs2.specification.dslmutable_TODO

class TodoSpec extends Specification {
  "Implemented features" should {
    "work correctly" in {
      true must beTrue
    }
  }

  "Planned features" should {
    "eventually sort items" in {
      todo // Always reports as pending
    }

    "eventually filter results" in {
      todo
    }
  }
}
```

### Summary of Pending/Skipped States

| State | Outcome | Use Case |
|---|---|---|
| `todo` | Pending (yellow) | Unimplemented feature |
| `skipped("reason")` | Skipped (yellow) | External dependency unavailable |
| `pendingUntilFixed` | Passes if assertion fails | Tracking known bugs |
| `skipAllIf(cond) { }` | Skipped if condition met | Conditional integration tests |

## Timeout and Duration Control

Control how long individual examples or entire specs are allowed to run.

### Per-Example Timeout

```scala
import org.specs2.concurrent.ExecutionEnv
import scala.concurrent.duration._

class TimeoutSpec extends Specification {
  // Set a default timeout for all examples in this spec
  override def defaultTimeout: FiniteDuration = 5.seconds

  "Timed examples" should {
    "complete within timeout" in {
      Thread.sleep(100)
      true must beTrue
    }

    "custom timeout per example" in {
      // Override the default timeout for this specific example
      Thread.sleep(200)
      true must beTrue
    }.timeout(1.second) // 1-second timeout instead of the 5-second default

    "eventually satisfy condition" in {
      // Retry until condition holds or timeout
      eventually(5, 100.millis) {
        Cache.get("key") must beSome("value")
      }
    }
  }
}
```

### Global Timeout via Arguments

```sbt
# Set a global 30-second timeout
sbt "testOnly *MySpec -- timeout 30s"
```

Or set it programmatically in the spec:

```scala
class GlobalTimeoutSpec extends Specification {
  override def arguments = super.arguments.timeout(10.seconds)

  "All examples" should {
    "inherit the global timeout" in {
      true must beTrue
    }
  }
}
```

### Eventually, Retry, and Await Patterns

```scala
import org.specs2.matcher.EventuallyMatchers

class RetrySpec extends Specification with EventuallyMatchers {
  "Retry patterns" should {
    "eventually succeed" in eventually {
      // Retries with increasing delays until the assertion holds
      AsyncQueue.size must be greaterThan(0)
    }

    "await a Future" in {
      import scala.concurrent.Future
      import scala.concurrent.ExecutionContext.Implicits.global

      val f = Future { Thread.sleep(50); 42 }
      await(f) must be equalTo 42
    }

    "await with custom timeout" in {
      val f = Future { Thread.sleep(200); "done" }
      await(f, timeout = 1.second) must be equalTo "done"
    }
  }
}
```

### Time-Matchers for Duration Assertions

```scala
import org.specs2.time.TimeConversions._

class DurationSpec extends Specification {
  "Duration assertions" should {
    "measure execution time" in {
      val elapsed = measure {
        Thread.sleep(50)
        "result"
      }
      elapsed.duration must be_<=(200.millis)
    }
  }
}
```
