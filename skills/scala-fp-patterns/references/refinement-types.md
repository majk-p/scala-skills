# Refinement Types with Iron (Scala 3)

Complete reference for refined types, opaque type wrappers, and compile-time validation using Iron. Iron replaces the Scala 2 `refined` library with a Scala 3-native approach: `A :| C` syntax, type-class-driven constraints, and zero-cost opaque wrappers.

## Why Iron Over Refined

The `eu.timepit.refined` library relies on Scala 2 macros and implicit conversions that don't port to Scala 3. Iron uses Scala 3's inline methods and the `Constraint` type class, giving you compile-time validation without macros. The `A :| C` syntax is a type alias — no wrapper boxing at runtime.

## Custom Constraint Type Classes

Every constraint is a `given` instance of `Constraint[A, C]` with two members: `test` (the predicate) and `message` (the error description).

```scala
import io.github.iltotore.iron.*

// Basic custom constraint — validated at runtime only
final class NotBlank
object NotBlank:
  given Constraint[String, NotBlank] with
    def message: String = "String must not be blank"
    def test(value: String): Boolean = value.nonEmpty

type NonBlankString = String :| NotBlank
```

For compile-time validation on literal values, mark `test` and `message` as `inline`:

```scala
final class Uppercase
object Uppercase:
  inline def message: String = "Must be uppercase"
  inline def test(value: String): Boolean = value == value.toUpperCase

type UpperString = String :| Uppercase

val ok: UpperString = "HELLO"     // Compiles
// val bad: UpperString = "Hello"  // Compile-time error: Must be uppercase
```

Parameterized constraints use type parameters on the constraint class:

```scala
final class DivisibleBy[V]
object DivisibleBy:
  given Constraint[Int, DivisibleBy[3]] with
    def message: String = "Number must be divisible by 3"
    def test(value: Int): Boolean = value % 3 == 0

type MultipleOfThree = Int :| DivisibleBy[3]
```

Combine multiple custom constraints with `&`:

```scala
type ValidUsername = String :| (NotBlank & Length[3, 20])
```

## Compile-Time vs Runtime Validation

Iron validates literals at compile time. Runtime values from external sources (user input, APIs, databases) require explicit refinement.

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.numeric.*

type PositiveInt = Int :| Greater[0]

// Compile-time — literals checked by the compiler
val a: PositiveInt = 42       // OK
// val b: PositiveInt = -1    // Compile-time error

// Runtime — use refineEither for safe validation
val input: Int = scala.util.Random.nextInt()
val result: Either[String, PositiveInt] = input.refineEither[Greater[0]]

// Runtime — use refineUnsafe when you're certain (throws IllegalArgumentException)
val forced: PositiveInt = 5.refineUnsafe
```

Choose the right method for the context:

| Method | Return Type | Use When |
|--------|-------------|----------|
| `refineEither[C]` | `Either[String, A :| C]` | External input, safe error handling |
| `refineOption[C]` | `Option[A :| C]` | Simple presence check |
| `refineUnsafe` | `A :| C` | You control the value, failure is a bug |
| `refineNel[C]` | `EitherNel[String, A :| C]` | Accumulating errors with Cats |
| `refineZIO[C]` | `ZIO[Any, String, A :| C]` | ZIO effect-based validation |

## Constraint Composition

Use operators to build complex constraints from primitives.

### AND — Intersection (`&`)

All constraints must hold. Use this for fields with multiple requirements:

```scala
import io.github.iltotore.iron.constraint.string.*
import io.github.iltotore.iron.constraint.numeric.*

type StrongPassword = String :| (Length[8, 100] & Contain["!"] & Contain["@"])
type ValidAge = Int :| (Greater[0] & Less[150])
```

### OR — Union (`|`)

At least one constraint must hold:

```scala
type NonZero = Double :| (Positive | Negative)
```

### Implication (`==>`)

If the left constraint holds, the right must also hold. Use this for conditional rules:

```scala
type AdultAge = Int :| (Greater[18] ==> Less[120])
```

Combine all three operators for business rules:

```scala
type ValidDiscount = Double :| (
  Greater[0.0] & Less[100.0] |
  Equal[0.0]    // free is allowed
)
```

## Opaque Type Wrappers (Newtype Pattern)

Scala 3 `opaque type` gives you zero-cost type wrappers with no boxing. Use these to prevent mixing up domain types that share the same underlying representation.

```scala
opaque type UserId = Long
object UserId:
  def apply(value: Long): UserId = value
  extension (self: UserId) def value: Long = self
```

Combine opaque types with Iron refinements to ensure the wrapped value is valid:

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.numeric.*

opaque type UserId = Long :| Greater[0L]
object UserId:
  // Smart constructor — safe
  def from(value: Long): Either[String, UserId] =
    value.refineEither[Greater[0L]].map(_.asInstanceOf[UserId])

  // Smart constructor — unsafe, for trusted data
  def unsafeFrom(value: Long): UserId =
    value.refineUnsafe.asInstanceOf[UserId]

  extension (self: UserId) def value: Long = self.asInstanceOf[Long :| Greater[0L]]
```

The opaque type erases at runtime — `UserId` is just `Long` with zero allocation overhead.

## Smart Constructors Combining Opaque Types + Refinements

Build domain types that are impossible to construct with invalid data:

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.constraint.string.*
import io.github.iltotore.iron.constraint.numeric.*

opaque type Email = String :| Contain["@"]
object Email:
  def from(value: String): Either[String, Email] =
    value.refineEither[Contain["@"]].map(_.asInstanceOf[Email])

  def unsafeFrom(value: String): Email =
    value.refineUnsafe.asInstanceOf[Email]

  extension (self: Email) def value: String = self

opaque type Amount = BigDecimal
object Amount:
  def from(value: BigDecimal): Either[String, Amount] =
    if value >= 0 then Right(value)
    else Left("Amount must be non-negative")

  extension (self: Amount) def value: BigDecimal = self
```

Use these in your domain model to make illegal states unrepresentable:

```scala
case class Order(
  id: UserId,
  customerEmail: Email,
  total: Amount
)

def createOrder(
  rawId: Long,
  rawEmail: String,
  rawTotal: BigDecimal
): Either[String, Order] =
  for
    id    <- UserId.from(rawId)
    email <- Email.from(rawEmail)
    total <- Amount.from(rawTotal)
  yield Order(id, email, total)
```

## Cats Effect Integration

Iron provides `iron-cats` for error accumulation with `EitherNel` and parallel validation:

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.cats.*          // brings refineNel
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import cats.data.EitherNel
import cats.syntax.all.*
import cats.effect.IO

case class User(name: String :| Length[1, 100], age: Int :| Greater[0])

def validateUser(name: String, age: Int): EitherNel[String, User] =
  (
    name.refineNel[Length[1, 100]],
    age.refineNel[Greater[0]]
  ).parMapN(User.apply)

// Lift into IO
def program(name: String, age: Int): IO[User] =
  validateUser(name, age).fold(
    errors => IO.raiseError(new IllegalArgumentException(errors.show)),
    IO.pure
  )
```

`parMapN` collects all validation failures before returning, so users see every problem at once instead of fixing one field at a time.

## JSON Serialization with Circe

`iron-circe` provides automatic `Encoder`/`Decoder` instances for refined types. Decoding validates the constraint — invalid JSON produces a decoding failure:

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.circe.*          // brings Encoder/Decoder instances
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import io.circe.Codec
import io.circe.generic.semiauto.deriveCodec
import io.circe.parser.decode
import io.circe.syntax.EncoderOps

case class Product(
  id: Long :| Greater[0L],
  name: String :| Length[1, 200],
  price: Double :| Greater[0.0]
) derives Codec

// Encode — straightforward
val product = Product(1L, "Widget", 9.99)
val json = product.asJson  // {"id":1,"name":"Widget","price":9.99}

// Decode — invalid values produce DecodingFailure
val badJson = """{"id":-1,"name":"","price":-5.0}"""
decode[Product](badJson)  // Left(DecodingFailure(...))
```

No manual codec writing — `derives Codec` picks up the Iron instances from the classpath.

## Common Imports

```scala
// Core — always needed
import io.github.iltotore.iron.*

// Built-in constraint categories
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import io.github.iltotore.iron.constraint.collection.*

// Effect system integration
import io.github.iltotore.iron.cats.*   // refineNel, Cats instances
import io.github.iltotore.iron.zio.*   // refineZIO, ZIO instances

// JSON integration
import io.github.iltotore.iron.circe.* // Encoder/Decoder for refined types
```

## Dependencies

```scala
// Core
libraryDependencies += "io.github.iltotore" %% "iron" % "3.2.+"

// Optional integrations
libraryDependencies += "io.github.iltotore" %% "iron-cats"  % "3.2.+"
libraryDependencies += "io.github.iltotore" %% "iron-zio"   % "3.2.+"
libraryDependencies += "io.github.iltotore" %% "iron-circe" % "3.2.+"
```
