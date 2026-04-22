# Frameworks Overview — Play, Tapir, ZIO-HTTP

Detailed comparison of Scala's three dominant web frameworks, their architectures, ecosystems, and when to choose each.

## Play Framework

### Architecture

Play follows a traditional MVC (Model-View-Controller) architecture. It is a full-stack framework providing everything from HTTP routing to template rendering to database integration.

**Core components:**
- **Router** — maps HTTP requests to controller actions via a routes file (`conf/routes`)
- **Controllers** — handle requests, return results via `Action` builders
- **Templates** — Twirl template engine for server-side HTML rendering
- **Filters** — request/response interceptors for cross-cutting concerns
- **Dependency Injection** — Guice (default) or compile-time DI

**Request lifecycle:**
1. HTTP request arrives at the server
2. Router matches the request to a controller action
3. Action parses the request body (if any)
4. Action executes business logic
5. Action returns a `Result` (status + headers + body)
6. Filters can intercept at any stage

### When to Choose Play

- **Full-stack web applications** with server-side rendering and templates
- **Teams familiar with MVC** from other ecosystems (Rails, Django, Spring)
- **Java/Scala hybrid teams** — Play supports both languages
- **Rapid prototyping** — hot-reload, built-in dev server, scaffolding
- **Large plugin ecosystem** — authentication, DB migrations, caching, WebSockets

### When to Avoid Play

- **Pure REST APIs** with no server-side rendering — Tapir or ZIO-HTTP are leaner
- **Purely functional codebase** — Play is Future-based, not effect-polymorphic
- **Minimal dependency requirements** — Play brings a lot of transitive dependencies
- **Compile-time safety on routes** — Play routes are strings, not type-checked

### Key Dependencies

- `play` — core framework
- `play-guice` — Guice DI integration
- `play-json` — built-in JSON library
- `play-slick` — Slick database integration
- `play-ahc-ws` — async HTTP client

### Play Directory Structure

```
app/
  controllers/        # Controller classes
  models/             # Domain models
  views/              # Twirl templates
  services/           # Business logic
conf/
  application.conf    # Configuration
  routes              # Route definitions
  db/migration/       # Database migrations
public/               # Static assets
test/                 # Test suites
build.sbt             # Build configuration
```

## Tapir

### Architecture

Tapir treats HTTP endpoints as **typed Scala values**. Each endpoint is a value describing inputs, outputs, and error outputs as types. These values are then interpreted by different backends.

**Core components:**
- **Endpoints** — typed descriptions of HTTP endpoints as values
- **Server interpreters** — convert endpoints to server routes (Netty, http4s, ZIO-HTTP, etc.)
- **Client interpreters** — convert endpoints to sttp client requests
- **Documentation interpreters** — generate OpenAPI/Swagger from endpoints

**Endpoint structure:**
```
Endpoint[SECURITY_INPUT, INPUT, ERROR_OUTPUT, OUTPUT, CAPABILITIES]
```

Each part is a type — inputs (path, query, header, body), outputs (status code, headers, body), and errors are all compile-time checked.

### When to Choose Tapir

- **Type-safe REST APIs** — compile-time checking of all inputs and outputs
- **Automatic documentation** — OpenAPI/Swagger generated from endpoint definitions
- **Multiple server backends** — swap Netty, http4s, ZIO-HTTP without changing endpoint logic
- **Client generation** — same endpoint definitions produce both server routes and client calls
- **Microservices** — consistent API contracts across services

### When to Avoid Tapir

- **Server-side rendering** — Tapir is API-focused, no template engine
- **Convention over configuration** — requires explicit endpoint definitions
- **Simple CRUD apps** — the type safety overhead may not justify itself for trivial apps

### Key Dependencies

- `tapir-core` — endpoint DSL
- `tapir-json-circe` — circe JSON codec integration (also available: play-json, zio-json, uPickle)
- `tapir-netty-server` — Netty server backend
- `tapir-zio-http-server` — ZIO-HTTP server backend
- `tapir-http4s-server` — http4s server backend
- `tapir-openapi-docs` — OpenAPI documentation generation
- `tapir-sttp-client` — sttp client interpreter

### Tapir Endpoint DSL

```scala
import sttp.tapir.*

// Basic structure: endpoint.method.in(path).in(body).out(response).errorOut(error)
val getUser =
  endpoint.get
    .in("api" / "users" / path[Long]("id"))   // path parameter
    .in(query[Option[String]]("fields"))        // optional query parameter
    .in(header[Option[String]]("X-Request-Id")) // optional header
    .out(jsonBody[User])                        // success response
    .errorOut(jsonBody[ApiError])               // error response
```

## ZIO-HTTP

### Architecture

ZIO-HTTP is a composable HTTP library built natively on ZIO. Routes are defined via pattern matching on HTTP method + path, and handlers return ZIO effects.

**Core components:**
- **Http** — composable request handler (pattern matching on method + path)
- **Middleware** — composable via `@@` operator
- **Server** — Netty-based server with ZIO integration
- **Response** — typed response construction

### When to Choose ZIO-HTTP

- **ZIO-native applications** — seamless integration with ZIO effects, layers, and fibers
- **Composable routing** — pattern-matching routes compose naturally via `++`
- **High concurrency** — ZIO's fiber-based concurrency model
- **Both client and server** — single library for both directions

### When to Avoid ZIO-HTTP

- **Cats Effect ecosystem** — use http4s or Tapir with http4s backend instead
- **Non-ZIO applications** — adds ZIO as a heavy dependency if not already used
- **Need Play features** — no templates, no built-in DB integration, no hot-reload

### Key Dependencies

- `zio-http` — HTTP server/client
- `zio` — ZIO core
- `zio-json` — JSON library for ZIO

## Migration Between Frameworks

### From Play to Tapir

1. Extract route definitions into Tapir endpoint values
2. Move controller logic into Tapir server logic functions
3. Replace Play-JSON with circe (or use `tapir-json-play`)
4. Replace Guice DI with manual wiring or Macwire
5. Replace Twirl templates with a frontend SPA (if applicable)

### From Play to ZIO-HTTP

1. Convert controllers to ZIO-HTTP pattern-matching handlers
2. Replace `Future` with `ZIO` throughout
3. Replace Guice DI with ZLayer
4. Replace Play-JSON with zio-json
5. Rewrite route definitions as pattern-match cases

### From Tapir to ZIO-HTTP (or vice versa)

Tapir endpoints can be served by ZIO-HTTP via the `tapir-zio-http-server` interpreter. This means you can use Tapir's type-safe endpoint DSL with ZIO-HTTP as the server backend, getting the best of both worlds.

## Ecosystem Integration

| Concern | Play | Tapir | ZIO-HTTP |
|---------|------|-------|----------|
| **JSON** | Play-JSON | Circe, Play-JSON, zio-json, uPickle | zio-json |
| **Database** | Slick, JDBC | Any (agnostic) | ZIO SQL, Quill |
| **Streaming** | Akka Streams | fs2, ZIO Streams | ZIO Streams |
| **Observability** | Play Filters | OpenTelemetry interceptors | ZIO Telemetry |
| **Testing** | Play Test, Mockito | ScalaTest, MUnit | ZIO Test |
| **Config** | HOCON (application.conf) | Any (agnostic) | ZIO Config |

## Performance Characteristics

- **Play** — good throughput for full-stack apps; overhead from DI and template engine
- **Tapir** — excellent throughput on Netty backend; minimal overhead from endpoint interpretation
- **ZIO-HTTP** — excellent throughput; benefits from ZIO's fiber-based scheduling

All three frameworks run on Netty as the underlying HTTP server and handle production workloads well.
