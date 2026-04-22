# Core Patterns — Routing, Controllers, Middleware, State

Complete reference for web framework core patterns across Play, Tapir, and ZIO-HTTP.

## Routing

### Play — Routes File

The routes file (`conf/routes`) maps HTTP methods + paths to controller actions.

```scala
# conf/routes

# Static path
GET   /                     controllers.HomeController.index()

# Path parameters (prefix with :)
GET   /users/:id            controllers.UserController.get(id: Long)

# Wildcard path (matches /)
GET   /files/*file          controllers.FileController.serve(file: String)

# Query parameters (in controller signature)
GET   /search               controllers.SearchController.search(q: String, page: Int ?= 1)

# RESTful CRUD
GET     /api/products       controllers.ProductController.list()
POST    /api/products       controllers.ProductController.create()
GET     /api/products/:id   controllers.ProductController.get(id: Long)
PUT     /api/products/:id   controllers.ProductController.update(id: Long)
DELETE  /api/products/:id   controllers.ProductController.delete(id: Long)
```

### Tapir — Typed Endpoint DSL

Endpoints are Scala values. Path segments, query params, headers, and bodies are all typed.

```scala
import sttp.tapir.*
import sttp.tapir.generic.auto.*

// Path parameters
val getUser = endpoint.get
  .in("api" / "users" / path[Long]("id"))
  .out(jsonBody[User])

// Query parameters
val searchUsers = endpoint.get
  .in("api" / "users" / "search")
  .in(query[String]("q"))
  .in(query[Option[Int]]("page"))       // optional
  .in(query[Int]("limit").default(20))   // with default
  .out(jsonBody[List[User]])

// Header parameters
val tracked = endpoint.get
  .in("api" / "resource")
  .in(header[String]("X-Request-Id"))
  .out(jsonBody[Resource])

// Capturing multiple path segments
val fileEndpoint = endpoint.get
  .in("files" / paths)
  .out(byteArrayBody)
```

### ZIO-HTTP — Pattern Matching

Routes are defined by pattern matching on `Method -> Path`.

```scala
import zio.http.*

val routes = Http.collectZIO[Request] {
  // Exact path
  case Method.GET -> Root / "api" / "health" =>
    ZIO.succeed(Response.text("OK"))

  // Path parameter
  case Method.GET -> Root / "api" / "users" / id =>
    getUser(id.toLong)

  // Query parameters
  case req @ Method.GET -> Root / "api" / "search" =>
    val q = req.url.queryParam("q").getOrElse("")
    val page = req.url.queryParam("page").flatMap(_.toIntOption).getOrElse(1)
    search(q, page)

  // POST with body
  case req @ Method.POST -> Root / "api" / "users" =>
    req.body.asString.map(parseAndCreate)
}

// Compose multiple route sets
val allRoutes = userRoutes ++ productRoutes ++ staticRoutes
```

## Controllers / Handler Logic

### Play — Controller Actions

Controllers extend `AbstractController` and use `Action` builders.

```scala
import javax.inject.Inject
import play.api.mvc._
import play.api.libs.json._
import scala.concurrent.Future
import scala.concurrent.ExecutionContext

case class CreateProduct(name: String, price: Double)
object CreateProduct { implicit val reads: Reads[CreateProduct] = Json.reads[CreateProduct] }

class ProductController @Inject() (cc: ControllerComponents)
  (implicit ec: ExecutionContext) extends AbstractController(cc) {

  // Simple action
  def index = Action {
    Ok("Hello")
  }

  // Action with path parameter
  def get(id: Long) = Action {
    Ok(s"Product $id")
  }

  // Async action
  def list = Action.async {
    productRepo.all().map(products => Ok(Json.toJson(products)))
  }

  // JSON body parsing
  def create() = Action.async(parse.json) { implicit request =>
    request.body.validate[CreateProduct].fold(
      errors => Future.successful(BadRequest(Json.obj("errors" -> JsError.toJson(errors)))),
      input  => productRepo.create(input).map(p => Created(Json.toJson(p)))
    )
  }

  // Async with error handling
  def safeGet(id: Long) = Action.async {
    productRepo.find(id).map {
      case Some(p) => Ok(Json.toJson(p))
      case None    => NotFound(s"Product $id not found")
    }.recover {
      case e: Exception => InternalServerError(e.getMessage)
    }
  }
}
```

### Tapir — Server Logic

Server logic is a function from input types to `Either[Error, Output]` wrapped in an effect.

```scala
import sttp.tapir.*
import sttp.tapir.server.ziohttp.ZioHttpServerInterpreter
import zio.*

// Server logic function
def createUserLogic(input: CreateUser): ZIO[UserRepo, String, User] =
  for {
    user <- ZIO.serviceWith[UserRepo](_.create(input))
  } yield user

// Wire endpoint to server logic
val createRoute = ZioHttpServerInterpreter().from(createUserEndpoint) { input =>
  createUserLogic(input).mapError(_.toString)
}.toRoutes

// Multiple endpoints to routes
val allRoutes = ZioHttpServerInterpreter().from(List(
  listUsersEndpoint  .serverLogic(_ => listUsersLogic),
  getUserEndpoint    .serverLogic(getUserLogic),
  createUserEndpoint .serverLogic(createUserLogic),
)).toRoutes
```

### ZIO-HTTP — Handler Functions

Handlers are ZIO effects returning `Response`.

```scala
import zio.http.*
import zio.json.*
import zio.json.JsonDecoder

case class CreateUser(name: String, price: Double)
object CreateUser { implicit val decoder: JsonDecoder[CreateUser] = DeriveJsonDecoder.gen }

val userHandler = Http.collectZIO[Request] {
  case Method.GET -> Root / "api" / "users" =>
    for {
      users <- UserRepo.all
    } yield Response.json(users.toJson)

  case Method.GET -> Root / "api" / "users" / id =>
    for {
      user <- UserRepo.find(id.toLong)
    } yield user match {
      case Some(u) => Response.json(u.toJson)
      case None    => Response.status(Status.NotFound)
    }

  case req @ Method.POST -> Root / "api" / "users" =>
    for {
      body   <- req.body.asString
      input  <- ZIO.fromEither(body.fromJson[CreateUser])
      user   <- UserRepo.create(input)
    } yield Response.json(user.toJson).status(Status.Created)
}
```

## Request / Response Handling

### Body Parsing

```scala
// Play — built-in body parsers
Action(parse.json)      // JSON body
Action(parse.text)      // Plain text
Action(parse.xml)       // XML body
Action(parse.formUrlEncoded)  // Form data
Action(parse.file(to))  // File upload
Action(parse.multipartFile)   // Multipart
Action(parse.empty)     // No body expected

// Tapir — typed body inputs
.in(jsonBody[User])           // JSON body with automatic codec
.in(stringBody)               // Plain text body
.in(byteArrayBody)            // Raw bytes
.in(multipartBody)            // Multipart form data
.in(formBody[FormData])       // URL-encoded form

// ZIO-HTTP — manual parsing from request
req.body.asString                    // String body
req.body.asArray                     // Byte array
req.body.asStream                    // Stream of bytes
body.fromJson[User]                  // ZIO-JSON parsing
```

### Response Construction

```scala
// Play — Result helpers
Ok("text")                                    // 200
Created(Json.toJson(obj))                     // 201
Accepted                                      // 202
NoContent                                     // 204
BadRequest(Json.obj("error" -> "bad"))        // 400
Unauthorized("auth required")                 // 401
Forbidden("denied")                           // 403
NotFound("not found")                         // 404
MethodNotAllowed                              // 405
InternalServerError("error")                  // 500
ServiceUnavailable("unavailable")             // 503

// Add headers
Ok("data").withHeaders("X-Custom" -> "value")
Ok("data").as(JSON)                           // Content-Type
Ok("data").withSession("key" -> "value")      // Session cookie
Redirect("/other")                            // 303 redirect

// Tapir — typed outputs
.out(jsonBody[User])                          // 200 JSON
.out(statusCode(Created).and(jsonBody[User])) // 201 JSON
.out(stringBody)                              // 200 text
.out(header("Location", "/users/123"))        // Header
.out(setCookie("session", "token"))           // Cookie

// ZIO-HTTP — Response construction
Response.text("hello")                        // 200 text/plain
Response.json("""{"ok":true}""")              // 200 application/json
Response.status(Status.NoContent)             // 204
Response.status(Status.NotFound)              // 404
Response.text("error").status(Status.BadRequest)  // 400 with body
Response.redirect(Root / "other")             // Redirect
Response.empty.copy(headers = Headers("X-Custom" -> "value"))
```

## Middleware

### Play Filters

Filters intercept every request. Register in `application.conf` or via module.

```scala
import javax.inject.Inject
import play.api.mvc.*
import play.api.streams.Accumulator
import org.apache.pekko.stream.Materializer
import scala.concurrent.ExecutionContext

class LoggingFilter @Inject() (implicit val mat: Materializer, ec: ExecutionContext)
  extends EssentialFilter {

  override def apply(next: EssentialAction): EssentialAction = EssentialAction { request =>
    val start = System.currentTimeMillis()
    next(request).map { result =>
      val duration = System.currentTimeMillis() - start
      println(s"[${request.method}] ${request.uri} -> ${result.header.status} (${duration}ms)")
      result.withHeaders("X-Response-Time" -> duration.toString)
    }
  }
}

// Register in application.conf
// play.filters.enabled += "filters.LoggingFilter"

// Action composition — per-action middleware
class AuthenticatedAction @Inject() (parser: BodyParsers.Default)
  (implicit ec: ExecutionContext) extends ActionBuilder[Request, AnyContent] {

  override def parser = parser
  override def invokeBlock[A](request: Request[A], block: Request[A] => Future[Result]) = {
    request.session.get("userId") match {
      case Some(_) => block(request)
      case None    => Future.successful(Unauthorized("Not authenticated"))
    }
  }
}
```

### Tapir Interceptors

```scala
import sttp.tapir.server.interceptor.*
import sttp.tapir.server.interceptor.log.DefaultServerLog

// Request logging
val loggingInterceptor = RequestInterceptor { (request, endpoints, handler) =>
  println(s"[${request.method}] ${request.uri}")
  handler(request)
}

// Custom interceptor
val corsInterceptor = RequestInterceptor { (request, endpoints, handler) =>
  handler(request).map(response =>
    response.withHeaders("Access-Control-Allow-Origin" -> "*")
  )
}

// Server options with interceptors
val serverOptions = ZioHttpServerOptions.customiseInterceptors
  .requestInterceptor(loggingInterceptor)
  .serverLog(DefaultServerLog[Unit]((msg, _) => println(msg)))
  .options
```

### ZIO-HTTP Middleware

Middleware composes via the `@@` operator.

```scala
import zio.http.*

// Built-in middleware
app @@ Middleware.debug                          // Request/response logging
app @@ Middleware.timeout(10.seconds)            // Timeout
app @@ Middleware.cors()                         // CORS
app @@ Middleware.addHeader("X-Server", "mine")  // Add response header

// Compose multiple middleware
val withMiddleware = app @@
  Middleware.debug @@
  Middleware.timeout(30.seconds) @@
  Middleware.cors()

// Custom middleware
val requestLogger = Middleware.intercept { (request, response) =>
  println(s"[${request.method}] ${request.url.path} -> ${response.status}")
}
```

## State Management

### Play — Request-Scoped State

Play controllers are singletons. Use DI for shared state, `Request` for per-request state.

```scala
// Shared state via DI
class CounterController @Inject() (cc: ControllerComponents, counter: AtomicCounter)
  extends AbstractController(cc) {

  def increment = Action {
    counter.increment()
    Ok(s"Count: ${counter.get()}")
  }
}

// AtomicCounter provided via DI module
class AtomicCounter {
  private val count = new java.util.concurrent.atomic.AtomicInteger(0)
  def increment(): Unit = count.incrementAndGet()
  def get(): Int = count.get()
}

// Module binding
class AppModule extends AbstractModule {
  override def configure() = bind(classOf[AtomicCounter]).asEagerSingleton()
}
```

### ZIO-HTTP — ZLayer State

```scala
import zio.*

case class AppState(counter: Ref[Int])

object AppState {
  val live: ZLayer[Any, Nothing, AppState] =
    ZLayer(Ref.make(0).map(AppState(_)))
}

val counterApp = Http.collectZIO[Request] {
  case Method.POST -> Root / "increment" =>
    for {
      state <- ZIO.service[AppState]
      _     <- state.counter.update(_ + 1)
      count <- state.counter.get
    } yield Response.text(s"Count: $count")
}

object Main extends ZIOAppDefault {
  def run = Server.serve(counterApp).provide(AppState.live, Server.default)
}
```

## API Versioning

```scala
// Play — route prefix
GET   /api/v1/users    controllers.v1.UserController.list()
GET   /api/v2/users    controllers.v2.UserController.list()

// Tapir — path segment
val v1Users = endpoint.get.in("api" / "v1" / "users").out(jsonBody[List[UserV1]])
val v2Users = endpoint.get.in("api" / "v2" / "users").out(jsonBody[List[UserV2]])

// ZIO-HTTP — pattern match on version
val versionedRoutes = Http.collectZIO[Request] {
  case Method.GET -> Root / "api" / "v1" / "users" => listUsersV1
  case Method.GET -> Root / "api" / "v2" / "users" => listUsersV2
}
```

## Error Handling

### Play

```scala
// Action-level error handling
def safeAction = Action.async {
  service.call().map(Ok(_)).recover {
    case e: NoSuchElementException => NotFound(e.getMessage)
    case e: IllegalArgumentException => BadRequest(e.getMessage)
    case e: Exception => InternalServerError(e.getMessage)
  }
}

// Global error handler
import play.api.http.HttpErrorHandler
import play.api.mvc.*

class ErrorHandler @Inject() extends HttpErrorHandler {
  def onClientError(request: RequestHeader, statusCode: Int, message: String) =
    Future.successful(Status(statusCode)(Json.obj("error" -> message)))

  def onServerError(request: RequestHeader, exception: Throwable) =
    Future.successful(InternalServerError(Json.obj("error" -> exception.getMessage)))
}
```

### Tapir — Typed Error Outputs

```scala
import sttp.tapir.*

// Union of error types
sealed trait ApiError
case class NotFoundError(message: String) extends ApiError
case class ValidationError(errors: List[String]) extends ApiError
case class UnauthorizedError(message: String) extends ApiError

val endpoint = endpoint.get
  .in("api" / "resource" / path[Long]("id"))
  .out(jsonBody[Resource])
  .errorOut(oneOf(
    oneOfVariant(statusCode(StatusCode.NotFound).and(jsonBody[NotFoundError])),
    oneOfVariant(statusCode(StatusCode.BadRequest).and(jsonBody[ValidationError])),
    oneOfVariant(statusCode(StatusCode.Unauthorized).and(jsonBody[UnauthorizedError])),
  ))
```

### ZIO-HTTP

```scala
// catchAll on the Http app
val safeApp = app.catchAll {
  case e: NoSuchElementException => Response.text(e.getMessage).status(Status.NotFound)
  case e: IllegalArgumentException => Response.text(e.getMessage).status(Status.BadRequest)
  case e: Exception => Response.text(e.getMessage).status(Status.InternalServerError)
}

// Map errors in individual handlers
val handler = Http.collectZIO[Request] {
  case Method.GET -> Root / "api" / "users" / id =>
    UserRepo.find(id.toLong)
      .map(_.fold(Response.status(Status.NotFound))(u => Response.json(u.toJson)))
      .catchAll(e => ZIO.succeed(Response.text(e.getMessage).status(Status.InternalServerError)))
}
```
