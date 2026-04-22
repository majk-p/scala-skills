---
name: scala-validation
description: Use this skill when working with type-safe validation in Scala using the Iron library. Covers basic constraints (numeric, string, collection), custom constraint type classes, Cats/ZIO integration, form validation, cross-field validation, JSON serialization with Circe, runtime refinement, and error accumulation. Trigger when the user mentions Iron, refined types, compile-time validation, runtime validation, type-safe constraints, or needs to prevent invalid values through static typing.
---

# Type-Safe Validation with Iron in Scala

Iron is a Scala 3 library that enforces type constraints at compile-time and runtime through refined types. Use `A :| Constraint` syntax to add constraints to any type. Literal values are validated at compile time; runtime values use explicit refinement methods.

## Quick Start

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.numeric.*

// Compile-time validation
type PositiveDouble = Double :| Positive
def log(value: PositiveDouble): Double = Math.log(value)
log(-1.0) // Compile-time error

// Runtime validation
val input: Double = Math.random()
val positive: PositiveDouble = input.refineUnsafe  // throws if invalid
```

## Core Concepts

### Refined Types

The `A :| C` syntax creates a type `A` constrained by `C`. The Iron runtime wraps values and checks constraints.

```scala
type Age = Int :| Greater[18]
type Temperature = Double :| Greater[0.0]
type Percentage = Double :| Less[1.0]
```

### Runtime Refinement Methods

```scala
// refineUnsafe — throws IllegalArgumentException
val v1: Double :| Positive = input.refineUnsafe

// refineEither — returns Either[String, Refined]
input.refineEither[Positive] match {
  case Right(valid) => useValue(valid)
  case Left(error)  => logError(error)
}

// refineOption — returns Option[Refined]
input.refineOption[Positive].foreach(useValue)

// refineNel — returns EitherNel[String, Refined] (cats)
val validated: EitherNel[String, Int :| Greater[0]] = input.refineNel[Greater[0]]

// refineZIO — returns ZIO[Any, String, Refined] (zio)
val result: ZIO[Any, String, Int :| Greater[0]] = input.refineZIO[Greater[0]]
```

### Built-in Constraints

#### Numeric

```scala
import io.github.iltotore.iron.constraint.numeric.*

type PositiveInt    = Int :| Positive
type NegativeDouble = Double :| Negative
type Age            = Int :| Greater[18]
type Discount       = Double :| Less[1.0]
type Score          = Int :| Interval[0, 100]    // inclusive
type Percentage     = Double :| Range[0.0, 100.0] // exclusive
```

#### String

```scala
import io.github.iltotore.iron.constraint.string.*

type HasAt       = String :| Contain["@"]
type Prefix      = String :| StartWith["prefix-"]
type Tld         = String :| EndWith[".com"]
type ShortName   = String :| Length[2, 10]
type PostalCode  = String :| Pattern["^[0-9]{5}$"]
```

#### Collection

```scala
import io.github.iltotore.iron.constraint.collection.*

type NonEmptyList    = List[Int] :| NonEmpty
type ExactlyFive     = List[String] :| Size[5]
type UniqueStrings   = List[String] :| Unique
```

### Constraint Composition

```scala
// Intersection (and) with &
type ValidAge = Int :| (Greater[18] & Less[120])
type ValidPassword = String :| (Length[8, 100] & Contain["!"])

// Union (or) with |
type NonZero = Double :| (Positive | Negative)

// Implication with ==>
type AdultAge = Int :| (Greater[18] ==> Less[120])
```

## Custom Constraints

Define constraints as type classes with `given` instances:

```scala
import io.github.iltotore.iron.*

final class NotBlank
object NotBlank:
  given Constraint[String, NotBlank] with
    def message = "String should not be blank"
    def test(value: String): Boolean = value.nonEmpty

type NonBlankString = String :| NotBlank
```

For compile-time constraints, use inline:

```scala
final class Uppercase
object Uppercase:
  inline def message: String = "Must be uppercase"
  inline def test(value: String): Boolean = value == value.toUpperCase

type UpperString = String :| Uppercase
```

Common custom constraints:

```scala
// Email validation
final class ValidEmail
object EmailConstraints:
  given Constraint[String, ValidEmail] with
    def message = "Must be a valid email address"
    def test(value: String): Boolean =
      value.matches("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$")
type Email = String :| ValidEmail

// Date format
final class ValidDate
object DateConstraints:
  given Constraint[String, ValidDate] with
    def message = "Date must be in YYYY-MM-DD format"
    def test(value: String): Boolean = value.matches("\\d{4}-\\d{2}-\\d{2}")

// Divisibility
final class DivisibleBy[V]
object NumericConstraints:
  given Constraint[Int, DivisibleBy[3]] with
    def message = "Number must be divisible by 3"
    def test(value: Int): Boolean = value % 3 == 0
```

## Cats Effect Integration

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.cats.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import cats.data.EitherNel
import cats.syntax.all.*
import cats.effect.IO

case class User(name: String :| Contain["a"], age: Int :| Greater[0])

def validateUser(name: String, age: Int): EitherNel[String, User] =
  (
    name.refineNel[Contain["a"]],
    age.refineNel[Greater[0]]
  ).parMapN(User.apply)

// With IO
def program(name: String, age: Int): IO[User] =
  validateUser(name, age).fold(
    errors => IO.raiseError(new Exception(errors.show)),
    IO.pure
  )
```

## ZIO Integration

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.zio.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import zio.*

case class User(name: String :| Contain["a"], age: Int :| Greater[0])

def validateUser(name: String, age: Int): Task[User] =
  (
    name.refineZIO[Contain["a"]],
    age.refineZIO[Greater[0]]
  ).mapN(User.apply)

// With error context
def validateWithErrors(name: String, age: Int): ZIO[Any, String, User] =
  (
    name.refineZIO[Contain["a"]],
    name.refineZIO[Length[3, 20]],
    age.refineZIO[Greater[18]],
    age.refineZIO[Less[120]]
  ).mapN(User.apply)
```

## Form Validation

### Multi-field Validation with Error Accumulation

```scala
case class RegistrationForm(
  username: String :| (Contain["a"] & Length[3, 20]),
  email: String :| (Contain["@"] & Length[5, 100]),
  age: Int :| (Greater[18] ==> Less[120]),
  password: String :| Length[8, 100]
)

def validateRegistration(
  username: String, email: String, age: Int, password: String
): EitherNel[String, RegistrationForm] =
  (
    username.refineNel[Contain["a"]],
    username.refineNel[Length[3, 20]],
    email.refineNel[Contain["@"]],
    email.refineNel[Length[5, 100]],
    age.refineNel[Greater[18]],
    age.refineNel[Less[120]],
    password.refineNel[Length[8, 100]]
  ).parMapN(RegistrationForm.apply)
```

### Cross-field Validation

```scala
case class PasswordForm(password: String :| Length[8, 100], confirmPassword: String)

def validatePasswords(password: String, confirm: String): Either[String, PasswordForm] =
  if password != confirm then Left("Passwords do not match")
  else password.refineNel[Length[8, 100]].map(PasswordForm(_, confirm)).toEither.leftMap(_.head)
```

## JSON Serialization with Circe

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.circe.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import io.circe.generic.auto.*
import io.circe.parser._

case class User(name: String :| Contain["a"], age: Int :| Greater[0])

// Encode
val user = User("alice", 30)
val json = user.asJson  // {"name":"alice","age":30}

// Decode and validate
val jsonString = """{"name":"alice","age":30}"""
decode[User](jsonString) match {
  case Right(user)   => println(s"Decoded: $user")
  case Left(error)   => println(s"Decode error: $error")
}

// Validating after decode
case class Product(id: Long :| Greater[0], name: String :| Contain["a"], price: Double :| Greater[0])

def parseAndValidate(jsonString: String): Either[String, Product] =
  decode[Product](jsonString) match {
    case Right(product) =>
      product.id.refineNel[Greater[0]].map(validId => product.copy(id = validId))
        .toEither.leftMap(_.head)
    case Left(error) => Left(s"Decode error: $error")
  }
```

## Validating Collections

```scala
case class Order(items: List[OrderItem] :| NonEmpty, total: Double :| Greater[0])
case class OrderItem(productId: String, quantity: Int :| Greater[0])

def validateOrder(items: List[OrderItem]): EitherNel[String, Order] =
  items.traverse { item =>
    (
      item.productId.refineNel[NotBlank],
      item.quantity.refineNel[Greater[0]]
    ).mapN(OrderItem)
  }.map(validItems => Order(validItems, validItems.map(_.price).sum))
```

## Nested Type Refinement

```scala
case class Product(name: String, price: Double :| Greater[0], quantity: Int :| Greater[0])
case class Order(id: String, products: List[Product] :| NonEmpty)

def createOrder(id: String, products: List[Product]): Either[String, Order] =
  if products.isEmpty then Left("Order must have at least one product")
  else Right(Order(id, products))
```

## Dependencies

```scala
// Core — check for latest version
libraryDependencies += "io.github.iltotore" %% "iron" % "3.2.+"

// Optional integrations
libraryDependencies += "io.github.iltotore" %% "iron-cats" % "3.2.+"
libraryDependencies += "io.github.iltotore" %% "iron-zio" % "3.2.+"
libraryDependencies += "io.github.iltotore" %% "iron-circe" % "3.2.+"
```

## Common Pitfalls

1. **Runtime values aren't validated at compile time**: Values from external sources need explicit refinement
2. **Choose the right refinement method**: `refineUnsafe` throws, `refineEither` is safe, `refineOption` is simple
3. **Constraint composition order matters**: Put most restrictive constraints first for better error messages
4. **`&` means AND, `|` means OR**: Don't confuse intersection with union

## Related Skills

- **scala-fp-patterns** — tagless final, MTL patterns, effect polymorphism
- **scala-json-circe** — deeper Circe JSON codec patterns
- **scala-lang** — Scala 3 language features

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/basic-constraints.md** — Complete reference for all built-in numeric, string, and collection constraints with examples
- **references/advanced-constraints.md** — Custom constraint type classes, Cats/ZIO integration patterns, error accumulation, performance optimization
- **references/form-validation.md** — Multi-field validation, cross-field validation, JSON form validation, complex form composition patterns
