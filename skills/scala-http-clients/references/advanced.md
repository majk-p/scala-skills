# Advanced HTTP Client Patterns

Streaming responses, OAuth2 flows, multipart uploads, WebSocket handling, retry/circuit-breaker strategies, batch processing, and performance optimization. Load this when building production HTTP clients with STTP.

## Table of Contents

- [Streaming](#streaming)
- [Multipart Requests](#multipart-requests)
- [WebSocket Handling](#websocket-handling)
- [OAuth2 Flows](#oauth2-flows)
- [Retry Strategies](#retry-strategies)
- [Circuit Breaking](#circuit-breaking)
- [Custom Error Types](#custom-error-types)
- [Batch Processing](#batch-processing)
- [Parallel Requests](#parallel-requests)
- [Performance Optimization](#performance-optimization)

---

## Streaming

### Response Body Streaming with fs2

```scala
import sttp.client4.*
import sttp.client4.fs2.*
import fs2.*

// Stream response body
val request = basicRequest
  .get(uri"https://example.com/large-file")
  .response(asStream[IO, Byte])

request.send(backend).body match {
  case Right(stream) =>
    stream
      .through(fs2.text.utf8Decode)
      .take(100)
      .compile
      .toList
}
```

### Stream to File

```scala
import fs2.io.file.*
import java.nio.file.Paths

stream
  .through(fs2.file.writeAll(Paths.get("download.zip")))
  .compile
  .drain
```

### Request Body Streaming

```scala
import sttp.client4.*
import sttp.client4.fs2.*

val fileStream: Stream[IO, Byte] = fs2.io.file.readAll[IO](Paths.get("upload.bin"))

val request = basicRequest
  .post(uri"https://example.com/upload")
  .streamBody(fileStream)
```

## Multipart Requests

```scala
import sttp.client4.*

// Simple file upload
val upload1 = basicRequest
  .post(uri"https://example.com/upload")
  .multipartBody(BasicFileBody(new java.io.File("data.txt")))

// Multiple parts with metadata
val upload2 = basicRequest
  .post(uri"https://example.com/upload")
  .multipartBody(
    BasicFileBody(new java.io.File("file1.txt")),
    BasicFileBody(new java.io.File("file2.txt")),
    BasicStringBody("description", "Two files upload")
  )

// Custom metadata
val upload3 = basicRequest
  .post(uri"https://example.com/upload")
  .multipartBody(
    BasicFileBody(
      new java.io.File("data.txt"),
      contentType = Some("text/plain"),
      fileName = Some("custom-name.txt")
    )
  )
```

## WebSocket Handling

```scala
import sttp.client4.*
import sttp.client4.ws.*

// Basic WebSocket
val wsRequest = basicRequest
  .get(uri"wss://echo.websocket.org")
  .response(asWebSocketAlways[IO])

wsRequest.send(backend).body match {
  case Right(ws) =>
    ws.sendText("Hello")
      .flatMap(_ => ws.receiveText())
      .repeatN(10)
}

// Bidirectional communication
wsRequest.send(backend).body match {
  case Right(ws) =>
    for {
      _   <- ws.sendText("Hello")
      _   <- ws.sendText("World")
      msg <- ws.receiveText()
    } yield println(s"Received: $msg")
}
```

## OAuth2 Flows

### Client Credentials

```scala
import sttp.client4.*
import sttp.oauth2.*

// Request token
val tokenResponse = basicRequest
  .post(uri"https://oauth2.example.com/token")
  .body("grant_type=client_credentials&client_id=id&client_secret=secret")
  .send(backend)

// Use token
val apiRequest = basicRequest
  .get(uri"https://api.example.com/resource")
  .auth.oauth2.bearer("access-token")
```

### Authorization Code

```scala
val authRequest = basicRequest
  .get(uri"https://example.com/authorize")
  .auth.oauth2.AuthorizationCodeRequest(
    clientId = "your-client-id",
    redirectUri = uri"https://your-app.com/callback",
    scope = Some("read write"),
    state = Some("csrf-token")
  )
```

### Refresh Token

```scala
val refreshRequest = basicRequest
  .post(uri"https://oauth2.example.com/token")
  .body("grant_type=refresh_token&refresh_token=refresh_token_value")
  .send(backend)
```

## Retry Strategies

```scala
import sttp.client4.*
import sttp.client4.wrappers.retryingBackend.*
import scala.concurrent.duration.*

val retryBackend = RetryingBackend(
  backend,
  maxRetries = 3,
  retryOnFailure = true,
  retryPolicy = RetryPolicy.whenShouldRetry(
    RetryPolicy.Defaults.Backoff.exponentialBackoff[Fibonacci](baseDelay = 500.millis)
  )
)

val request = basicRequest.get(uri"http://example.com/api").send(retryBackend)
```

### Conditional Retry

```scala
def isRetryable(error: String): Boolean =
  error.contains("5") || error.contains("429")

request.send(backend).body match {
  case Left(error) if isRetryable(error) => // retry logic
  case Left(error)                       => Left(error)
  case Right(body)                       => Right(body)
}
```

## Circuit Breaking

```scala
import sttp.client4.*
import resilience4s.circuitbreaker.*

val circuitBreaker = CircuitBreaker.Builder()
  .failureRateThreshold(50)
  .waitDurationInOpenState(60.seconds)
  .permittedNumberOfCallsInHalfOpenState(10)
  .build()

val resilientBackend = CircuitBreakerBackend(backend, circuitBreaker = circuitBreaker)
```

## Custom Error Types

```scala
sealed trait HttpError
case class HttpErrorStatus(statusCode: Int, message: String) extends HttpError
case class HttpErrorParsing(message: String) extends HttpError
case class HttpErrorConnection(message: String) extends HttpError

case class User(name: String)

object UserClient {
  def getUser(id: Long): Either[HttpError, User] = {
    val request = basicRequest.get(uri"https://api.example.com/user/$id")

    request.send(backend).body match {
      case Right(json) =>
        io.circe.parser.decode[User](json) match {
          case Right(user) => Right(user)
          case Left(error) => Left(HttpErrorParsing(error.message))
        }
      case Left(error) =>
        Left(HttpErrorStatus(response.code.code, error))
    }
  }
}
```

## Batch Processing

```scala
import fs2.*

case class Order(id: Long, customerId: Long, amount: Double)

def streamOrders(orders: List[Order]): Stream[IO, Unit] =
  Stream.emits(orders)
    .metered(1.second)  // Rate limit: one per second
    .evalMap { order =>
      IO(
        basicRequest
          .post(uri"https://api.example.com/orders")
          .body(jsonEncoder[Order].apply(order))
          .send(backend)
      )
    }
    .compile
    .drain
```

## Parallel Requests

```scala
import sttp.client4.*
import scala.concurrent.{Future, ExecutionContext}

implicit val ec = ExecutionContext.global

val requests = List(
  basicRequest.get(uri"http://api.example.com/data1"),
  basicRequest.get(uri"http://api.example.com/data2"),
  basicRequest.get(uri"http://api.example.com/data3")
)

val responses: Future[List[Response[Either[String, String]]]] =
  Future.sequence(requests.map(_.send(backend)))
```

## Performance Optimization

### Connection Pooling

```scala
// Default backends handle connection pooling automatically
val backend = DefaultSyncBackend()

// For higher throughput, use Armeria
import sttp.client4.armeria.ArmeriaBackend
val armeriaBackend = ArmeriaBackend()
```

### Compression

```scala
// Gzip compression is enabled by default
val request = basicRequest.get(uri"http://example.com/api")

// Disable compression if needed
val noCompression = basicRequest
  .get(uri"http://example.com/api")
  .response(asString)
```

### Performance Tips

1. **Reuse backends** — create once, share across requests
2. **Use connection pooling** — built into all backends
3. **Enable compression** — default is enabled
4. **Use Armeria** — highest throughput backend option
5. **Set timeouts** — prevent hanging requests
6. **Consume streams fully** — avoid resource leaks
7. **Use async backends in async code** — never block with sync backends in `Future`/`IO`
