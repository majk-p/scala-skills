# Circe Codecs Reference

Encoding, decoding, automatic derivation, cursor navigation, and ADT handling.

## Required Imports

```scala
import io.circe._
import io.circe.generic.auto._       // automatic derivation
import io.circe.generic.semiauto._   // semi-automatic derivation
import io.circe.parser._             // parse strings
import io.circe.syntax._             // .asJson extension
```

## Automatic Derivation

The simplest way to get encoders/decoders for case classes. Just import `io.circe.generic.auto._`.

```scala
import io.circe._
import io.circe.generic.auto._
import io.circe.parser._
import io.circe.syntax._

case class User(id: Long, name: String, email: String, age: Int)

// Encode
val user = User(1, "Alice", "alice@example.com", 30)
val jsonString: String = user.asJson.spaces2
// {"id":1,"name":"Alice","email":"alice@example.com","age":30}

// Decode
val jsonStr = """{"id":2,"name":"Bob","email":"bob@example.com","age":25}"""
val decoded: Either[Error, User] = decode[User](jsonStr)
decoded match {
  case Right(user) => println(s"Decoded: $user")
  case Left(error) => println(s"Error: $error")
}
```

## Semi-Automatic Derivation (Recommended for Production)

Derive on demand with `deriveEncoder`/`deriveDecoder`. Avoids implicit scope pollution.

```scala
import io.circe._
import io.circe.generic.semiauto._
import io.circe.syntax._

case class User(id: Long, name: String, email: String)

implicit val userEncoder: Encoder[User] = deriveEncoder[User]
implicit val userDecoder: Decoder[User] = deriveDecoder[User]

val json = User(1, "Alice", "alice@example.com").asJson
val decoded = json.as[User]
```

## Manual Encoder/Decoder

Use `forProductN` when you need to control field names or transform values.

```scala
import io.circe._
import io.circe.syntax._

case class User(id: Long, name: String, email: String)

implicit val userEncoder: Encoder[User] = Encoder.forProduct3("id", "name", "email") {
  case User(id, name, email) => (id, name, email)
}

implicit val userDecoder: Decoder[User] = Decoder.forProduct3("id", "name", "email") {
  (id, name, email) => User(id, name, email)
}

val json = User(1, "Alice", "alice@example.com").asJson
```

## Cursor Navigation

Cursors let you navigate and modify JSON without decoding the entire structure.

```scala
import io.circe._
import io.circe.parser._
import io.circe.syntax._

val jsonStr = """{"id": 1, "name": "Alice", "active": true}"""
val cursor: HCursor = parse(jsonStr).getOrElse(Json.Null).hcursor

// Read a field
cursor.downField("id").as[Int]       // Right(1)
cursor.downField("name").as[String]  // Right("Alice")

// Modify a field
val modified: Option[Json] = cursor.downField("name").withFocus(_.withString(_ => "Bob")).top

// Navigate arrays
val arrJson = """{"items": [1, 2, 3]}"""
val arrCursor = parse(arrJson).getOrElse(Json.Null).hcursor
arrCursor.downField("items").downArray.as[Int]  // Right(1)

// Delete a field
val deleted: Option[Json] = cursor.downField("active").delete.top
```

## ADT Handling (Sealed Traits)

Circe adds a discriminator field to distinguish subtypes. Use `auto` or configure with annotations.

```scala
import io.circe._
import io.circe.generic.auto._
import io.circe.syntax._
import io.circe.parser._

sealed trait Shape
case class Circle(radius: Double) extends Shape
case class Rectangle(width: Double, height: Double) extends Shape

// Auto derivation adds a type discriminator
val circle: Shape = Circle(5.0)
val json = circle.asJson
// {"Circle":{"radius":5.0}}

// Decode back
val decoded = decode[Shape](""""{"Circle":{"radius":5.0}}""")
```

### Custom Discriminator with Configuration

```scala
import io.circe._
import io.circe.generic.semiauto._
import io.circe.generic.extras.Configuration
import io.circe.generic.extras.semiauto._

implicit val config: Configuration = Configuration.default.withDiscriminator("type")

implicit val circleEncoder: Encoder[Circle] = deriveEncoder
implicit val circleDecoder: Decoder[Circle] = deriveDecoder
implicit val rectEncoder: Encoder[Rectangle] = deriveEncoder
implicit val rectDecoder: Decoder[Rectangle] = deriveDecoder
implicit val shapeEncoder: Encoder[Shape] = deriveEncoder
implicit val shapeDecoder: Decoder[Shape] = deriveDecoder

val json = Circle(5.0).asJson
// {"type":"Circle","radius":5.0}
```

## Option and Either

Circe handles `Option` (encodes as null or value) and `Either` (encodes as `Left`/`Right` wrapper) out of the box.

```scala
case class User(id: Long, name: Option[String], contact: Either[String, String])

implicit val userDecoder: Decoder[User] = Decoder.forProduct3("id", "name", "contact") {
  (id, name, contact) => User(id, name, contact)
}
implicit val userEncoder: Encoder[User] = Encoder.forProduct3("id", "name", "contact") {
  case User(id, name, contact) => (id, name, contact)
}

val user = User(1, Some("Alice"), Right("alice@example.com"))
val json = user.asJson
```

## Refined Types Integration

```scala
import io.circe._
import io.circe.refined._  // provides Encoder/Decoder for refined types
import eu.timepit.refined.api._
import eu.timepit.refined.string._

case class Email(value: Refined[String, Url])

// circe-refined provides implicit instances automatically
val json = email.asJson
```

## Error Handling

```scala
import io.circe._
import io.circe.parser._
import io.circe.syntax._

// Basic pattern
decode[User](json) match {
  case Right(user) => handleSuccess(user)
  case Left(error) => handleError(error)
}

// Detailed error inspection
val cursor = parse(json).getOrElse(Json.Null).hcursor
cursor.downField("age").as[Int] match {
  case Right(age) => println(s"Age: $age")
  case Left(error) =>
    println(s"Message: ${error.message}")
    println(s"History: ${error.history}")
}
```

## Custom Error Types

```scala
import io.circe._
import io.circe.generic.semiauto._
import io.circe.syntax._

case class ApiError(code: String, message: String, context: String)

implicit val apiErrorDecoder: Decoder[ApiError] = deriveDecoder[ApiError]
implicit val apiErrorEncoder: Encoder[ApiError] = deriveEncoder[ApiError]
```

## Testing Patterns

```scala
import org.scalatest.matchers.should.Matchers
import org.scalatest.wordspec.AnyWordSpec
import io.circe._
import io.circe.generic.auto._
import io.circe.parser._
import io.circe.syntax._

class CirceCodecSpec extends AnyWordSpec with Matchers {
  case class User(id: Long, name: String)

  "Circe codecs" should {
    "round-trip encode/decode" in {
      val user = User(1, "Alice")
      user.asJson.as[User] shouldBe Right(user)
    }

    "fail on invalid JSON" in {
      decode[User]("""{"id":1,"name":null}""") shouldBe a[Left[_, _]]
    }

    "preserve field values" in {
      val json = """{"id":1,"name":"Alice"}"""
      decode[User](json) shouldBe Right(User(1, "Alice"))
    }
  }
}
```

## Common Pitfalls

1. **Missing auto import** — Always `import io.circe.generic.auto._` for automatic derivation
2. **Null handling** — `null` in JSON may cause `DecodingFailure`; use `Option[T]` for nullable fields
3. **Missing implicits** — All nested types need `Encoder`/`Decoder` instances in scope
4. **Private fields** — Private fields are not derived automatically
5. **ADT ordering** — Sealed trait subtype order can affect discriminator derivation

## Resources

- Official docs: https://circe.github.io/circe/codecs.html
- GitHub: https://github.com/circe/circe
