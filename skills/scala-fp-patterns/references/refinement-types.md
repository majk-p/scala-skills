# Refinement Types Reference

Complete reference for newtypes, refinement types, and compile-time validation.

## Custom Validation Predicates

```scala
import eu.timepit.refined.api.Validate

case class Email()

implicit val emailValidate: Validate.Plain[String, Email] =
  Validate.fromPartial(
    s => Email(s),
    s => s.matches("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"),
    Predicate("Must be a valid email address")
  )

type ValidEmail = String Refined Email
```

## RefinedTypeOps

```scala
import eu.timepit.refined.api.RefinedTypeOps

object Username {
  type Username = String Refined NonEmpty
  implicit class UsernameOps(val u: Username) extends AnyVal {
    def value: String = u.value
  }
  def from(s: String): Either[String, Username] = refineV[NonEmpty](s)
  def unsafeFrom(s: String): Username = refineV[NonEmpty](s) match {
    case Right(v) => v
    case Left(err) => throw new IllegalArgumentException(err)
  }
}
```

## Higher-Kinded Refinements

```scala
import eu.timepit.refined.collection._

type NonEmptyMap[K, V] = Map[K, V] Refined NonEmpty
type NonEmptyList[T] = List[T] Refined NonEmpty
```

## Newtype Ops

```scala
import io.estatico.newtype.macros._
import io.estatico.newtype.ops._

@newtype case class Username(value: String)

// Access underlying value
val name = Username("alice")
val raw: String = name.value

// Implicit ops for domain methods
implicit class UsernameOps(u: Username) {
  def lowercase: Username = Username(u.value.toLowerCase)
  def trimmed: Username = Username(u.value.trim)
}
```

## Smart Constructors

```scala
@newtype case class UserId(value: Long)

object UserId {
  def from(s: String): Either[String, UserId] =
    refineV[NonEmpty](s).map(u => UserId(u.value.toLong))

  def unsafeFrom(s: String): UserId =
    from(s).fold(err => throw new IllegalArgumentException(err), identity)
}

@newtype case class Amount(value: BigDecimal)

object Amount {
  def from(d: BigDecimal): Either[String, Amount] =
    if (d >= 0) Right(Amount(d))
    else Left("Amount must be non-negative")
}
```

## Combining Newtypes with Refinements

```scala
@newtype case class Email private (value: String)

object Email {
  type EmailR = String Refined MatchesRegex["^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"]

  def from(s: String): Either[String, Email] =
    refineV[MatchesRegex["^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"]](s)
      .map(v => Email(v.value))
}
```

## Runtime vs Compile-time Validation

```scala
// Runtime validation — errors surface at runtime
def validateAge(age: Int): Either[String, Int] =
  if (age > 0) Right(age) else Left("Age must be positive")

// Compile-time validation — errors caught during compilation
type PositiveAge = Int Refined Greater[0]

val valid: PositiveAge = 25   // OK
// val invalid: PositiveAge = -5  // COMPILATION ERROR
```

## Common Imports

```scala
// Newtypes
import io.estatico.newtype.macros._
import io.estatico.newtype.ops._

// Refined
import eu.timepit.refined.api.Refined
import eu.timepit.refined.api.RefinedTypeOps
import eu.timepit.refined.auto._
import eu.timepit.refined.collection._
import eu.timepit.refined.numeric._
import eu.timepit.refined.string._
import eu.timepit.refined.boolean._

// Cats integration
import eu.timepit.refined.cats._
```
