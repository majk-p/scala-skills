# Weaver Expectations API Reference

## Type: Expectations

`Expectations` is a pure value representing one or more assertion results.
It is not throw-based — it composes via standard combinators.

```scala
sealed trait Expectations
object Expectations {
  case class Success(loc: SourceLocation) extends Expectations
  case class Failure(details: String, loc: SourceLocation) extends Expectations
  case class Multiple(expectations: List[Expectations]) extends Expectations
}
```

## Core Assertions

### expect — boolean assertion

```scala
def expect(condition: Boolean)(implicit loc: SourceLocation): Expectations
```

Captures source location automatically. Fails with `"assertion failed"` if
condition is false.

```scala
test("basic") {
  IO.pure(expect(1 + 1 == 2))
}
```

### expect.eql — structural equality with diff

```scala
def expect.eql[A](expected: A, actual: A)(implicit loc: SourceLocation, show: Show[A] = ...): Expectations
```

Shows a diff between expected and actual on failure. Uses `Show` for
human-readable output when available.

```scala
test("list equality") {
  IO.pure(expect.eql(List(1, 2, 3), (1 to 3).toList))
}
```

### expect.same — reference equality

```scala
def expect.same[A](expected: A, actual: A)(implicit loc: SourceLocation): Expectations
```

Uses `eq` (reference equality). Prefer `expect.eql` for value comparisons.

## Composition Operators

### and — conjunction (both must pass)

```scala
val result: Expectations = expect(a > 0) and expect(a < 100)
```

Collects all failures — does not short-circuit. Use `.failFast` for
short-circuiting behavior.

### or — disjunction (at least one must pass)

```scala
val result: Expectations = expect(x == 0) or expect(x == 1)
```

Reports failure only if both sides fail.

### xor — exclusive or (exactly one must pass)

```scala
val result: Expectations = expect(flag1) xor expect(flag2)
```

Fails if both pass or both fail.

### expect.all — variadic conjunction

```scala
val result: Expectations = expect.all(
  expect(name.nonEmpty),
  expect(age > 0),
  expect(score >= 0.0)
)
```

Same as chaining `and`, but more readable for multiple assertions.

### not — negation

```scala
val result: Expectations = not(expect(list.isEmpty))
```

## Collection Assertions

### forEach — every element must satisfy

```scala
def forEach[A](collection: Iterable[A])(f: A => Expectations): Expectations
```

```scala
forEach(Seq(2, 4, 6, 8)) { n =>
  expect(n % 2 == 0).clue(s"$n is not even")
}
```

Reports per-element failures with indices.

### exists — at least one element must satisfy

```scala
def exists[A](collection: Iterable[A])(f: A => Expectations): Expectations
```

```scala
exists(List("apple", "banana", "cherry")) { fruit =>
  expect(fruit.startsWith("b"))
}
```

## Pattern Matching Assertions

### matches — destructure and assert

```scala
def matches[A, B](value: A)(pf: PartialFunction[A, Expectations]): Expectations
```

Fails if the value does not match the pattern or if the inner expectation fails.

```scala
matches(fetchResult(id)) {
  case Right(user) => expect(user.name.nonEmpty)
}
// If Left(err) => fails with "no match"
// If Right(user) with empty name => fails with inner assertion
```

### whenSuccess — unwrap Success from Either/Validated/Try

```scala
def whenSuccess[A](value: Either[?, A])(f: A => Expectations): Expectations
def whenSuccess[A](value: Validated[?, A])(f: A => Expectations): Expectations
def whenSuccess[A](value: Try[A])(f: A => Expectations): Expectations
```

```scala
whenSuccess(parseConfig(raw)) { config =>
  expect(config.timeout > 0) and expect(config.host.nonEmpty)
}
```

## Fail-Fast

### .failFast — short-circuit on failure

```scala
val result: Expectations = expect(step1Ok).failFast and
  expect(step2Ok).failFast and
  expect(step3Ok).failFast
```

When `.failFast` is applied, if the expectation fails, subsequent expectations
are **not evaluated**. Without `.failFast`, all expectations run and all
failures are collected.

Use `.failFast` when later assertions would be meaningless after an earlier
failure (e.g., parsing failed before validation).

## Clue System

### .clue — attach diagnostic context

```scala
def clue(context: String): Expectations
```

Appends context string to the failure message. Lazy — only evaluated on
failure.

```scala
users.zipWithIndex.foreach { case (user, idx) =>
  expect(user.age > 0)
    .clue(s"User #$idx (id=${user.id}) had invalid age: ${user.age}")
}
```

### Clue with computed values

```scala
val result = expect(response.status == 200)
  .clue(s"status=${response.status}, body=${response.body.take(200)}")
```

Multiple `.clue` calls stack:

```scala
expect(value > 0)
  .clue(s"value=$value")
  .clue(s"context=$ctx")
```

## Constants

```scala
val success: Expectations  // Always passes
val failure: Expectations  // Always fails with "failure"
```

Useful for conditional test logic:

```scala
test("platform-specific") {
  if (Platform.isJVM) {
    // JVM assertions
    expect(jvmSpecific())
  } else success
}
```

## Custom Expectations

### From Either

```scala
def fromEither[A](either: Either[String, A])(f: A => Expectations): Expectations
```

```scala
fromEither(parseJson(raw)) { json =>
  expect(json.hcursor.get[Int]("age").isRight)
}
```

### From Validated

```scala
def fromValidated[A](v: Validated[String, A])(f: A => Expectations): Expectations
```

### From Try

```scala
def fromTry[A](t: Try[A])(f: A => Expectations): Expectations
```

## Asserting Exceptions

### assertFailure — expect an effect to fail

```scala
test("division by zero throws") {
  IO.delay(1 / 0).attempt.map {
    case Left(_: ArithmeticException) => success
    case Left(e)  => failure.clue(s"Wrong exception: ${e.getClass}")
    case Right(_) => failure.clue("Expected exception but succeeded")
  }
}
```

There is no built-in `intercept` — use `IO.attempt` and pattern match.

## Source Location

All assertions capture `SourceLocation` implicitly. This provides file name
and line number in failure output automatically — no manual annotation needed.

```scala
// Automatic: assertion at line 42 of MySuite.scala
// Failure output: "MySuite.scala:42: assertion failed"
```

## Debugging Tips

1. Use `.clue()` liberally — it only renders on failure, zero cost on success
2. Use `.failFast` when later checks depend on earlier ones
3. Use `forEach` instead of loops — reports per-element index
4. Use `loggedTest` for trace-level debugging — logs appear only on failure
5. Use `expect.eql` over `expect(a == b)` — shows diff on mismatch
