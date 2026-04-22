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
