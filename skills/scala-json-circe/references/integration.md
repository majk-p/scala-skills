# Circe Integration Reference

Cats Effect integration, fs2 stream processing, ZIO integration, and effect system patterns.

## Required Imports

```scala
// Cats Effect + circe
import io.circe._
import io.circe.generic.auto._
import cats.effect._
import cats.implicits._
import fs2.Stream

// ZIO + circe
import io.circe._
import io.circe.generic.auto._
import zio._
import zio.stream._
```

## Cats Effect — IO-based JSON Processing

```scala
import io.circe._
import io.circe.generic.auto._
import cats.effect._
import cats.implicits._

case class Order(orderId: String, userId: String, items: List[OrderItem], total: BigDecimal, status: OrderStatus)
case class OrderItem(productId: String, quantity: Int, price: BigDecimal)
enum OrderStatus:
  case Pending, Processing, Shipped, Delivered, Cancelled

object OrderProcessing extends IOApp.Simple {
  def run: IO[Unit] = {
    val orderJson = """{
      "orderId": "ORD-12345",
      "userId": "USR-67890",
      "items": [{"productId": "PROD-001", "quantity": 2, "price": 29.99}],
      "total": 59.98,
      "status": "Pending"
    }"""

    for {
      order <- io.circe.parser.decode[Order](orderJson).liftTo[IO]
      _ <- IO(println(s"Order ${order.orderId} validated, status: ${order.status}"))
    } yield ()
  }
}
```

## Cats Effect — Streaming JSON Processing

### JSON Lines with fs2

```scala
import io.circe._
import io.circe.generic.auto._
import cats.effect._
import fs2.Stream

case class Event(id: Long, name: String, timestamp: String)

object StreamingExample extends IOApp.Simple {
  def run: IO[Unit] = {
    val jsonStream: Stream[IO, String] = Stream.emits(
      List(
        """{"id":1,"name":"Event1","timestamp":"2024-01-01"}""",
        """{"id":2,"name":"Event2","timestamp":"2024-01-02"}""",
        """{"id":3,"name":"Event3","timestamp":"2024-01-03"}"""
      )
    )

    jsonStream
      .evalMap(line => IO.fromEither(io.circe.parser.decode[Event](line)))
      .evalMap(event => IO(println(s"Processed: ${event.name}")))
      .compile
      .drain
  }
}
```

### Large File Processing

```scala
import io.circe._
import io.circe.generic.auto._
import cats.effect._
import fs2.Stream
import fs2.io.file.Path

case class Transaction(id: String, amount: BigDecimal, txnType: String, date: String)

object LargeFileProcessor extends IOApp.Simple {
  def run: IO[Unit] = {
    fs2.io.file.readAll[IO](Path("/path/to/large.jsonl"))
      .through(fs2.text.utf8Decode)
      .through(fs2.text.lines)
      .filter(_.nonEmpty)
      .evalMap(line => IO.fromEither(io.circe.parser.decode[Transaction](line)))
      .chunkN(1000)
      .evalMap(chunk => IO(println(s"Processed ${chunk.size} transactions")))
      .compile
      .drain
  }
}
```

### Batch Processing with Error Accumulation

```scala
import io.circe._
import io.circe.generic.auto._
import cats.effect._
import fs2.Stream

case class BatchResult[T](batchId: String, successCount: Int, failures: List[String], processed: List[T])

def processBatch[T: Decoder](lines: Stream[IO, String], batchSize: Int): Stream[IO, BatchResult[T]] =
  lines
    .evalMap(line => IO(io.circe.parser.decode[T](line)))
    .batchN(batchSize)
    .evalMap { results =>
      val (successes, failures) = results.partitionMap(identity)
      IO(BatchResult("batch", successes.size, failures.map(_.message), successes))
    }
```

## ZIO Integration

### Basic ZIO + Circe

```scala
import io.circe._
import io.circe.generic.auto._
import io.circe.syntax._
import zio._

case class User(id: Long, name: String)

object ZioCirceExample extends ZIOAppDefault {
  def run: ZIO[Any, Nothing, Unit] =
    for {
      user <- ZIO.succeed(User(1, "Alice"))
      json <- ZIO.succeed(user.asJson.spaces2)
      _ <- Console.printLine(json)
    } yield ()
}
```

### ZIO Streams with JSON

```scala
import io.circe._
import io.circe.generic.auto._
import io.circe.syntax._
import zio._
import zio.stream._

case class LogEntry(timestamp: Long, level: String, message: String)

object ZioStreamExample extends ZIOAppDefault {
  def run: ZIO[Any, Error, Unit] = {
    val logStream: ZStream[Any, Nothing, LogEntry] = ZStream.fromIterable(
      (1 to 10).map(i => LogEntry(System.currentTimeMillis(), if (i % 2 == 0) "INFO" else "WARN", s"Entry $i"))
    )

    logStream
      .mapZIO(entry => ZIO.fromEither(io.circe.parser.decode[LogEntry](entry.asJson.noSpaces)))
      .mapZIO(entry => Console.printLine(s"${entry.level}: ${entry.message}"))
      .runDrain
      .mapError(_.asInstanceOf[Error])
  }
}
```

## HTTP Client Integration

### STTP with Circe

```scala
import sttp.client4._
import sttp.client4.circe._
import io.circe.generic.auto._

case class User(id: Long, name: String)

// Decode response body as JSON
val response: Either[ResponseException[String, CirceError], List[User]] =
  basicRequest
    .get(uri"http://api.example.com/users")
    .response(asJson[List[User]])
    .send(DefaultSyncBackend())
    .body
```

### http4s with Circe

```scala
import org.http4s._
import org.http4s.circe._
import org.http4s.dsl.io._
import io.circe.generic.auto._
import cats.effect._

case class Item(id: Long, name: String)

val service: HttpRoutes[IO] = HttpRoutes.of[IO] {
  case GET -> Root / "items" / LongVar(id) =>
    val item = Item(id, "Widget")
    Ok(item.asJson)  // circe-syntax + http4s-circe
}
```

## Performance Considerations

1. **Parser choice** — `circe-jawn` for best performance, `circe-parser` for convenience
2. **Explicit field mapping** — `forProductN` is faster than auto-derivation
3. **String pooling** — circe reuses string objects for memory efficiency
4. **Cache instances** — store derived encoders/decoders in `implicit val` rather than re-deriving
5. **Streaming for large data** — use fs2/ZIO streams to avoid loading entire JSON into memory
6. **Batch processing** — use `chunkN` / `buffer` to control memory and concurrency

## Resources

- Official docs: https://circe.github.io/circe/
- Cats Effect: https://typelevel.org/cats-effect/
- ZIO: https://zio.dev/
- fs2: https://fs2.io/
