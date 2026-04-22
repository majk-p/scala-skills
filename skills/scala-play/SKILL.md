---
name: scala-play
description: Use this skill when working with Play Framework in Scala. Covers controllers, routing, JSON handling, form validation, database integration, custom filters, dependency injection, WebSocket handling, caching, error handling, and performance optimization. Trigger when the user mentions Play Framework, Play controllers, Play routes, or needs to build RESTful APIs or web applications with Scala and Play.
---

# Play Framework in Scala

Play Framework is a high-velocity web framework for building stateless, non-blocking, reactive applications in Scala. It features hot reloading, type-safe routing, and built-in dependency injection.

## Quick Start

### Minimal Controller

```scala
import javax.inject._
import play.api.mvc._

@Singleton
class HomeController @Inject()(val controllerComponents: ControllerComponents)
extends BaseController {
  def index: Action[AnyContent] = Action {
    Ok(views.html.index())
  }
}
```

### SBT Configuration

```scala
// build.sbt
scalaVersion := "3.3.0" // check for latest version

libraryDependencies ++= Seq(
  "com.typesafe.play" %% "play-slick" % "10.0.+",           // check for latest version
  "com.typesafe.play" %% "play-json" % "2.10.+",            // check for latest version
  "com.typesafe.play" %% "play-logback" % "3.1.+" % Test    // check for latest version
)
```

## Core Concepts

### Routing

Routes are defined in `conf/routes`:

```
GET     /                    controllers.HomeController.index
GET     /users/:id           controllers.UserController.getById(id: Long)
POST    /users               controllers.UserController.create
PUT     /users/:id           controllers.UserController.update(id: Long)
DELETE  /users/:id           controllers.UserController.delete(id: Long)
```

Or programmatically with `sird`:

```scala
import play.api.routing.sird._

object MyRouter extends play.api.routing.SimpleRouter {
  val prefix = "/api"
  def routes = {
    case GET(p"/users/$id") => controller.getUser(id)
    case POST(p"/users")    => controller.createUser
  }
}
```

### JSON Handling

```scala
import play.api.libs.json._

case class User(id: Long, name: String, email: String)

object User {
  implicit val userFormat: OFormat[User] = Json.format[User]
}

// In controller
def createUser: Action[JsValue] = Action(parse.json) { implicit request =>
  request.body.validate[User].fold(
    errors => BadRequest(Json.obj("error" -> errors)),
    user => Created(Json.obj("message" -> "User created", "id" -> user.id))
  )
}
```

### RESTful API Controller

```scala
import javax.inject._
import play.api.mvc._
import play.api.libs.json._
import scala.concurrent.{ExecutionContext, Future}

case class TodoItem(id: Long, title: String, completed: Boolean)
object TodoItem {
  implicit val format: OFormat[TodoItem] = Json.format[TodoItem]
}

@Singleton
class TodoController @Inject()(val controllerComponents: ControllerComponents)
(implicit ec: ExecutionContext) {

  private var todos: List[TodoItem] = List()

  def getAll: Action[AnyContent] = Action {
    Ok(Json.toJson(todos))
  }

  def getById(id: Long): Action[AnyContent] = Action {
    todos.find(_.id == id) match {
      case Some(todo) => Ok(Json.toJson(todo))
      case None       => NotFound
    }
  }

  def create: Action[JsValue] = Action(parse.json) { implicit request =>
    request.body.validate[TodoItem].fold(
      errors => BadRequest,
      todo => {
        val newItem = todo.copy(id = System.currentTimeMillis())
        todos = newItem :: todos
        Created(Json.toJson(newItem))
      }
    )
  }

  def delete(id: Long): Action[AnyContent] = Action {
    todos = todos.filter(_.id != id)
    NoContent
  }
}
```

### Database Integration with Slick

```scala
import slick.jdbc.H2Profile.api._

case class TodoItem(id: Long, title: String, completed: Boolean)

class TodoTable(tag: Tag) extends Table[TodoItem](tag, "todos") {
  def id        = column[Long]("id", O.PrimaryKey, O.AutoInc)
  def title     = column[String]("title")
  def completed = column[Boolean]("completed")
  def * = (id, title, completed) <> (TodoItem.tupled, TodoItem.unapply)
}

class TodoRepository @Inject()(protected val db: Database) {
  private val todos = TableQuery[TodoTable]
  def all: Future[List[TodoItem]]        = db.run(todos.to[List].result)
  def create(todo: TodoItem): Future[Long] = db.run((todos += todo).map(_.getOrElse(0L)))
}
```

## Common Patterns

### Error Handling

```scala
import play.api.mvc._
import play.api.libs.json._

// JSON error responses
def invocationException(ex: Exception): Result = ex match {
  case _: NotFoundException    => NotFound(Json.obj("error" -> "Not Found", "message" -> ex.getMessage))
  case _: BadRequestException  => BadRequest(Json.obj("error" -> "Bad Request", "message" -> ex.getMessage))
  case _: ConflictException    => Conflict(Json.obj("error" -> "Conflict", "message" -> ex.getMessage))
  case _                       => InternalServerError(Json.obj("error" -> "Internal Server Error", "message" -> ex.getMessage))
}
```

### Custom Filters (Middleware)

```scala
import javax.inject._
import play.api.mvc._
import scala.concurrent.{ExecutionContext, Future}

@Singleton
class AuthenticationFilter @Inject()(
  val controllerComponents: ControllerComponents
)(implicit ec: ExecutionContext) extends EssentialFilter {

  override def apply(next: RequestHeader => Future[Result])
    (request: RequestHeader): Future[Result] = {
    val apiKey = request.headers.get("X-API-Key")

    apiKey match {
      case Some(key) if isValidKey(key) => next(request)
      case _ => Future.successful(
        Unauthorized(Json.obj("error" -> "Unauthorized", "message" -> "Invalid or missing API key"))
      )
    }
  }

  private def isValidKey(key: String): Boolean = key == "valid-api-key-123"
}
```

### Dependency Injection

Play uses JSR-330 (`@Inject`) with Guice by default:

```scala
import javax.inject._
import play.api.mvc._
import play.api.Configuration

@Singleton
class AppConfig @Inject()(config: Configuration) {
  val appName: String = config.get[String]("app.name")
}

@Singleton
class AppController @Inject()(
  appConfig: AppConfig,
  val controllerComponents: ControllerComponents
) extends BaseController {
  def index: Action[AnyContent] = Action {
    Ok(s"Welcome to ${appConfig.appName}")
  }
}
```

For manual DI, define a custom module:

```scala
import play.api._

class CustomModule extends Module {
  def bindings(env: Environment, config: Configuration, context: Environment.Context) = Seq(
    bind[CustomService].to[CustomServiceImpl]
  )
}

trait CustomService {
  def doSomething(): String
}

class CustomServiceImpl extends CustomService {
  def doSomething(): String = "Custom service implementation"
}
```

### WebSocket Handling

```scala
import javax.inject._
import play.api.mvc._
import play.api.libs.streams._
import akka.actor.typed.scaladsl.Behaviors
import akka.actor.typed.{ActorRef, Behavior}

@Singleton
class WebSocketController @Inject()(
  val controllerComponents: ControllerComponents
) {
  def ws = WebSocket.accept[String, String] { request =>
    ActorFlow.actorRef { out => ChatActor(out) }
  }
}

object ChatActor {
  def apply(out: ActorRef[String]): Behavior[String] = Behaviors.setup { context =>
    Behaviors.receiveMessage {
      case text =>
        out ! s"Echo: $text"
        Behaviors.same
    }
  }
}
```

### Caching

```scala
import javax.inject._
import play.api.mvc._
import play.api.cache._
import scala.concurrent.duration._

@Singleton
class CacheController @Inject()(
  val controllerComponents: ControllerComponents,
  cacheApi: AsyncCacheApi
) extends BaseController {

  def getCachedData(key: String): Action[AnyContent] = Action.async {
    cacheApi.get[JsValue](key).map {
      case Some(data) => Ok(data)
      case None       => NotFound
    }
  }

  def setCachedData(key: String): Action[JsValue] = Action(parse.json) { implicit request =>
    cacheApi.set(key, request.body, 10.minutes)
    Ok(Json.obj("message" -> "Data cached"))
  }
}
```

### Cats Effect Integration

```scala
import javax.inject._
import play.api.mvc._
import cats.effect._
import scala.concurrent.{ExecutionContext, Future}

@Singleton
class CatsPlayController @Inject()(
  val controllerComponents: ControllerComponents
)(implicit ec: ExecutionContext) {

  def getData: Action[AnyContent] = Action.async {
    val io = IO.fromFuture(IO(Future("Hello from Cats Effect")))
    io.map(Ok(_)).unsafeToFuture()
  }
}
```

## Performance Tips

1. **Connection Pooling**: Configure database connection pools appropriately
2. **Caching**: Use Play's cache module to reduce database queries
3. **Eager Loading**: Prevent N+1 queries
4. **Async Processing**: Keep operations asynchronous for maximum throughput
5. **Gzip Compression**: Enable compression for responses
6. **Cache-Control Headers**: Set proper caching headers

## Common Pitfalls

1. **Blocking in Controllers**: Play is non-blocking — avoid blocking calls or wrap them in `IO.blocking`
2. **Unclosed Resources**: Always close database connections and resources
3. **Missing Error Handlers**: Implement proper error handling for all endpoints
4. **Route Registration**: Ensure routes are properly registered in `conf/routes`
5. **Type Safety**: Use Play's type-safe routing to catch errors at compile time

## Dependencies

```scala
// Core Play — check for latest version
libraryDependencies ++= Seq(
  "com.typesafe.play" %% "play-slick" % "10.0.+",
  "com.typesafe.play" %% "play-json" % "2.10.+",
  "com.typesafe.play" %% "play-logback" % "3.1.+" % Test
)

// Database evolutions
libraryDependencies += "com.typesafe.play" %% "play-slick-evolutions" % "10.0.+"
```

## Related Skills

- **scala-web-frameworks** — general web framework patterns in Scala
- **scala-json-circe** — when using Circe instead of Play-JSON
- **scala-di** — dependency injection patterns

## References

Load these when you need exhaustive details or patterns not shown above:

- **references/basics.md** — Controllers, routing, JSON handling, form validation, database integration patterns
- **references/advanced.md** — Custom filters, DI modules, WebSocket handling, caching strategies, error handling, performance optimization
