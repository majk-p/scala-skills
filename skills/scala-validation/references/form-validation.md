# Form Validation Reference

Multi-field validation, cross-field validation, JSON form validation with Circe, and complex form composition patterns. See main SKILL.md for overview; see basic-constraints.md and advanced-constraints.md for constraint API details.

## Multi-field Validation with Error Accumulation

Every field validated simultaneously, errors collected — no short-circuiting. Users see all problems at once, not one per submission. Pattern: each field → `refineNel`, combine with `parMapN`.

### Registration Form

```scala
import io.github.iltotore.iron.*
import io.github.iltotore.iron.cats.*
import io.github.iltotore.iron.constraint.numeric.*
import io.github.iltotore.iron.constraint.string.*
import io.github.iltotore.iron.constraint.collection.*
import cats.data.EitherNel
import cats.syntax.all.*

// Refined types — reuse across your codebase
type Username = String :| (Length[3, 20] & Contain["a"])
type Email    = String :| (Contain["@"] & Length[5, 100])
type Age      = Int :| (Greater[18] & Less[120])
type Password = String :| Length[8, 100]

case class RegistrationForm(username: Username, email: Email, age: Age, password: Password)

def validateRegistration(
  username: String, email: String, age: Int, password: String
): EitherNel[String, RegistrationForm] =
  (
    username.refineNel[Length[3, 20]],
    username.refineNel[Contain["a"]],
    email.refineNel[Contain["@"]],
    email.refineNel[Length[5, 100]],
    age.refineNel[Greater[18]],
    age.refineNel[Less[120]],
    password.refineNel[Length[8, 100]]
  ).parMapN(RegistrationForm.apply)

// validateRegistration("b", "no-at", 15, "short")
// Left(NonEmptyList(
//   "Length should be between 3 and 20",
//   "Should contain 'a'",
//   "Should contain '@'",
//   "Length should be between 5 and 100",
//   "Should be greater than 18",
//   "Length should be between 8 and 100"
// ))
```

### Address Form

```scalatype Street     = String :| Length[1, 200]
type City       = String :| Length[1, 100]
type Country    = String :| Length[2, 100]
type PostalCode = String :| Length[3, 10]

case class Address(street: Street, city: City, country: Country, postalCode: PostalCode)

def validateAddress(
  street: String, city: String, country: String, postalCode: String
): EitherNel[String, Address] =
  (
    street.refineNel[Length[1, 200]],
    city.refineNel[Length[1, 100]],
    country.refineNel[Length[2, 100]],
    postalCode.refineNel[Length[3, 10]]
  ).parMapN(Address.apply)
```

### Payment Form

Same pattern, more constraints per field:```scala
type CardNumber = String :| (Length[16, 19] & Digits)
type Cvv        = String :| (Length[3, 4] & Digits)
type Amount     = Double :| Greater[0.0]

case class Payment(cardNumber: CardNumber, cvv: Cvv, amount: Amount)

def validatePayment(card: String, cvv: String, amount: Double): EitherNel[String, Payment] =
  (
    card.refineNel[Length[16, 19]], card.refineNel[Digits],
    cvv.refineNel[Length[3, 4]], cvv.refineNel[Digits],
    amount.refineNel[Greater[0.0]]
  ).parMapN(Payment.apply)
```

## Cross-field Validation

Constraints spanning multiple fields. Iron operates on single values, so cross-field rules live in a second pass after individual field validation.

### Password Confirmation

```scala
def validatePasswordWithConfirm(password: String, confirm: String): EitherNel[String, Password] =
  if password != confirm then Either.leftNec("Passwords do not match")
  else password.refineNel[Length[8, 100]]
```

Why separate the match check: Iron's type system constrains single values. "Must match" spans two values, so it's a plain conditional outside Iron.

### Date Range (Start Before End)

```scala
import java.time.LocalDate

final class ValidDate
object DateConstraints:
  given Constraint[String, ValidDate] with
    def message = "Date must be in YYYY-MM-DD format"
    def test(value: String): Boolean = value.matches("\\d{4}-\\d{2}-\\d{2}")

type DateString = String :| ValidDate

case class DateRange(startDate: DateString, endDate: DateString)

def validateDateRange(start: String, end: String): EitherNel[String, DateRange] =
  val validStart = start.refineNel[ValidDate].mapLeft(msg => s"Start date: $msg")
  val validEnd   = end.refineNel[ValidDate].mapLeft(msg => s"End date: $msg")

  (validStart, validEnd).parMapN(DateRange.apply).ensureOr(range =>
    s"Start date (${range.startDate}) must be before end date (${range.endDate})"
  )(range => range.startDate <= range.endDate)
```

### Conditional Fields (If X Then Y Required)

Branch before refining — skip validation for disabled features:

```scala
case class NotificationSettings(
  enableEmail: Boolean, emailAddress: Option[Email],
  enableSms: Boolean, phoneNumber: Option[String :| Length[10, 15]]
)

def validateNotificationSettings(
  enableEmail: Boolean, emailAddress: Option[String],
  enableSms: Boolean, phoneNumber: Option[String]
): EitherNel[String, NotificationSettings] =
  val emailResult = if !enableEmail then Right(None)
    else emailAddress.toRightNec("Email address required when email notifications enabled")
      .flatMap(_.refineNel[Contain["@"]].map(Some(_)))

  val phoneResult = if !enableSms then Right(None)
    else phoneNumber.toRightNec("Phone number required when SMS enabled")
      .flatMap(_.refineNel[Length[10, 15]].map(Some(_)))

  (emailResult, phoneResult).parMapN(NotificationSettings(enableEmail, _, enableSms, _))
```

## JSON Form Validation with Circe

Circe decodes JSON shape but won't enforce domain constraints. Pattern: decode into raw DTO → validate each field with Iron → accumulate errors → return structured error response.

### Decode, Validate, Respond

```scala
import io.github.iltotore.iron.circe.*
import io.circe.generic.auto.*
import io.circe.parser.*
import io.circe.syntax.*
import io.circe.{Json, JsonObject}

// Raw DTO — no Iron types. Circe decodes into this.
case class CreateUserDTO(username: String, email: String, age: Int, password: String)

// Validated domain model — Iron types everywhere.
case class CreateUser(username: Username, email: Email, age: Age, password: Password)

def validateCreateUserDTO(dto: CreateUserDTO): EitherNel[String, CreateUser] =
  (
    dto.username.refineNel[Length[3, 20]].mapLeft(m => s"username: $m"),
    dto.username.refineNel[Contain["a"]].mapLeft(m => s"username: $m"),
    dto.email.refineNel[Contain["@"]].mapLeft(m => s"email: $m"),
    dto.email.refineNel[Length[5, 100]].mapLeft(m => s"email: $m"),
    dto.age.refineNel[Greater[18]].mapLeft(m => s"age: $m"),
    dto.age.refineNel[Less[120]].mapLeft(m => s"age: $m"),
    dto.password.refineNel[Length[8, 100]].mapLeft(m => s"password: $m")
  ).parMapN(CreateUser.apply)

// HTTP handler pattern
def handleCreateUser(jsonString: String): Either[Json, CreateUser] =
  decode[CreateUserDTO](jsonString) match
    case Left(error) =>
      Left(JsonObject.singleton("decodeError", error.getMessage.asJson).asJson)
    case Right(dto) =>
      validateCreateUserDTO(dto).leftMap { errors =>
        Json.obj("errors" -> errors.toList.asJson)
      }.toEither
```

### Field-level Error Mapping

Group errors by field name for frontend display:```scala
case class FieldError(field: String, messages: List[String])

def groupErrors(errors: NonEmptyList[String]): List[FieldError] =
  errors.toList
    .map { msg =>
      val idx = msg.indexOf(": ")
      if idx > 0 then (msg.substring(0, idx), msg.substring(idx + 2))
      else ("unknown", msg)
    }
    .groupMap(_._1)(_._2)
    .map { (field, msgs) => FieldError(field, msgs) }
    .toList

// Returns JSON like:
// { "errors": [
//   { "field": "username", "messages": ["Length should be between 3 and 20"] },
//   { "field": "age", "messages": ["Should be greater than 18"] }
// ]}
```

## Complex Form Composition

### Nested Forms (Order with Items)

Each sub-form has its own validator. Compose with `parMapN` and `traverse`:

```scala
case class OrderItem(productId: String :| Length[1, 50], quantity: Int :| Greater[0], price: Double :| Greater[0.0])
case class Order(orderId: String :| Length[1, 36], items: List[OrderItem], total: Double :| Greater[0.0])

def validateItem(productId: String, quantity: Int, price: Double): EitherNel[String, OrderItem] =
  (
    productId.refineNel[Length[1, 50]], quantity.refineNel[Greater[0]], price.refineNel[Greater[0.0]]
  ).parMapN(OrderItem.apply)

def validateItems(raw: List[(String, Int, Double)]): EitherNel[String, List[OrderItem]] =
  raw.zipWithIndex.traverse { case ((pid, qty, price), idx) =>
    validateItem(pid, qty, price).mapLeft(_.map(msg => s"item[$idx]: $msg"))
  }

def validateOrder(orderId: String, rawItems: List[(String, Int, Double)]): EitherNel[String, Order] =
  val items = validateItems(rawItems)
  val id    = orderId.refineNel[Length[1, 36]]
  (id, items).parMapN { (validId, validItems) =>
    val total = validItems.map(i => i.quantity * i.price).sum
    Order(validId, validItems, total.refineUnsafe[Greater[0.0]])
  }
```

### Dependent Forms (Shipping Depends on Address)

When one field's validation depends on another's value, branch after field-level validation:

```scala
case class ShippingMethod(name: String :| Length[1, 50], cost: Double :| Greater[0.0])

sealed trait ShippingSelection
case class Domestic(method: ShippingMethod) extends ShippingSelection
case class International(method: ShippingMethod, customsFee: Double :| Greater[0.0]) extends ShippingSelection

def validateShipping(country: String, methodName: String, cost: Double, customsFee: Option[Double]
): EitherNel[String, ShippingSelection] =
  val method = (
    methodName.refineNel[Length[1, 50]], cost.refineNel[Greater[0.0]]
  ).parMapN(ShippingMethod.apply)

  if country == "US" then method.map(Domestic(_))
  else
    val fee = customsFee match
      case None    => Either.leftNec[String, Double :| Greater[0.0]]("Customs fee required for international")
      case Some(v) => v.refineNel[Greater[0.0]]
    (method, fee).parMapN(International.apply)
```

### Multi-step Wizard with State Accumulation

Each step validates independently. Final step combines all validated data.

```scala
case class Step1(firstName: String :| Length[1, 50], lastName: String :| Length[1, 50], email: Email)
case class Step2(address: Address)
case class Step3(payment: Payment)
case class WizardResult(personal: Step1, address: Step2, payment: Step3)

def validateStep1(first: String, last: String, email: String): EitherNel[String, Step1] =
  (
    first.refineNel[Length[1, 50]], last.refineNel[Length[1, 50]],
    email.refineNel[Contain["@"]], email.refineNel[Length[5, 100]]
  ).parMapN(Step1.apply)

def validateStep2(street: String, city: String, country: String, postal: String): EitherNel[String, Step2] =
  validateAddress(street, city, country, postal).map(Step2(_))

// Frontend stores validated Step1 and Step2 results server-side (session/cache),
// then calls assembleWizard after Step3 completes:
def assembleWizard(step1: Step1, step2: Step2, step3: Step3): WizardResult =
  WizardResult(step1, step2, step3)
```

## Form Validation Patterns for Web APIs

### HTTP Error Response Format

Standardize validation errors for API consumers:

```scala
case class ApiError(status: Int, errors: List[FieldError])
case class FieldError(field: String, message: String)

def toApiError(errors: NonEmptyList[String], status: Int = 422): ApiError =
  val fieldErrors = errors.toList.map { msg =>
    val (field, message) = msg.splitAt(msg.indexOf(": ") + 2)
    FieldError(field.stripSuffix(": "), message)
  }
  ApiError(status, fieldErrors)
```

### Localization-ready Error Messages

Use error codes so the frontend can translate:

```scala
case class ValidationErrorCode(code: String, params: Map[String, String])

def toErrorCodes(errors: NonEmptyList[String]): List[ValidationErrorCode] =
  errors.toList.map {
    case m if m.contains("greater than") =>
      ValidationErrorCode("validation.number.greaterThan", Map("min" -> m.split(" ").last))
    case m if m.contains("Length should be between") =>
      ValidationErrorCode("validation.string.lengthBetween", Map("detail" -> m))
    case other =>
      ValidationErrorCode("validation.unknown", Map("message" -> other))
  }
```

### Common Form Patterns

**Search filters** — optional fields, validate only when present:

```scala
case class SearchFilters(
  query: Option[String :| Length[1, 200]],
  minPrice: Option[Double :| Greater[0.0]],
  maxPrice: Option[Double :| Greater[0.0]],
  limit: Option[Int :| Interval[1, 100]]
)

def validateFilters(query: Option[String], minPrice: Option[Double], maxPrice: Option[Double], limit: Option[Int]
): EitherNel[String, SearchFilters] =
  (
    query.traverse(_.refineNel[Length[1, 200]]),
    minPrice.traverse(_.refineNel[Greater[0.0]]),
    maxPrice.traverse(_.refineNel[Greater[0.0]]),
    limit.traverse(_.refineNel[Interval[1, 100]])
  ).parMapN(SearchFilters.apply)
```

**User profile edit** — partial updates with `Option` + `traverse` (same pattern as search filters above, but with `Map[String, String]` input where only present keys are validated).

**Bulk import** — validate each row, collect per-row errors:

```scala
case class ImportRow(id: Int :| Greater[0], name: String :| Length[1, 100], email: Email)
case class ImportResult(successes: List[ImportRow], failures: List[(Int, List[String])])

def validateBulk(rows: List[(Int, String, String)]): ImportResult =
  val results = rows.map { (id, name, email) =>
    val validated = (
      id.refineNel[Greater[0]], name.refineNel[Length[1, 100]],
      email.refineNel[Contain["@"]], email.refineNel[Length[5, 100]]
    ).parMapN(ImportRow.apply)
    validated.fold(errors => Left((id, errors.toList)), Right(_))
  }
  ImportResult(results.collect { case Right(r) => r }, results.collect { case Left(f) => f })
```

## Testing Form Validators

### Unit Testing Individual Validators

Test valid and invalid inputs:

```scala
import munit.FunSuite

class RegistrationValidatorTest extends FunSuite:

  test("valid registration returns Right") {
    val result = validateRegistration("alice123", "alice@example.com", 25, "securePass123")
    assert(result.isRight)
  }

  test("all invalid fields accumulate all errors") {
    val result = validateRegistration("b", "no-at", 15, "short")
    assert(result.isLeft)
    val errors = result.leftMap(_.toList).left.getOrElse(List.empty)
    assert(errors.length >= 4, s"Expected 4+ errors, got: $errors")
  }

  test("username too short produces correct error") {
    val result = validateRegistration("ab", "alice@example.com", 25, "securePass123")
    val errors = result.leftMap(_.toList).left.getOrElse(List.empty)
    assert(errors.exists(_.contains("3")))
  }
```

### Property-based Testing of Forms

ScalaCheck boundary testing around constraint thresholds:

```scala
import munit.ScalaCheckSuite
import org.scalacheck.Prop.*

class RegistrationPropertyTest extends ScalaCheckSuite:

  property("age below 18 always fails") {
    forAll { (age: Int) =>
      whenever(age < 18) {
        val result = validateRegistration("alice", "a@b.cd", age, "password123")
        assert(result.isLeft)
        result.leftMap(_.toList).left.foreach { errors =>
          assert(errors.exists(_.contains("18")))
        }
      }
    }
  }
```

### Integration Testing with HTTP Endpoints

Test the full JSON → validate → response pipeline:

```scala
class CreateUserEndpointTest extends FunSuite:

  test("valid JSON returns user") {
    val json = """{"username":"alice","email":"alice@test.com","age":25,"password":"secure123"}"""
    assert(handleCreateUser(json).isRight)
  }

  test("malformed JSON returns decode error") {
    val result = handleCreateUser("""{not valid json}""")
    assert(result.isLeft)
  }

  test("multiple constraint violations return all field errors") {
    val json = """{"username":"b","email":"nope","age":10,"password":"x"}"""
    val result = handleCreateUser(json)
    assert(result.isLeft)
    val errors = result.swap.toOption.get.hcursor.downField("errors").as[List[String]]
    assert(errors.toOption.get.length >= 3)
  }
```
