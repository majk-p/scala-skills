---
name: scala-web-frameworks
description: Use this skill when building web applications or APIs in Scala. Covers Play Framework, Tapir, and ZIO-HTTP for routing, controllers, request/response handling, middleware, authentication, JSON serialization, error handling, and server setup. Trigger when the user mentions web development, REST API, HTTP server, backend, routes, controllers, endpoints, middleware, or needs to build any web service in Scala — even if they don't explicitly name the framework.
---

# Web Frameworks in Scala

Scala has three dominant approaches to web development: **Play Framework** (full-stack MVC), **Tapir** (type-safe endpoint descriptions with automatic documentation), and **ZIO-HTTP** (ZIO-native composable HTTP). All three handle routing, request/response, middleware, and JSON — but differ radically in philosophy and API style.

This skill covers all three. When the user's codebase uses one, focus on that framework. When the choice is open, recommend based on project needs: Play for full-stack apps, Tapir for type-safe APIs with docs, ZIO-HTTP for ZIO-native services.

## Quick Start

### Play Framework

```scala
// conf/routes
GET   /hello              controllers.HomeController.hello(name: String)
POST  /api/users          controllers.UserController.create()

// app/controllers/HomeController.scala
package controllers

import javax.inject.Inject
import play.api.mvc._

class HomeController @Inject() (cc: ControllerComponents) extends AbstractController(cc) {
  def hello(name: String) = Action {
    Ok(s"Hello, $name!")
  }
}
```

### Tapir

```scala
import sttp.tapir.*
import sttp.tapir.generic.auto.*
import sttp.tapir.json.circe.*
import io.circe.generic.auto.*

case class User(name: String, email: String)

// Type-safe endpoint — input, error, output all encoded in types
val createUser: PublicEndpoint[User, String, User, Any] =
  endpoint.post
    .in("api" / "users")
    .in(jsonBody[User])
    .errorOut(stringBody)
    .out(jsonBody[User])

// Generate OpenAPI docs from endpoint definitions
import sttp.apispec.openapi.circe.yaml.*
import sttp.tapir.docs.openapi.OpenAPIDocsInterpreter

val docs = OpenAPIDocsInterpreter().toOpenAPI(createUser, "My API", "1.0")
println(docs.toYaml)
```

### ZIO-HTTP

```scala
import zio.*
import zio.http.*

val app = Http.collectZIO[Request] {
  case Method.GET -> Root / "hello" / name =>
    ZIO.succeed(Response.text(s"Hello, $name!"))
}

object Main extends ZIOAppDefault {
  def run = Server.serve(app).provide(Server.default)
}
```

## Framework Comparison

| Aspect | Play | Tapir | ZIO-HTTP |
|--------|------|-------|----------|
| **Style** | Full-stack MVC | Endpoint-as-values | ZIO-native composable |
| **Routing** | Routes file + controllers | Typed endpoint DSL | Pattern matching |
| **JSON** | Play-JSON (built-in) | Circe / other via interpreter | ZIO-JSON |
| **DI** | Guice / compile-time DI | Manual or Macwire | ZLayer |
| **Docs** | Manual or plugins | Auto OpenAPI/Swagger | Manual |
| **Backends** | Netty / Akka HTTP | Netty, http4s, ZIO, etc. | Netty |
| **Effect System** | Future-based | Agnostic (ZIO, IO, Future) | ZIO only |

### When to Use Each

**Play** — full-stack web apps with server-side rendering, MVC architecture, built-in features (templates, caching, DB migrations, hot-reload). Ideal for Java/Scala hybrid teams and applications needing a large plugin ecosystem.

**Tapir** — type-safe REST APIs where input/output types are checked at compile time. Endpoints are values that generate both server routes and OpenAPI documentation. Supports multiple server backends. Ideal for microservices.

**ZIO-HTTP** — services already committed to ZIO. Provides composable routing via pattern matching, ZLayer-based dependency injection, and seamless ZIO effect integration. Avoid if using cats-effect.

## Core Patterns

### Routing

```scala
// Play — routes file (conf/routes)
GET     /api/users           controllers.UserController.list()
GET     /api/users/:id       controllers.UserController.get(id: Long)
POST    /api/users           controllers.UserController.create()
PUT     /api/users/:id       controllers.UserController.update(id: Long)
DELETE  /api/users/:id       controllers.UserController.delete(id: Long)

// Tapir — typed endpoints
val listUsers: PublicEndpoint[Unit, Unit, List[User], Any] =
  endpoint.get.in("api" / "users").out(jsonBody[List[User]])

val getUser: PublicEndpoint[Long, String, User, Any] =
  endpoint.get.in("api" / "users" / path[Long]("id")).out(jsonBody[User])

// ZIO-HTTP — pattern matching
val routes = Http.collectZIO[Request] {
  case Method.GET -> Root / "api" / "users"      => listUsers
  case Method.GET -> Root / "api" / "users" / id => getUser(id.toLong)
}
```

### Controllers / Endpoint Logic

```scala
// Play controller
class UserController @Inject() (cc: ControllerComponents, userRepo: UserRepository)
  extends AbstractController(cc) {

  def list = Action.async {
    userRepo.all().map(users => Ok(Json.toJson(users)))
  }

  def get(id: Long) = Action.async {
    userRepo.find(id).map {
      case Some(user) => Ok(Json.toJson(user))
      case None       => NotFound(s"User $id not found")
    }
  }

  def create() = Action.async(parse.json) { implicit request =>
    request.body.validate[CreateUser].fold(
      errors => Future.successful(BadRequest(Json.obj("errors" -> JsError.toJson(errors)))),
      user   => userRepo.create(user).map(created => Created(Json.toJson(created)))
    )
  }
}

// Tapir server logic
import sttp.tapir.server.ziohttp.ZioHttpServerInterpreter

val userRoutes = ZioHttpServerInterpreter().from(createUser) { user =>
  userRepo.create(user).map(Right(_))
      .catchAll(e => ZIO.left(e.getMessage))
}.toRoutes
```

### Request / Response Handling

```scala
// Play — body parsing
def createJson = Action(parse.json) { implicit request =>
  request.body.validate[User] match {
    case JsSuccess(user)    => Created(Json.toJson(user))
    case JsError(errors)    => BadRequest(Json.obj("errors" -> JsError.toJson(errors)))
  }
}

// Play — response helpers
Ok("text")                                    // 200 text/plain
Ok(Json.toJson(obj))                          // 200 application/json
Created(Json.toJson(obj))                     // 201
NoContent                                     // 204
BadRequest(Json.obj("error" -> "invalid"))    // 400
Unauthorized("auth required")                 // 401
Forbidden("access denied")                    // 403
NotFound("not found")                         // 404
InternalServerError("oops")                   // 500

// Tapir — typed inputs/outputs
val endpoint = endpoint.post
  .in("api" / "users")
  .in(jsonBody[CreateUser])                   // request body
  .out(statusCode(Created).and(jsonBody[User]))  // 201 response
  .errorOut(statusCode(BadRequest).and(jsonBody[ErrorInfo]))  // error response
```

### Middleware

```scala
// Play — filter-based middleware
class LoggingFilter @Inject() (implicit val mat: Materializer) extends EssentialFilter {
  override def apply(next: EssentialAction): EssentialAction = EssentialAction { request =>
    val start = System.currentTimeMillis()
    next(request).map { result =>
      val duration = System.currentTimeMillis() - start
      result.withHeaders("X-Response-Time" -> duration.toString)
    }
  }
}

// Tapir — interceptors
import sttp.tapir.server.interceptor.*

val loggingInterceptor = RequestInterceptor { request =>
  println(s"[${request.method}] ${request.uri}")
  request
}

// ZIO-HTTP — middleware via @@
val appWithMiddleware = app @@ Middleware.debug @@ Middleware.timeout(10.seconds)
```

### Session & Auth

```scala
// Play — session
def login = Action { implicit request =>
  Ok("Welcome").withSession("userId" -> "123")
}

def profile = Action { implicit request =>
  request.session.get("userId")
    .map(id => Ok(s"User: $id"))
    .getOrElse(Unauthorized("Not logged in"))
}

// Tapir — security endpoints
import sttp.tapir.*

val secureEndpoint = endpoint
  .securityIn(auth.bearer[String]())
  .in("api" / "profile")
  .out(jsonBody[UserProfile])

// ZIO-HTTP — header-based auth
val authed = Http.collectZIO[Request] {
  case req @ Method.GET -> Root / "profile" =>
    req.header(Header.Authorization) match {
      case Some(Header.Authorization.Bearer(token)) => handleAuth(token)
      case _ => ZIO.succeed(Response.status(Status.Unauthorized))
    }
}
```

## Advanced Patterns

### RESTful API Design

```scala
// Play — RESTful resource controller
class ResourceController @Inject() (cc: ControllerComponents) extends AbstractController(cc) {
  def list(page: Int, limit: Int) = Action {
    Ok(Json.obj("page" -> page, "limit" -> limit, "data" -> Json.toJson(items)))
  }
  def get(id: Long) = Action { /* ... */ }
  def create() = Action(parse.json) { /* ... */ }
  def update(id: Long) = Action(parse.json) { /* ... */ }
  def delete(id: Long) = Action { NoContent }
}

// Tapir — composed REST endpoints
val apiEndpoints = List(listUsers, getUser, createUser, updateUser, deleteUser)
  .map(_.tag("Users").in("api" / "v1"))

// ZIO-HTTP — REST routes
val restApi = Http.collectZIO[Request] {
  case Method.GET    -> Root / "api" / "users"      => listUsers
  case Method.GET    -> Root / "api" / "users" / id => getUser(id.toLong)
  case Method.POST   -> Root / "api" / "users"      => createUser
  case Method.PUT    -> Root / "api" / "users" / id => updateUser(id.toLong)
  case Method.DELETE -> Root / "api" / "users" / id => deleteUser(id.toLong)
}
```

### Error Handling

```scala
// Play — recover from failures
def safeAction(f: => Future[Result]): Future[Result] =
  f.recover { case e: Exception =>
    InternalServerError(Json.obj("error" -> e.getMessage))
  }

// Tapir — typed error outputs
val endpoint = endpoint
  .errorOut(oneOf(
    oneOfVariant(statusCode(NotFound).and(jsonBody[NotFoundError])),
    oneOfVariant(statusCode(BadRequest).and(jsonBody[ValidationError])),
    oneOfDefaultVariant(statusCode(InternalServerError).and(stringBody))
  ))

// ZIO-HTTP — catchAll
val safeApp = app.catchAll { case e: Exception =>
  Response.text(e.getMessage).status(Status.InternalServerError)
}
```

### Content Negotiation

```scala
// Play
def resource = Action { implicit request =>
  request.headers.get("Accept") match {
    case Some("application/json") => Ok(Json.toJson(data)).as(JSON)
    case Some("text/html")        => Ok(views.html.resource(data))
    case _                        => Ok(Json.toJson(data)).as(JSON)
  }
}

// Tapir — multiple output encodings
val endpoint = endpoint.get
  .in("resource")
  .out(jsonBody[Data])
  .out(header("Content-Type", "application/json"))
```

## Dependencies

```scala
// Play Framework — check for latest version
libraryDependencies ++= Seq(
  "org.playframework" %% "play" % "latest.integration",
  "org.playframework" %% "play-guice" % "latest.integration",
  "org.playframework" %% "play-json" % "latest.integration"
)

// Tapir — check for latest version
libraryDependencies ++= Seq(
  "com.softwaremill.sttp.tapir" %% "tapir-core" % "latest.integration",
  "com.softwaremill.sttp.tapir" %% "tapir-json-circe" % "latest.integration",
  "com.softwaremill.sttp.tapir" %% "tapir-netty-server" % "latest.integration",
  "com.softwaremill.sttp.tapir" %% "tapir-openapi-docs" % "latest.integration",
  "io.circe" %% "circe-generic" % "latest.integration"
)

// ZIO-HTTP — check for latest version
libraryDependencies ++= Seq(
  "dev.zio" %% "zio-http" % "latest.integration",
  "dev.zio" %% "zio" % "latest.integration",
  "dev.zio" %% "zio-json" % "latest.integration"
)
```

## Related Skills

- **scala-play** — deep dive into Play Framework: DI, templates, WebSockets, caching, advanced configuration
- **scala-http-clients** — HTTP client patterns with sttp for consuming external APIs
- **scala-json-circe** — JSON encoding/decoding with circe for API serialization
- **scala-async-effects** — ZIO and cats-effect patterns used in async web handlers

## References

Load these when you need exhaustive details or patterns not shown above:

- **references/frameworks-overview.md** — Detailed framework comparison: Play vs Tapir vs ZIO-HTTP, when to use each, architecture patterns, ecosystem integration, migration between frameworks
- **references/core-patterns.md** — Complete reference for routing, controllers, request/response handling, body parsing, middleware, session management, state management, API versioning, and error handling across all three frameworks
