# Play Framework — Advanced Reference

Deeper patterns for filters, DI modules, WebSockets, caching, error handling, security, and performance.
Complements the main `SKILL.md` which covers the essentials.

## Filter Chain and Registration

### Registering Filters

```scala
import javax.inject._
import play.api.http.HttpFilters
import play.api.mvc.EssentialFilter

// Default filter registration
@Singleton
class Filters @Inject()(
  corsFilter: CORSFilter,
  loggingFilter: LoggingFilter,
  gzipFilter: GzipFilter
) extends HttpFilters {
  def filters: Seq[EssentialFilter] = Seq(corsFilter, loggingFilter, gzipFilter)
}
```

### Request Logging Filter

```scala
import javax.inject._
import play.api.mvc._
import play.api.Logger
import scala.concurrent.{ExecutionContext, Future}

@Singleton
class LoggingFilter @Inject()(implicit ec: ExecutionContext) extends EssentialFilter {

  private val logger = Logger(getClass)

  override def apply(next: RequestHeader => Future[Result])
    (request: RequestHeader): Future[Result] = {
    val startTime = System.currentTimeMillis()

    next(request).map { result =>
      val duration = System.currentTimeMillis() - startTime
      logger.info(s"${request.method} ${request.uri} -> ${result.header.status} (${duration}ms)")
      result.withHeaders("X-Response-Time" -> s"${duration}ms")
    }
  }
}
```

### Rate Limiting Filter

```scala
import javax.inject._
import play.api.mvc._
import scala.concurrent.{ExecutionContext, Future}
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Singleton
class RateLimitFilter @Inject()(implicit ec: ExecutionContext) extends EssentialFilter {

  private val requestCounts = new ConcurrentHashMap[String, AtomicLong]()
  private val MaxRequests = 100L
  private val WindowMs = 60_000L

  override def apply(next: RequestHeader => Future[Result])
    (request: RequestHeader): Future[Result] = {
    val clientIp = request.remoteAddress
    val counter = requestCounts.computeIfAbsent(clientIp, _ => new AtomicLong(0))

    if (counter.incrementAndGet() > MaxRequests) {
      Future.successful(TooManyRequests(Json.obj("error" -> "Rate limit exceeded")))
    } else {
      next(request)
    }
  }
}
```

### CORS Filter Configuration

```hocon
# application.conf
play.filters.cors {
  allowedOrigins = ["https://example.com", "https://app.example.com"]
  allowedHttpMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  allowedHttpHeaders = ["Accept", "Content-Type", "Authorization", "X-API-Key"]
  preflightMaxAge = 3 days
}
```

## Advanced Dependency Injection

### Module with Eager and Lazy Bindings

```scala
import play.api._
import javax.inject._

class AppModule extends Module {
  def bindings(env: Environment, config: Configuration, context: Environment.Context) = Seq(
    // Lazy — created when first injected
    bind[UserService].to[UserServiceImpl],
    bind[EmailService].to[EmailServiceImpl],

    // Eager — created at application startup
    bind[StartupHook].toSelf.eagerly()
  )
}

// Provider for complex construction
class DatabaseProvider @Inject()(config: Configuration) extends Provider[Database] {
  def get(): Database = {
    val url = config.get[String]("db.url")
    Database.forUrl(url)
  }
}

// Register provider
class DbModule extends Module {
  def bindings(env: Environment, config: Configuration, context: Environment.Context) = Seq(
    bind[Database].toProvider[DatabaseProvider]
  )
}
```

### Register Modules in application.conf

```hoconf
# application.conf
play.modules.enabled += "modules.AppModule"
play.modules.enabled += "modules.DbModule"

# Disable a built-in module
play.modules.disabled += "play.api.db.DBModule"
```

## WebSocket — Typed Actor Patterns

### Multi-User Chat Room

```scala
import javax.inject._
import play.api.mvc._
import play.api.libs.streams._
import akka.actor.typed.scaladsl.Behaviors
import akka.actor.typed.{ActorRef, Behavior}
import akka.stream.{Materializer, OverflowStrategy}

@Singleton
class ChatController @Inject()(
  val controllerComponents: ControllerComponents
)(implicit mat: Materializer) {

  private val roomActor = ActorSystem(ChatRoom(), "chat-room")

  def socket = WebSocket.accept[String, String] { request =>
    ActorFlow.actorRef { out =>
      ChatUser(out, roomActor)
    }
  }
}

object ChatRoom {
  sealed trait Command
  case class Join(user: ActorRef[ChatUser.Event]) extends Command
  case class Message(text: String, from: ActorRef[ChatUser.Event]) extends Command
  case class Leave(user: ActorRef[ChatUser.Event]) extends Command

  def apply(): Behavior[Command] = Behaviors.setup { context =>
    var users: Set[ActorRef[ChatUser.Event]] = Set.empty

    Behaviors.receiveMessage {
      case Join(user) =>
        users += user
        users.foreach(_ ! ChatUser.Event(s"User joined. Total: ${users.size}"))
        Behaviors.same

      case Message(text, from) =>
        users.foreach(_ ! ChatUser.Event(text))
        Behaviors.same

      case Leave(user) =>
        users -= user
        Behaviors.same
    }
  }
}

object ChatUser {
  sealed trait Event
  case class Event(text: String) extends Event

  def apply(out: ActorRef[String], room: ActorRef[ChatRoom.Command]): Behavior[Event] =
    Behaviors.setup { context =>
      room ! ChatRoom.Join(context.self)
      Behaviors.receiveMessage {
        case Event(text) =>
          out ! text
          Behaviors.same
      }
    }
}
```

## Advanced Caching

### Cache Patterns

```scala
import javax.inject._
import play.api.cache.AsyncCacheApi
import play.api.mvc._
import scala.concurrent.duration._
import scala.concurrent.{ExecutionContext, Future}

@Singleton
class CachedService @Inject()(cacheApi: AsyncCacheApi)(implicit ec: ExecutionContext) {

  // Get-or-set pattern
  def getUser(id: Long): Future[User] = {
    cacheApi.getOrElseUpdate[User](s"user:$id")(ttl = 30.minutes) {
      // Only called on cache miss
      fetchUserFromDb(id)
    }
  }

  // Invalidate
  def updateUser(user: User): Future[Unit] = {
    saveToDb(user).map { _ =>
      cacheApi.remove(s"user:${user.id}")
    }
  }

  private def fetchUserFromDb(id: Long): Future[User] = ???
  private def saveToDb(user: User): Future[Unit] = ???
}
```

### Cache Configuration

```hocon
# application.conf
play.cache {
  bindCaches = ["user-cache", "api-cache"]
  caffeine {
    defaults {
      maximumSize = 1000
      expireAfterWrite = 30m
    }
    caches {
      user-cache {
        maximumSize = 500
        expireAfterWrite = 1h
      }
    }
  }
}
```

### Named Cache Injection

```scala
import javax.inject._
import play.api.cache.{AsyncCacheApi, NamedCache}

@Singleton
class UserController @Inject()(
  @NamedCache("user-cache") userCache: AsyncCacheApi
)(implicit ec: ExecutionContext) {
  def getUser(id: Long): Future[User] =
    userCache.getOrElseUpdate(s"user:$id")(fetchUser(id))
}
```

## Error Handler Customization

### Global HTTP Error Handler

```scala
import javax.inject._
import play.api.http.HttpErrorHandler
import play.api.mvc._
import play.api.libs.json._
import scala.concurrent.{ExecutionContext, Future}

@Singleton
class AppErrorHandler @Inject()(implicit ec: ExecutionContext) extends HttpErrorHandler {

  def onClientError(request: RequestHeader, statusCode: Int, message: String): Future[Result] = {
    Future.successful(Status(statusCode)(Json.obj(
      "error" -> message,
      "status" -> statusCode,
      "path" -> request.path
    )))
  }

  def onServerError(request: RequestHeader, exception: Throwable): Future[Result] = {
    Future.successful(InternalServerError(Json.obj(
      "error" -> "Internal Server Error",
      "message" -> exception.getMessage,
      "path" -> request.path
    )))
  }
}
```

### Register Error Handler

```hocon
# application.conf
play.http.errorHandler = "handlers.AppErrorHandler"
```

## Security

### Security Headers Filter

```hocon
# application.conf
play.filters.headers {
  contentSecurityPolicy = "default-src 'self'; script-src 'self'"
  contentTypeOptions = "nosniff"
  frameOptions = "DENY"
  xssProtection = "1; mode=block"
  permittedCrossDomainPolicies = "master-only"
  referrerPolicy = "strict-origin-when-cross-origin"
}
```

### Allowed Hosts Filter

```hocon
# application.conf
play.filters.hosts {
  allowed = ["example.com", ".example.com", "localhost:9000"]
}
```

## Performance Configuration

### Server, Gzip, and Connection Pool Tuning

```hocon
# application.conf
play.server {
  provider = "play.core.server.AkkaHttpServerProvider"
  akka.http.server {
    max-content-length = 10m
    request-timeout = 30s
    idle-timeout = 60s
  }
}

play.filters.gzip {
  contentType.whiteList = ["text/*", "application/json", "application/javascript"]
  bufferSize = 8192
}

slick.dbs.default.db {
  connectionPool = "HikariCP"
  numThreads = 20
  maxConnections = 30
  minConnections = 5
  connectionTimeout = 30s
}
```

## Deployment — Docker

```dockerfile
# Multi-stage Dockerfile for Play
FROM sbtscala/scala-sbt as build  # check for latest version
WORKDIR /app
COPY . .
RUN sbt dist

FROM eclipse-temurin:17-jre-alpine  # check for latest version
WORKDIR /app
COPY --from=build /app/target/universal/*.zip .
RUN unzip *.zip && rm *.zip && mv dist/* app-dist
EXPOSE 9000
ENTRYPOINT ["./app-dist/bin/application"]
```
