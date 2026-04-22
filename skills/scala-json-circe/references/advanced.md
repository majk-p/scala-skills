# Circe Advanced Reference

Zero-copy decoding, custom type class instances, conditional decoding, JSON Schema generation, recursive types, and performance optimization.

## Zero-Copy Decoding

Decode from byte arrays/byte buffers without creating intermediate strings. Critical for high-throughput services.

```scala
import io.circe._
import io.circe.jawn.CirceSupport
import java.nio.ByteBuffer

// Parse from ByteBuffer directly
val buffer = ByteBuffer.wrap("""{"id":1,"name":"Alice"}""".getBytes("UTF-8"))
val json: Either[ParsingFailure, Json] = io.circe.jawn.parseByteBuffer(buffer)
val user: Either[Error, User] = json.flatMap(_.as[User])

// Parse from byte array
val bytes = """{"id":1,"name":"Alice"}""".getBytes("UTF-8")
val json2 = io.circe.jawn.parseByteArray(bytes)
```

## Custom Type Class Instances

Build encoders/decoders for types that circe doesn't handle out of the box.

### java.time Types

```scala
import io.circe._
import java.time.{Instant, LocalDate}

// Instant — ISO-8601 string representation
implicit val instantEncoder: Encoder[Instant] = Encoder.instance(v => Json.fromString(v.toString))
implicit val instantDecoder: Decoder[Instant] = Decoder.instance { cursor =>
  cursor.as[String].flatMap { str =>
    Either.catchNonFatal(Instant.parse(str)).leftMap(e => DecodingFailure(e.getMessage, cursor.history))
  }
}

// LocalDate — ISO date string
implicit val localDateEncoder: Encoder[LocalDate] = Encoder.instance(v => Json.fromString(v.toString))
implicit val localDateDecoder: Decoder[LocalDate] = Decoder.instance { cursor =>
  cursor.as[String].flatMap { str =>
    Either.catchNonFatal(LocalDate.parse(str)).leftMap(e => DecodingFailure(e.getMessage, cursor.history))
  }
}
```

### Custom Value Classes

```scala
import io.circe._

case class Email private (value: String)

object Email {
  implicit val encoder: Encoder[Email] = Encoder.instance(e => Json.fromString(e.value))
  implicit val decoder: Decoder[Email] = Decoder.instance { cursor =>
    cursor.as[String].flatMap { str =>
      if (str.contains("@")) Right(Email(str))
      else Left(DecodingFailure("Invalid email format", cursor.history))
    }
  }
}
```

## Conditional Decoding

Decode differently based on a field value. Useful for polymorphic payloads.

```scala
import io.circe._
import io.circe.syntax._
import io.circe.generic.semiauto._

sealed trait Payment
case class CreditCard(amount: Double, cardNumber: String) extends Payment
case class BankTransfer(amount: Double, bankCode: String) extends Payment

implicit val paymentDecoder: Decoder[Payment] = Decoder.instance { cursor =>
  cursor.downField("type").as[String] match {
    case Right("credit_card") => cursor.as[CreditCard](deriveDecoder)
    case Right("bank_transfer") => cursor.as[BankTransfer](deriveDecoder)
    case Right(other) => Left(DecodingFailure(s"Unknown payment type: $other", cursor.history))
    case Left(e) => Left(e)
  }
}
```

## Custom Field Names

Map Scala field names to different JSON keys. Use `forProductN` or `@JsonCodec` with configuration.

### Using forProductN

```scala
import io.circe._

case class ApiUser(userId: Long, userName: String, userEmail: String)

implicit val encoder: Encoder[ApiUser] = Encoder.forProduct3("user_id", "user_name", "user_email") {
  case ApiUser(id, name, email) => (id, name, email)
}
implicit val decoder: Decoder[ApiUser] = Decoder.forProduct3("user_id", "user_name", "user_email") {
  (id, name, email) => ApiUser(id, name, email)
}
```

### Using Configuration (circe-generic-extras)

```scala
import io.circe.generic.extras.Configuration
import io.circe.generic.extras.semiauto._

implicit val config: Configuration = Configuration.default.withSnakeCaseMemberNames

case class ApiUser(userId: Long, userName: String)

implicit val encoder: Encoder[ApiUser] = deriveConfiguredEncoder
implicit val decoder: Decoder[ApiUser] = deriveConfiguredDecoder
// Encodes as: {"user_id":1,"user_name":"Alice"}
```

## Recursive Types

Handle self-referential data structures like trees.

```scala
import io.circe._
import io.circe.generic.semiauto._
import io.circe.syntax._

case class TreeNode(value: Int, left: Option[TreeNode] = None, right: Option[TreeNode] = None)

// Lazy is needed for recursive types with semiauto derivation
implicit val treeNodeEncoder: Encoder[TreeNode] = deriveEncoder[TreeNode]
implicit val treeNodeDecoder: Decoder[TreeNode] = deriveDecoder[TreeNode]

val tree = TreeNode(
  1,
  Some(TreeNode(2)),
  Some(TreeNode(3, Some(TreeNode(4))))
)

val json = tree.asJson
val decoded = json.as[TreeNode]  // Right(tree)
```

### Generic Tree with Recursive ADTs

```scala
sealed trait Expr
case class Literal(value: Double) extends Expr
case class Add(left: Expr, right: Expr) extends Expr
case class Multiply(left: Expr, right: Expr) extends Expr

implicit val exprEncoder: Encoder[Expr] = deriveEncoder
implicit val exprDecoder: Decoder[Expr] = deriveDecoder

val expression: Expr = Add(Literal(1), Multiply(Literal(2), Literal(3)))
val json = expression.asJson
```

## JSON Schema Generation

Generate JSON Schema from circe type class instances.

```scala
import io.circe._
import io.circe.generic.semiauto._
import io.circe.schema._

case class User(id: Long, name: String, email: String)

implicit val userSchema: JsonSchema[User] = JsonSchema.derived[User]
val schemaJson: Json = userSchema.toJson
```

## Complex Type Handling

### Nested Case Classes with Maps and Lists

```scala
import io.circe._
import io.circe.generic.semiauto._

case class Address(street: String, city: String, country: String)
case class Profile(name: String, age: Int, address: Option[Address])
case class ComplexUser(
  id: Long,
  profile: Option[Profile],
  preferences: Map[String, String],
  tags: List[String]
)

implicit val addressEnc: Encoder[Address] = deriveEncoder
implicit val addressDec: Decoder[Address] = deriveDecoder
implicit val profileEnc: Encoder[Profile] = deriveEncoder
implicit val profileDec: Decoder[Profile] = deriveDecoder
implicit val complexUserEnc: Encoder[ComplexUser] = deriveEncoder
implicit val complexUserDec: Decoder[ComplexUser] = deriveDecoder
```

### Key-Value Maps with Non-String Keys

```scala
import io.circe._

// Map[Int, String] — encode keys as strings
implicit val intStringMapEncoder: Encoder[Map[Int, String]] =
  Encoder.instance(m => Json.fromFields(m.map { case (k, v) => k.toString -> Json.fromString(v) }))

implicit val intStringMapDecoder: Decoder[Map[Int, String]] =
  Decoder.instance { cursor =>
    cursor.as[Map[String, String]].map(_.map { case (k, v) => k.toInt -> v })
  }
```

## Performance Optimization

### Choosing the Right Derivation Strategy

| Strategy | Compile Time | Runtime Performance | Use Case |
|----------|-------------|---------------------|----------|
| `generic.auto` | Slow | Good | Prototyping, small projects |
| `generic.semiauto` | Medium | Good | Production |
| `forProductN` | Fast | Best | Performance-critical paths |
| Custom instances | Fast | Best | Full control |

### Parser Selection

- **`circe-jawn`** — Fastest parser, use for production
- **`circe-parser`** — Convenience wrapper around jawn
- **Zero-copy APIs** — `parseByteBuffer`, `parseByteArray` for byte-level input

### General Tips

1. **Use `forProductN`** in hot paths — avoids macro overhead at runtime
2. **Cache derived instances** in `implicit val`, never re-derive inside loops
3. **Prefer semiauto over auto** — explicit is better, avoids implicit scope pollution
4. **Stream large payloads** — don't load entire JSON into memory
5. **Reuse `Json` objects** — circe's AST is immutable and safe to share

## Testing Advanced Codecs

```scala
import org.scalatest.matchers.should.Matchers
import org.scalatest.wordspec.AnyWordSpec
import io.circe._
import io.circe.generic.semiauto._
import io.circe.syntax._
import io.circe.parser._

class AdvancedCodecSpec extends AnyWordSpec with Matchers {
  case class User(id: Long, name: String, admin: Boolean)
  implicit val enc: Encoder[User] = deriveEncoder
  implicit val dec: Decoder[User] = deriveDecoder

  "Advanced codecs" should {
    "round-trip recursive types" in {
      val tree = TreeNode(1, Some(TreeNode(2)), Some(TreeNode(3)))
      tree.asJson.as[TreeNode] shouldBe Right(tree)
    }

    "handle conditional decoding" in {
      val json = """{"type":"credit_card","amount":10.0,"cardNumber":"4111"}"""
      decode[Payment](json) shouldBe a[Right[_, CreditCard]]
    }

    "reject invalid custom types" in {
      val json = """"not-an-email""""
      decode[Email](json) shouldBe a[Left[_, _]]
    }
  }
}
```

## Resources

- circe codecs: https://circe.github.io/circe/codecs.html
- circe generic: https://circe.github.io/circe/codec-for-generic-classes.html
- circe schema: https://github.com/circe/circe-schema
- GitHub: https://github.com/circe/circe
