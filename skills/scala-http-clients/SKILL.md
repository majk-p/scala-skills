---
name: scala-http-clients
description: Use this skill when making HTTP requests in Scala using STTP. Covers GET/POST/PUT/DELETE, request/response handling, authentication (Basic, Bearer, OAuth2), JSON integration with Circe, error handling, retries, streaming with fs2, multipart uploads, WebSocket communication, connection pooling, and backend selection (sync, cats-effect, ZIO, Armeria). Trigger when the user mentions HTTP client, REST API, HTTP request, STTP, API call, web request, fetch, download, upload, or needs to interact with any HTTP endpoint in a Scala codebase — even if they don't explicitly name the library.
---

# HTTP Clients in Scala with STTP

**STTP** is the primary typed HTTP client for Scala. It provides a clean, type-safe API for defining requests and handling responses, with backend implementations for every effect system: synchronous `Identity`, `Future`, cats-effect `IO`, ZIO `Task`, and streaming via fs2. It supports JSON codecs (Circe, uPickle, JSON4s), multipart uploads, WebSockets, and resiliency patterns (retry, circuit breaker).

This skill covers the full STTP API from basic CRUD to production patterns like streaming and OAuth2.

## Quick Start

### Synchronous

```scala
import sttp.client4.*

val backend = DefaultSyncBackend()
val response = basicRequest
  .get(uri"http://example.com/api/users")
  .send(backend)

response.body match {
  case Right(body) => println(body)
  case Left(error) => println(s"Error: $error")
}
```

### Cats Effect

```scala
import cats.effect.*
import sttp.client4.*
import sttp.client4.httpclient.fs2.HttpClientFs2Backend

object Main extends IOApp.Simple {
  val run: IO[Unit] =
    HttpClientFs2Backend.resource[IO]().use { backend =>
      basicRequest
        .get(uri"http://example.com/api")
        .send(backend)
        .flatMap(resp => IO.println(resp.body))
    }
}
```

## Core Concepts

### Request Definition

STTP uses immutable request builders. Start with `basicRequest`, chain method calls, and send with a backend.

```scala
import sttp.client4.*

// basicRequest → Either[String, String] response (Left = error, Right = success)
val request = basicRequest
  .get(uri"https://api.example.com/data")
  .header("Accept", "application/json")
  .readTimeout(5.seconds)

// quickRequest → plain String response (simpler for scripts)
val quick = quickRequest.get(uri"https://api.example.com/data")
```

### HTTP Methods

```scala
basicRequest.get(uri"https://api.example.com/data")
basicRequest.post(uri"https://api.example.com/data")
basicRequest.put(uri"https://api.example.com/data/1")
basicRequest.delete(uri"https://api.example.com/data/1")
basicRequest.patch(uri"https://api.example.com/data/1")
basicRequest.head(uri"https://api.example.com/data/1")
basicRequest.options(uri"https://api.example.com/api")
```

### Request Bodies

```scala
// String body
basicRequest.post(uri"...").body("plain text")

// JSON string
basicRequest.post(uri"...").body("""{"name": "Alice"}""")

// Form data
basicRequest.post(uri"...").body(Map("key" -> "value"))

// Binary
basicRequest.post(uri"...").body(Array(0x01, 0x02))

// JSON with Circe
import sttp.client4.circe.*
basicRequest.post(uri"...").body(jsonEncoder[User].apply(user))
```

### URI Construction

```scala
import sttp.client4.*

// Interpolation (auto URL-encoding)
val u1 = uri"https://api.example.com/users/$id"

// Path segments
val u2 = uri"http://example.com/api" / "users" / "123"

// Query parameters
val u3 = uri"http://example.com/search".addParam("q", "scala").addParams("page" -> "1")

// Optional params (removed when None)
val sort: Option[String] = Some("stars")
val u4 = uri"https://api.github.com/search?q=$query&sort=$sort"
```

### Response Handling

```scala
import sttp.client4.*

// Default: Either[String, String]
val response = basicRequest.get(uri"...").send(backend)
response.body match {
  case Right(body) => // success (2xx)
  case Left(error) => // error (4xx/5xx)
}

// Status code inspection
response.code.isSuccess     // 2xx
response.code.isClientError // 4xx
response.code.isServerError // 5xx

// JSON deserialization (Circe)
import sttp.client4.circe.*
val userResponse = basicRequest
  .get(uri"https://api.example.com/user/1")
  .response(asJson[User])
  .send(backend)

// Fail fast on non-2xx
import sttp.client4.ResponseAs.*
basicRequest.get(uri"...").response(asStringOrFail)

// Binary response
basicRequest.get(uri"...").response(asByteArray)

// Ignore body
basicRequest.get(uri"...").response(ignore)
```

### Backends

The backend handles connection management. Choose based on your effect system. **Always reuse backends** — never create one per request.

```scala
// Synchronous (Java HttpClient)
val syncBackend = DefaultSyncBackend()

// Future-based
val futureBackend = DefaultFutureBackend()(ExecutionContext.global)

// Cats Effect (fs2)
val ceBackend: Resource[IO, SttpBackend[IO]] = HttpClientFs2Backend.resource[IO]()

// ZIO
val zioBackend: ZLayer[Any, Throwable, SttpBackend[Task]] = HttpClientZioBackend.layer()

// High performance (Armeria)
val armeriaBackend = ArmeriaBackend()
```

## Common Patterns

### Authentication

```scala
// Basic Auth
basicRequest.get(uri"...").auth.basic("user", "pass")

// Bearer Token
basicRequest.get(uri"...").auth.bearer("token")

// API Key
basicRequest.get(uri"...").header("X-API-Key", "key")
```

### Error Handling

```scala
// Status-based dispatch
response.body match {
  case Right(body) => handleSuccess(body)
  case Left(error) if response.code.isServerError => retryOrFail(error)
  case Left(error) => handleClientError(error)
}

// Custom error types
sealed trait HttpError
case class HttpErrorStatus(code: Int, message: String) extends HttpError
case class HttpErrorParsing(message: String) extends HttpError

def getUser(id: Long): Either[HttpError, User] =
  basicRequest.get(uri"https://api.example.com/user/$id").send(backend).body match {
    case Right(json) =>
      io.circe.parser.decode[User](json)
        .left.map(err => HttpErrorParsing(err.message))
    case Left(error) =>
      Left(HttpErrorStatus(response.code.code, error))
  }
```

### Retries

```scala
import sttp.client4.wrappers.retryingBackend.*
import scala.concurrent.duration.*

val retryBackend = RetryingBackend(
  backend,
  maxRetries = 3,
  retryPolicy = RetryPolicy.whenShouldRetry(
    RetryPolicy.Defaults.Backoff.exponentialBackoff[Fibonacci](baseDelay = 500.millis)
  )
)
```

### JSON with Circe

```scala
import sttp.client4.circe.*
import io.circe.generic.auto.*

case class User(id: Int, name: String, email: String)

// Decode response
val user = basicRequest
  .get(uri"https://api.example.com/user")
  .response(asJson[User])
  .send(backend)

// Encode request body
val created = basicRequest
  .post(uri"https://api.example.com/users")
  .body(jsonEncoder[User].apply(User(1, "Alice", "a@b.com")))
  .send(backend)
```

## Advanced Patterns

### Streaming with fs2

```scala
import sttp.client4.*
import sttp.client4.fs2.*
import fs2.*

// Stream response body
val streamRequest = basicRequest
  .get(uri"https://example.com/large-file")
  .response(asStream[IO, Byte])

streamRequest.send(backend).body match {
  case Right(stream) =>
    stream
      .through(fs2.text.utf8Decode)
      .through(fs2.text.lines)
      .take(1000)
      .compile
      .toList
}

// Stream to file
stream.through(fs2.io.file.writeAll[IO](Paths.get("output.bin"))).compile.drain
```

### OAuth2

```scala
import sttp.oauth2.*

// Client credentials
val tokenReq = basicRequest
  .post(uri"https://oauth2.example.com/token")
  .body("grant_type=client_credentials&client_id=id&client_secret=secret")

// Use token
val apiReq = basicRequest
  .get(uri"https://api.example.com/resource")
  .auth.oauth2.bearer("access-token")

// Authorization code
basicRequest.get(uri"https://example.com/authorize")
  .auth.oauth2.AuthorizationCodeRequest(
    clientId = "client-id",
    redirectUri = uri"https://your-app.com/callback",
    scope = Some("read write"),
    state = Some("csrf-token")
  )

// Refresh token
basicRequest.post(uri"https://oauth2.example.com/token")
  .body("grant_type=refresh_token&refresh_token=token_value")
```

### Multipart Uploads

```scala
// Single file
basicRequest.post(uri"https://example.com/upload")
  .multipartBody(BasicFileBody(new java.io.File("data.txt")))

// Multiple parts with metadata
basicRequest.post(uri"https://example.com/upload")
  .multipartBody(
    BasicFileBody(new java.io.File("file1.txt")),
    BasicFileBody(new java.io.File("file2.txt")),
    BasicStringBody("description", "Two files")
  )

// Custom content type and filename
basicRequest.post(uri"https://example.com/upload")
  .multipartBody(
    BasicFileBody(
      new java.io.File("data.csv"),
      contentType = Some("text/csv"),
      fileName = Some("upload.csv")
    )
  )
```

### WebSocket

```scala
import sttp.client4.ws.*

val wsRequest = basicRequest
  .get(uri"wss://echo.websocket.org")
  .response(asWebSocketAlways[IO])

wsRequest.send(backend).body match {
  case Right(ws) =>
    for {
      _   <- ws.sendText("Hello")
      msg <- ws.receiveText()
    } yield println(s"Received: $msg")
}
```

### Batch Processing with Rate Limiting

```scala
def processBatch(orders: List[Order]): Stream[IO, Unit] =
  Stream.emits(orders)
    .metered(1.second)
    .evalMap { order =>
      IO(basicRequest
        .post(uri"https://api.example.com/orders")
        .body(jsonEncoder[Order].apply(order))
        .send(backend))
    }
```

## Common Pitfalls

```scala
// ❌ Creating backend per request (resource leak)
def fetch(id: Int) = {
  val backend = DefaultSyncBackend()  // WRONG
  basicRequest.get(uri"http://api/users/$id").send(backend)
}

// ✅ Reuse backend
val backend = DefaultSyncBackend()
def fetch(id: Int) = basicRequest.get(uri"http://api/users/$id").send(backend)

// ❌ Blocking with sync backend in async code
def asyncFetch = Future {
  val backend = DefaultSyncBackend()  // WRONG - blocks thread
  basicRequest.get(uri"http://api").send(backend)
}

// ✅ Use async backend
val backend = HttpClientFs2Backend.resource[IO]()
def asyncFetch = backend.use(b => basicRequest.get(uri"http://api").send(b))

// ❌ Missing Content-Type for JSON
basicRequest.post(uri"...").body("""{"key": "value"}""")  // WRONG

// ✅ Set Content-Type
basicRequest.post(uri"...").contentType("application/json").body("""{"key": "value"}""")
```

## Dependencies

```scala
// Core STTP client — check for latest version
libraryDependencies += "com.softwaremill.sttp.client4" %% "core" % "4.0.+"

// JSON with Circe
libraryDependencies += "com.softwaremill.sttp.client4" %% "circe" % "4.0.+"

// JSON with uPickle
libraryDependencies += "com.softwaremill.sttp.client4" %% "upickle" % "4.0.+"

// Cats Effect / fs2 backend
libraryDependencies += "com.softwaremill.sttp.client4" %% "httpclient-fs2" % "4.0.+"

// ZIO backend
libraryDependencies += "com.softwaremill.sttp.client4" %% "httpclient-zio" % "4.0.+"

// Armeria backend (high performance)
libraryDependencies += "com.softwaremill.sttp.client4" %% "armeria" % "4.0.+"
```

## Related Skills

- **scala-web-frameworks** — for building the server side that STTP talks to
- **scala-json-circe** — for Circe codec details used in JSON request/response handling
- **scala-async-effects** — for cats-effect IO/ZIO patterns used with async backends

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/sttp-reference.md** — Complete STTP API reference: all HTTP methods, URI construction, headers, response types, authentication options, backend selection for every effect system, JSON integration (Circe, uPickle, JSON4s), timeout configuration, testing with stub backends
- **references/advanced.md** — Streaming responses with fs2, OAuth2 flows (client credentials, authorization code, refresh token), multipart uploads, WebSocket communication, retry strategies with exponential backoff, circuit breaking, custom error types, batch processing with rate limiting, parallel requests, performance optimization tips
