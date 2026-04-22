# STTP API Reference

Complete STTP API reference covering request definition, response handling, URI construction, headers, authentication, backends, JSON integration, and timeout configuration. Load this when you need exhaustive API details beyond the main skill.

## Table of Contents

- [Request Definition](#request-definition)
- [HTTP Methods](#http-methods)
- [URI Construction](#uri-construction)
- [Headers](#headers)
- [Response Handling](#response-handling)
- [Authentication](#authentication)
- [Backend Selection](#backend-selection)
- [JSON Integration](#json-integration)
- [Timeout Configuration](#timeout-configuration)
- [Testing](#testing)

---

## Request Definition

### Initial Request Builders

```scala
import sttp.client4.*

// basicRequest - reads response as Either[String, String]
// Left = HTTP error (4xx, 5xx), Right = success (2xx)
val request1: PartialRequest[Either[String, String]] = basicRequest.get(uri"...")

// quickRequest - reads response as String always (simpler for scripts)
val request2: Request[String] = quickRequest.get(uri"...")

// Request - type-safe with configurable response
val request3: Request[T] = request.get(uri"...").response(asJson[MyData])
```

### Request Body Types

```scala
import sttp.client4.*

// String body (Content-Type inferred or set explicitly)
basicRequest.post(uri"...").body("plain text")

// JSON string body
basicRequest.post(uri"...").body("""{"key": "value"}""")

// Form data (Map)
basicRequest.post(uri"...").body(Map("key" -> "value", "foo" -> "bar"))

// Binary body
basicRequest.post(uri"...").body(Array(0x01, 0x02, 0x03))

// No body (GET, DELETE)
basicRequest.get(uri"...")  // no body needed
```

## HTTP Methods

```scala
basicRequest.get(uri"https://api.example.com/data")
basicRequest.post(uri"https://api.example.com/data")
basicRequest.put(uri"https://api.example.com/data/1")
basicRequest.delete(uri"https://api.example.com/data/1")
basicRequest.head(uri"https://api.example.com/data/1")
basicRequest.patch(uri"https://api.example.com/data/1")
basicRequest.options(uri"https://api.example.com/api")
```

## URI Construction

```scala
import sttp.client4.*

// String interpolation (auto-URL encoding)
val uri1 = uri"https://api.example.com/users/123"
val uri2 = uri"http://example.com/search?q=$query"

// Path segments
val uri3 = uri"http://example.com/api" / "users" / "123"

// Query parameters
val uri4 = uri"http://example.com/search"
  .addParam("q", "scala")
  .addParams("page" -> "1", "limit" -> "10")

// Fragments
val uri5 = uri"http://example.com/docs#section1"

// Optional query parameters (automatically removed if None)
val sort: Option[String] = Some("stars")
val uri6 = uri"https://api.github.com/search/repositories?q=$query&sort=$sort"
```

## Headers

```scala
import sttp.client4.*

// Single header
basicRequest
  .get(uri"https://api.example.com")
  .header("Authorization", "Bearer token")

// Multiple headers
basicRequest
  .get(uri"https://api.example.com")
  .header("Authorization", "Bearer token")
  .header("User-Agent", "MyApp/1.0")
  .header("Accept", "application/json")

// Convenience methods
import sttp.client4.headers.*

basicRequest
  .get(uri"https://api.example.com")
  .contentType("application/json")
  .accept("application/json")
  .userAgent("MyApp/1.0")
  .authorization("Bearer token")
```

## Response Handling

### Response Type

```scala
trait Response[T] {
  def code: StatusCode           // HTTP status code
  def headers: Seq[Header]       // Response headers
  def body: T                    // Parsed body (type depends on response spec)
  def history: Option[Response[_]]  // Redirect history
}

// StatusCode helpers
response.code.code          // Int: 200, 404, etc.
response.code.info          // String: "OK", "Not Found", etc.
response.code.isSuccess     // Boolean: 2xx
response.code.isRedirect    // Boolean: 3xx
response.code.isClientError // Boolean: 4xx
response.code.isServerError // Boolean: 5xx
```

### Response Body Deserialization

```scala
import sttp.client4.*

// Default: Either[String, String]
val response1 = basicRequest.get(uri"...").send(backend)
response1.body match {
  case Right(successBody) => // 2xx response
  case Left(errorMessage) => // 4xx/5xx or deserialization error
}

// As string always (no Either wrapper)
val request2 = quickRequest.get(uri"...")

// As string with metadata
val request3 = basicRequest
  .get(uri"https://api.example.com/data")
  .response(asString)

// Fail fast on non-2xx
import sttp.client4.ResponseAs.*
val request4 = basicRequest
  .get(uri"https://api.example.com/data")
  .response(asStringOrFail)

// As JSON (Circe)
import sttp.client4.circe.*
val request5 = basicRequest
  .get(uri"https://api.example.com/user")
  .response(asJson[User])

// As binary
val request6 = basicRequest
  .get(uri"https://example.com/file")
  .response(asByteArray)

// Ignore response body
val request7 = basicRequest
  .get(uri"https://example.com/ping")
  .response(ignore)
```

## Authentication

### Basic Auth

```scala
val authRequest = basicRequest
  .get(uri"https://example.com/protected")
  .auth.basic("username", "password")
```

### Bearer Token

```scala
val tokenRequest = basicRequest
  .get(uri"https://api.example.com/data")
  .auth.bearer("your-bearer-token")
```

### Custom Header Auth

```scala
val customAuthRequest = basicRequest
  .get(uri"https://api.example.com/data")
  .header("X-API-Key", "secret-key")
```

### OAuth2 Client Credentials

```scala
import sttp.client4.*
import sttp.oauth2.*

val tokenRequest = basicRequest
  .post(uri"https://oauth2.example.com/token")
  .body("grant_type=client_credentials&client_id=id&client_secret=secret")
  .send(backend)

val apiRequest = basicRequest
  .get(uri"https://api.example.com/resource")
  .auth.oauth2.bearer("access-token")
```

### OAuth2 Authorization Code

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

## Backend Selection

### Synchronous Backends

```scala
import sttp.client4.*

// Default sync (uses Java HttpClient)
val syncBackend: SttpBackend[Identity] = DefaultSyncBackend()

// HttpURLConnection
val backend2: SttpBackend[Identity] = HttpURLConnectionBackend()

// OkHttp
val backend3: SttpBackend[Identity] = OkHttpBackend()
```

### Future-Based Backend

```scala
import scala.concurrent.ExecutionContext

val futureBackend: SttpBackend[Future] = DefaultFutureBackend()(global)
```

### Cats Effect Backend

```scala
import cats.effect.IO
import sttp.client4.httpclient.fs2.HttpClientFs2Backend

val catsBackend: Resource[IO, SttpBackend[IO]] = HttpClientFs2Backend.resource[IO]()
```

### ZIO Backend

```scala
import zio.*
import sttp.client4.httpclient.zio.HttpClientZioBackend

val zioBackend: ZLayer[Any, Throwable, SttpBackend[Task]] = HttpClientZioBackend.layer()
```

### Fs2 Backend

```scala
import cats.effect.IO
import sttp.client4.wrappers.fs2.*

val fs2Backend: Resource[IO, SttpBackend[IO]] = Fs2Backend.resource[IO]()
```

### Armeria (High Performance)

```scala
import sttp.client4.armeria.ArmeriaBackend

val armeriaBackend: SttpBackend[Identity] = ArmeriaBackend()
```

## JSON Integration

### Circe

```scala
import sttp.client4.circe.*
import io.circe.generic.auto.*

case class User(id: Int, name: String, email: String)

implicit val userDecoder = jsonOf[User]
implicit val userEncoder = jsonEncoder[User]

// Send JSON
val request1 = basicRequest
  .post(uri"https://api.example.com/users")
  .body(jsonEncoder[User].apply(User(1, "Alice", "alice@example.com")))

// Receive JSON
val request2 = basicRequest
  .get(uri"https://api.example.com/user")
  .response(asJson[User])
```

### uPickle

```scala
import sttp.client4.upicklejson.default.*
import upickle.default.*

case class User(id: Int, name: String, age: Int)

val request1 = basicRequest
  .post(uri"https://api.example.com/users")
  .body(write(User(1, "Alice", 30)))

val request2 = basicRequest
  .get(uri"https://api.example.com/user")
  .response(asJson[User])
```

### JSON4s

```scala
import sttp.client4.json4s.*
import org.json4s.DefaultFormats

implicit val formats = DefaultFormats

val jsonBody = JsonDSL("name" -> "Alice", "age" -> 30)

val request = basicRequest
  .post(uri"https://api.example.com/users")
  .body(jsonBody)
```

## Timeout Configuration

```scala
import scala.concurrent.duration.*

// Per-request timeout
val request = basicRequest
  .get(uri"http://example.com/api")
  .readTimeout(5.seconds)

// Backend-level: follow redirects with global timeout
val backend = DefaultSyncBackend()
val timeoutBackend = FollowRedirectsBackend(
  backend,
  maxRedirects = 5,
  Sensitivity.AutoRedirect,
  timeout = 10.seconds
)
```

## Testing

```scala
import sttp.client4.*
import sttp.client4.testing.*

val stubBackend: SttpBackend[Identity] = SttpBackendStub()

stubBackend.whenRequestMatches(
  basicRequest.get(uri"https://api.example.com/data")
).thenRespondOk("""{"id": 1, "name": "Test Data"}""")
```
