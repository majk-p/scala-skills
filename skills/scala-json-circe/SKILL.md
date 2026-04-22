---
name: scala-json-circe
description: Use this skill when working with JSON in Scala using circe. Covers encoding, decoding, automatic and semi-automatic derivation, cursor navigation, ADT handling, custom codecs, zero-copy decoding, JSON Schema generation, recursive types, cats-effect integration, fs2 streaming, ZIO integration, and performance optimization. Trigger when the user mentions JSON, circe, encode, decode, serialization, deserialization, JSON parsing, JSON schema, or needs to handle JSON data in a Scala codebase — even if they don't explicitly name the library.
---

# JSON Processing with Circe in Scala

Circe is a pure functional JSON library for Scala built on cats. It provides type-class-based encoding/decoding with automatic derivation via generic, zero-copy parsing via jawn, cursor-based navigation, and seamless integration with cats-effect and fs2.

This is the standard JSON library for the Typelevel ecosystem. If the codebase uses cats-effect, fs2, or http4s, circe is the default choice.

## Quick Start

```scala
import io.circe._
import io.circe.generic.auto._
import io.circe.parser._
import io.circe.syntax._

case class User(id: Long, name: String, email: String)

// Encode to JSON
val user = User(1, "Alice", "alice@example.com")
val jsonString: String = user.asJson.spaces2
// {"id":1,"name":"Alice","email":"alice@example.com"}

// Decode from JSON
val decoded: Either[Error, User] = decode[User]("""{"id":2,"name":"Bob","email":"bob@example.com"}""")
```

## Core Concepts

### Encoder and Decoder

The two fundamental type classes. `Encoder[A]` converts `A => Json`. `Decoder[A]` converts `Json => Either[Error, A]`.

```scala
// Built-in instances for primitives, collections, Option, Either
val intJson: Json = 42.asJson
val listJson: Json = List(1, 2, 3).asJson
val optJson: Json = Some("hello").asJson  // "hello"
val noneJson: Json = None.asJson          // null

// Decoder produces Either[Error, A]
val result: Either[Error, Int] = Decoder[Int].decodeJson(42.asJson)
```

### Derivation Strategies

Three ways to get instances, from least to most explicit:

```scala
import io.circe.generic.auto._       // 1. Auto — everything in scope
import io.circe.generic.semiauto._   // 2. Semi-auto — derive on demand (recommended)
import io.circe._                     // 3. Manual — full control with forProductN

// Auto — just import, implicit resolution does the rest
case class Item(name: String, price: Double)
// Encoder[Item] and Decoder[Item] are now in implicit scope

// Semi-auto — explicit derivation (preferred for production)
implicit val itemEncoder: Encoder[Item] = deriveEncoder[Item]
implicit val itemDecoder: Decoder[Item] = deriveDecoder[Item]

// Manual — control field names and transformations
implicit val itemEncoder: Encoder[Item] = Encoder.forProduct2("item_name", "item_price") {
  case Item(name, price) => (name, price)
}
implicit val itemDecoder: Decoder[Item] = Decoder.forProduct2("item_name", "item_price") {
  (name, price) => Item(name, price)
}
```

### Cursor Navigation

Cursors let you traverse and modify JSON without decoding the whole structure.

```scala
val json: Json = parse("""{"user":{"name":"Alice","age":30}}""").getOrElse(Json.Null)
val cursor: HCursor = json.hcursor

// Read nested field
cursor.downField("user").downField("name").as[String]  // Right("Alice")

// Modify in place
val updated: Option[Json] = cursor.downField("user").downField("age").withFocus(_.mapNumber(_.map(_ + 1))).top

// Delete a field
val cleaned: Option[Json] = cursor.downField("user").downField("age").delete.top
```

## Common Patterns

### Custom Codecs for External Types

```scala
import java.time.Instant

implicit val instantEncoder: Encoder[Instant] = Encoder.instance(v => Json.fromString(v.toString))
implicit val instantDecoder: Decoder[Instant] = Decoder.instance { cursor =>
  cursor.as[String].flatMap { str =>
    Either.catchNonFatal(Instant.parse(str))
      .leftMap(e => DecodingFailure(e.getMessage, cursor.history))
  }
}
```

### ADTs (Sealed Traits)

```scala
sealed trait Shape
case class Circle(radius: Double) extends Shape
case class Rectangle(width: Double, height: Double) extends Shape

// Auto derivation wraps subtype name as key:
// Circle(5.0).asJson → {"Circle":{"radius":5.0}}

// For custom discriminator field, use circe-generic-extras:
implicit val config: Configuration = Configuration.default.withDiscriminator("type")
implicit val shapeEncoder: Encoder[Shape] = deriveEncoder
implicit val shapeDecoder: Decoder[Shape] = deriveDecoder
// Circle(5.0).asJson → {"type":"Circle","radius":5.0}
```

### Error Handling

```scala
decode[User](jsonString) match {
  case Right(user) => handleSuccess(user)
  case Left(error) =>
    println(s"Message: ${error.message}")   // what went wrong
    println(s"History: ${error.history}")    // path through JSON
}
```

### Optional and Nullable Fields

```scala
case class User(id: Long, name: String, nickname: Option[String])
// nickname = None  → field omitted or null in JSON
// nickname = Some("ali") → "ali" in JSON
```

## Advanced Patterns

### Zero-Copy Decoding

Parse byte arrays directly without intermediate strings. Essential for high-throughput services.

```scala
import java.nio.ByteBuffer

val bytes = """{"id":1,"name":"Alice"}""".getBytes("UTF-8")
val buffer = ByteBuffer.wrap(bytes)

val json: Either[ParsingFailure, Json] = io.circe.jawn.parseByteBuffer(buffer)
val user: Either[Error, User] = json.flatMap(_.as[User])
```

### Recursive Types

```scala
case class TreeNode(value: Int, left: Option[TreeNode] = None, right: Option[TreeNode] = None)

implicit val treeNodeEncoder: Encoder[TreeNode] = deriveEncoder[TreeNode]
implicit val treeNodeDecoder: Decoder[TreeNode] = deriveDecoder[TreeNode]

val tree = TreeNode(1, Some(TreeNode(2)), Some(TreeNode(3, Some(TreeNode(4)))))
tree.asJson.as[TreeNode]  // Right(tree)
```

### JSON Schema Generation

```scala
import io.circe.schema._

implicit val userSchema: JsonSchema[User] = JsonSchema.derived[User]
val schemaJson: Json = userSchema.toJson
```

## Integration

### Cats Effect

```scala
import cats.effect._
import cats.implicits._

for {
  user <- IO.fromEither(decode[User](jsonString))
  json <- IO.pure(user.asJson.spaces2)
  _ <- IO(println(json))
} yield ()
```

### fs2 Streaming

```scala
import fs2.Stream

// Parse JSON Lines from a stream
val events: Stream[IO, Event] =
  fs2.io.file.readAll[IO](path)
    .through(fs2.text.utf8Decode)
    .through(fs2.text.lines)
    .filter(_.nonEmpty)
    .evalMap(line => IO.fromEither(decode[Event](line)))
```

### ZIO

```scala
import zio._

for {
  user <- ZIO.fromEither(decode[User](jsonString))
  json <- ZIO.succeed(user.asJson.spaces2)
  _ <- Console.printLine(json)
} yield ()
```

### HTTP Clients

```scala
// STTP
import sttp.client4.circe._
basicRequest.get(uri).response(asJson[User])

// http4s
import org.http4s.circe._
Ok(user.asJson)  // encode response body
req.as[User]     // decode request body
```

## Dependencies

```scala
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % "latest.version")  // check for current version

// Optional — streaming
"co.fs2" %% "fs2-core"  // fs2 integration

// Optional — refined types
"io.circe" %% "circe-refined"

// Optional — JSON Schema
"io.circe" %% "circe-schema"

// Optional — generic-extras for custom discriminators/snake_case
"io.circe" %% "circe-generic-extras"
```

## Related Skills

- **scala-async-effects** — when combining JSON processing with ZIO or cats-effect IO
- **scala-streaming** — when building JSON processing pipelines with fs2
- **scala-http-clients** — when using circe with STTP or http4s for REST APIs
- **scala-web-frameworks** — when integrating circe into Play, http4s, or Akka HTTP

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/codecs.md** — Encoding, decoding, automatic/semi-auto/manual derivation, cursor navigation, ADT handling, Option/Either, refined types, error handling, testing patterns
- **references/integration.md** — Cats Effect IO integration, fs2 streaming (JSON Lines, large files, batch processing), ZIO integration, ZIO streams, HTTP client integration (STTP, http4s)
- **references/advanced.md** — Zero-copy decoding, custom type classes (java.time, value classes), conditional decoding, custom field names, recursive types, JSON Schema, performance optimization, testing advanced codecs
