# Advanced Constraints Reference

Custom constraint type classes, Cats/ZIO integration, error accumulation, JSON with Circe, performance optimization. See main SKILL.md for basic patterns.

## Custom Constraint Type Classes

### Runtime Constraint via Given Instance

```scala
import io.github.iltotore.iron.*

final class NotBlank
object NotBlank:
  given Constraint[String, NotBlank] with
    def message = "String should not be blank"
    def test(value: String): Boolean = value.nonEmpty

type NonBlankString = String :| NotBlank
val result: Either[String, NonBlankString] = "hello".refineEither[NotBlank]
```

### Compile-time Constraint via Inline

```scala
final class Uppercase
object Uppercase:
  inline def message: String = "Must be uppercase"
  inline def test(value: String): Boolean = value == value.toUpperCase

type UpperString = String :| Uppercase
val ok: UpperString = "HELLO"    // OK
val bad: UpperString = "hello"   // Compile-time error
```

### Parameterized Constraints

```scala
final class DivisibleBy[V]
object NumericConstraints:
  given Constraint[Int, DivisibleBy[3]] with
    def message = "Number must be divisible by 3"
    def test(value: Int): Boolean = value % 3 == 0

  given Constraint[Double, DivisibleBy[0.5]] with
    def message = "Number must be divisible by 0.5"
    def test(value: Double): Boolean = (value * 2) % 1 == 0

type MultipleOfThree = Int :| DivisibleBy[3]
type MultipleOfHalf = Double :| DivisibleBy[0.5]
```

### Multi-type Constraint Instances

```scala
final class ValidDate
object DateConstraints:
  given Constraint[String, ValidDate] with
    def message = "Date must be in YYYY-MM-DD format"
    def test(value: String): Boolean = value.matches("\\d{4}-\\d{2}-\\d{2}")

  given Constraint[LocalDate, ValidDate] with
    def message = "Date must be a valid date"
    def test(value: LocalDate): Boolean = true

type ValidDateString = String :| ValidDate
type ValidLocalDate = LocalDate :| ValidDate
```

## Cats Integration Patterns

### Required Imports

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.cats.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import cats.data.EitherNel
import cats.syntax.all.*
```

### Parallel Validation with parMapN (Error Accumulation)

All fields validated simultaneously — errors accumulated, not short-circuited.

```scala
case class User(name: String :| Contain["a"], age: Int :| Greater[0])

def validateUser(name: String, age: Int): EitherNel[String, User] =
  (name.refineNel[Contain["a"]], age.refineNel[Greater[0]]).parMapN(User.apply)

validateUser("bob", -5)
// Left(NonEmptyList("Should contain 'a'", "Should be greater than 0"))
```

### Contextual Error Messages

Add field names to errors for clearer diagnostics.

```scala
def validateWithContext(
  username: String, email: String, age: Int
): EitherNel[String, UserProfile] =
  (
    username.refineNel[Contain["a"]].mapLeft(msg => s"Username: $msg"),
    username.refineNel[Length[3, 20]].mapLeft(msg => s"Username: $msg"),
    email.refineNel[Contain["@"]].mapLeft(msg => s"Email: $msg"),
    email.refineNel[Length[5, 100]].mapLeft(msg => s"Email: $msg"),
    age.refineNel[Greater[18]].mapLeft(msg => s"Age: $msg"),
    age.refineNel[Less[120]].mapLeft(msg => s"Age: $msg")
  ).parMapN(UserProfile.apply)
```

### Cats Effect IO Integration

```scala
import cats.effect.IO

def validateWithIO(name: String, age: Int): IO[User] =
  validateUser(name, age).fold(
    errors => IO.raiseError(new Exception(s"Validation failed: ${errors.show}")),
    IO.pure
  )
```

### Validating Collections with Traverse

```scala
case class OrderItem(productId: String, quantity: Int :| Greater[0], price: Double :| Greater[0])

def validateItems(items: List[OrderItem]): EitherNel[String, List[OrderItem]] =
  items.traverse { item =>
    (
      item.productId.refineNel[NotBlank],
      item.quantity.refineNel[Greater[0]],
      item.price.refineNel[Greater[0]]
    ).mapN(OrderItem)
  }
```

## ZIO Integration Patterns

### Required Imports

```scala
import io.github.iltotore.iron.zio.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import zio.*
```

### Basic ZIO Validation

```scala
def validateUser(name: String, age: Int): Task[User] =
  (name.refineZIO[Contain["a"]], age.refineZIO[Greater[0]]).mapN(User.apply)
```

### Multi-field ZIO Validation

```scala
case class UserProfile(
  username: String :| (Contain["a"] & Length[3, 20]),
  email: String :| (Contain["@"] & Length[5, 100]),
  phone: String :| (StartWith["+"] & Length[10, 15])
)

def validateProfile(username: String, email: String, phone: String): Task[UserProfile] =
  (
    username.refineZIO[Contain["a"]],
    username.refineZIO[Length[3, 20]],
    email.refineZIO[Contain["@"]],
    email.refineZIO[Length[5, 100]],
    phone.refineZIO[StartWith["+"]],
    phone.refineZIO[Length[10, 15]]
  ).mapN(UserProfile.apply)
```

### ZIO Error Context

```scala
def validateWithErrorContext(name: String, age: Int): ZIO[Any, String, User] =
  (
    name.refineZIO[Contain["a"]],
    name.refineZIO[Length[3, 20]],
    age.refineZIO[Greater[18]],
    age.refineZIO[Less[120]]
  ).mapN(User.apply)

def run: ZIO[Any, String, Unit] =
  validateWithErrorContext("bob", 15).mapError(err => s"User validation failed: $err")
```

### ZIO with Environment

```scala
def validateUserInContext(username: String, age: Int, userId: UUID): ZIO[Database, String, User] =
  (
    username.refineZIO[Contain["a"]],
    username.refineZIO[Length[3, 20]],
    age.refineZIO[Greater[18]],
    age.refineZIO[Less[120]]
  ).mapN(User.apply)
```

## Form Validation Composition

### Nested Form Validation

Build complex forms by composing simpler validators.

```scala
case class Address(
  street: String :| Length[1, 200], city: String :| Length[1, 100],
  country: String :| Length[2, 100], postalCode: String :| Length[3, 10]
)

case class Customer(
  firstName: String :| (Length[2, 50] & Contain[Char.isAlpha]),
  lastName: String :| (Length[2, 50] & Contain[Char.isAlpha]),
  email: String :| (Contain["@"] & Length[5, 100]),
  address: Address
)

def validateAddress(street: String, city: String, country: String, postalCode: String
): EitherNel[String, Address] =
  (
    street.refineNel[Length[1, 200]], city.refineNel[Length[1, 100]],
    country.refineNel[Length[2, 100]], postalCode.refineNel[Length[3, 10]]
  ).parMapN(Address.apply)

def validateCustomer(
  firstName: String, lastName: String, email: String,
  street: String, city: String, country: String, postalCode: String
): EitherNel[String, Customer] =
  (
    firstName.refineNel[Length[2, 50]], lastName.refineNel[Length[2, 50]],
    email.refineNel[Contain["@"]], email.refineNel[Length[5, 100]],
    validateAddress(street, city, country, postalCode)
  ).parMapN(Customer.apply)
```

### Web API Request Validation

```scala
case class CreateUserRequest(
  username: String :| (Length[3, 20] & Contain[Char.isAlpha]),
  email: String :| (Contain["@"] & Length[5, 100]),
  age: Int :| (Greater[18] & Less[120])
)

def validateCreateUser(username: String, email: String, age: Int
): EitherNel[String, CreateUserRequest] =
  (
    username.refineNel[Length[3, 20]], username.refineNel[Contain[Char.isAlpha]],
    email.refineNel[Contain["@"]], email.refineNel[Length[5, 100]],
    age.refineNel[Greater[18]], age.refineNel[Less[120]]
  ).parMapN(CreateUserRequest.apply)
```

## JSON Serialization with Circe

### Required Imports

```scala
import io.github.iltotore.iron.circe.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import io.circe.generic.auto.*
import io.circe.parser.*
import io.circe.syntax.*
```

### Encode and Decode

```scala
case class User(name: String :| Contain["a"], age: Int :| Greater[0])

val user = User("alice", 30)
val json = user.asJson  // {"name":"alice","age":30}

val jsonString = """{"name":"alice","age":30}"""
decode[User](jsonString) match
  case Right(user)   => println(s"Decoded: $user")
  case Left(error)   => println(s"Decode error: $error")
```

### Validating After Decode

```scala
case class Product(id: Long :| Greater[0], name: String :| Contain["a"], price: Double :| Greater[0])

def parseAndValidate(jsonString: String): Either[String, Product] =
  decode[Product](jsonString) match
    case Right(product) =>
      product.id.refineNel[Greater[0]]
        .map(validId => product.copy(id = validId))
        .toEither.leftMap(_.head)
    case Left(error) =>
      Left(s"Decode error: $error")
```

### Form JSON Validation Pipeline

```scala
case class LoginForm(
  username: String :| (Contain["a"] & Length[3, 20]),
  email: String :| (Contain["@"] & Length[5, 100]),
  password: String :| Length[8, 100]
)

def validateLoginJson(jsonString: String): Either[String, LoginForm] =
  decode[LoginForm](jsonString) match
    case Right(form) =>
      val validation = for
        u <- form.username.refineNel[Contain["a"]]
        u <- u.refineNel[Length[3, 20]]
        e <- form.email.refineNel[Contain["@"]]
        e <- e.refineNel[Length[5, 100]]
        p <- form.password.refineNel[Length[8, 100]]
      yield LoginForm(u, e, p)
      validation.toEither.leftMap(_.head)
    case Left(error) =>
      Left(s"Decode error: $error")
```

## Error Accumulation

### Manual Error Collection

Mix Iron constraints with custom business logic:

```scala
def validateAll(username: String, email: String, age: Int): List[String] =
  List(
    Option.when(username.isEmpty)("Username is required"),
    Option.when(username.length < 3)("Username too short"),
    Option.when(!username.contains("a"))("Username must contain 'a'"),
    Option.when(email.isEmpty)("Email is required"),
    Option.when(age < 18)("Must be 18 or older"),
    Option.when(age > 120)("Invalid age")
  ).flatten

val errors = validateAll("bob", "", 15)
if errors.nonEmpty then errors.foreach(println)
```

## Performance Optimization

### Compile-time vs Runtime Strategy

```scala
// Compile-time: literals — zero runtime cost
def process(value: Int :| Greater[0]): Int = value * 2
process(5)    // OK, validated at compile time
process(-5)   // Compile-time error

// Runtime: for external data
val externalValue: Int = fetchFromExternalSource()
val validated: Either[String, Int :| Greater[0]] = externalValue.refineEither
```

### Selective Validation

Skip expensive constraints when not needed.

```scala
case class Config(
  mandatoryField: String :| Length[1, 100],
  optionalField: String :| Length[0, 100],
  sensitiveField: String :| Length[32, 32]
)

def validateConfig(config: Config, validateOptional: Boolean = false): Either[String, Config] =
  val validated = for
    mandatory  <- config.mandatoryField.refineNel[Length[1, 100]]
    optional   <- if validateOptional then config.optionalField.refineNel[Length[0, 100]]
                  else Right(config.optionalField)
    sensitive  <- config.sensitiveField.refineNel[Length[32, 32]]
  yield Config(mandatory, optional, sensitive)
  validated.toEither.leftMap(_.head)
```

### Caching Validated Values

```scala
import scala.collection.mutable

val priceCache = mutable.Map.empty[String, Double :| Greater[0]]
def getValidatedPrice(productId: String): Double :| Greater[0] =
  priceCache.getOrElseUpdate(productId,
    fetchPrice(productId).refineUnsafe[Greater[0]]
  )
```
### Constraint Ordering

Order from most restrictive to least.

```scala
type OptimalAge = Int :| (Greater[18] & Less[120] & Even & DivisibleBy[7])
```