# Dependency Injection - Complete Reference

## Macwire Complete Reference

### Core Macros

#### wire[] - Context-Dependent Wiring

The `wire[]` macro generates code to create an instance of the given type, using values from the enclosing scope for constructor parameters.

**Signature:**
```scala
def wire[T]: T
```

**Resolution Order:**
1. Values in enclosing block/method arguments
2. Values/defs in enclosing type
3. Values in parent types (via inheritance)

**Example:**
```scala
class Database()
class Service(db: Database)

trait AppModule {
  lazy val db = wire[Database]
  lazy val service = wire[Service]
  // Generates: lazy val service = new Service(db)
}
```

#### wireRec[] - Recursive Wiring

Creates instances and automatically creates missing dependencies recursively.

**Signature:**
```scala
def wireRec[T]: T
```

**Example:**
```scala
class Database()
class SecurityFilter()
class UserFinder(db: Database, filter: SecurityFilter)
class UserStatusReader(finder: UserFinder)

trait AppModule {
  lazy val reader = wireRec[UserStatusReader]
  // Generates:
  // lazy val reader = new UserStatusReader(
  //   new UserFinder(new Database(), new SecurityFilter())
  // )
}
```

#### autowire[] - Context-Free Wiring

Creates instances without relying on enclosing context. Accepts parameters for customizing dependency resolution.

**Signature:**
```scala
def autowire[T](dependencies: Any*): T
```

**Parameters:**
- Instance: Use this specific instance when a dependency of that type is needed
- Factory function: Function that creates the dependency
- `classOf[T]`: Specify which class to instantiate for trait/interface
- `autowireMembersOf(instance)`: Use members of an instance as dependencies

**Examples:**

```scala
// Provide custom instance
val customDb = new Database("custom-connection")
val service = autowire[Service](customDb)

// Provide factory
def createService(db: Database, adminOnly: Boolean) = new Service(db, adminOnly)
val service = autowire[Service](createService _)

// Specify implementation
trait Database
class DatabaseImpl() extends Database
autowire[Service](classOf[DatabaseImpl])

// Use members of instance
class ConfigModule {
  val db = new Database()
}
val config = new ConfigModule()
autowire[Service](autowireMembersOf(config))
```

**Error Conditions:**
- Circular dependency detected
- Duplicate dependencies provided
- Primitive or String used as dependency (use opaque types instead)
- Cannot find constructor or apply method

#### wireSet[] - Multi-Instance Collection

Collects all instances of a given type from context and returns as a `Set`.

**Signature:**
```scala
def wireSet[T]: Set[T]
```

**Example:**
```scala
trait Handler
class UserHandler extends Handler
class OrderHandler extends Handler

trait App {
  lazy val userHandler = new UserHandler
  lazy val orderHandler = new OrderHandler
  lazy val handlers = wireSet[Handler]  // Set[UserHandler, OrderHandler]
}
```

#### wireList[] - Ordered Multi-Instance Collection (Scala 3)

Collects all instances of a given type from context and returns as a `List`, preserving order.

**Signature:**
```scala
def wireList[T]: List[T]
```

**Example:**
```scala
trait Handler
class UserHandler extends Handler
class OrderHandler extends Handler

trait App {
  lazy val userHandler = new UserHandler
  lazy val orderHandler = new OrderHandler
  lazy val handlers = wireList[Handler]  // List[UserHandler, OrderHandler] (preserves order)
}
```

### Factory Methods

#### wireWith[] - Use Factory Method Instead of Constructor

Wires an object using a factory method instead of the constructor.

**Signature:**
```scala
def wireWith[T](factory: (Dependencies) => T): T
```

**Example:**
```scala
class A()
class C(a: A, specialValue: Int)
object C {
  def create(a: A): C = new C(a, 42)
}

trait MyModule {
  lazy val a = wire[A]
  lazy val c = wireWith(C.create _)
  // Generates: lazy val c = C.create(a)
}
```

### Module Composition

#### Inheritance

```scala
trait DatabaseModule {
  lazy val db = wire[Database]
}

trait AuthModule {
  lazy val authService = wire[AuthService]
}

// Combine via inheritance
trait AppModule extends DatabaseModule with AuthModule {
  lazy val app = wire[Application]
}
```

#### Composition with Imports

```scala
class FacebookAccess(userFinder: UserFinder)

class UserModule {
  lazy val userFinder = wire[UserFinder]
}

class SocialModule(userModule: UserModule) {
  import userModule._
  lazy val facebookAccess = wire[FacebookAccess]
}
```

#### @Module Annotation (Avoid Imports)

Add `"com.softwaremill.macwire" %% "util" % "2.6.7"` to dependencies.

```scala
import com.softwaremill.macwire.util.Module

@Module
class UserModule {
  lazy val userFinder = wire[UserFinder]
}

class SocialModule(userModule: UserModule) {
  // No import needed - @Module automatically used
  lazy val facebookAccess = wire[FacebookAccess]
}
```

### Scoping

#### Built-in Scopes

```scala
trait WebModule {
  // Singleton - one instance
  lazy val userService: UserService = wire[UserService]

  // Dependent - new instance per usage
  def requestService: RequestService = wire[RequestService]
}
```

#### Custom Scopes

Add `"com.softwaremill.macwire" %% "proxy" % "2.6.7"` to dependencies.

```scala
import com.softwaremill.macwire._

trait Scope {
  def apply[T](value: => T): T
  def get[T]: T
}

// Thread-local scope
import com.softwaremill.macwire.proxy.ThreadLocalScope

trait WebModule {
  lazy val requestScope: Scope = new ThreadLocalScope

  lazy val loggedInUser = requestScope(new LoggedInUser)
}
```

### Akka Integration

Add `"com.softwaremill.macwire" %% "macrosakka" % "2.6.7" % "provided"`.

```scala
import akka.actor.{Actor, ActorSystem}
import com.softwaremill.macwire._
import com.softwaremill.macwire.akkasupport._

class DatabaseAccess()
class SecurityFilter()

class UserFinderActor(
  databaseAccess: DatabaseAccess,
  securityFilter: SecurityFilter
) extends Actor {
  def receive: Receive = { case _ => }
}

trait AkkaModule {
  lazy val databaseAccess = wire[DatabaseAccess]
  lazy val securityFilter = wire[SecurityFilter]

  lazy val system = ActorSystem("actor-system")

  // Wire actor - creates ActorRef
  lazy val userFinder = wireActor[UserFinderActor]("userFinder")

  // Wire anonymous actor
  lazy val anonymousActor = wireAnonymousActor[UserFinderActor]

  // Wire Props
  lazy val userFinderProps = wireProps[UserFinderActor]
}

// Using factory functions
object UserFinderActor {
  def get(databaseAccess: DatabaseAccess): UserFinderActor =
    new UserFinderActor(databaseAccess, new SecurityFilter())
}

lazy val userFinder = wireActorWith(UserFinderActor.get _)("userFinder")
```

### Qualifiers for Multiple ActorRefs

```scala
import com.softwaremill.macwire.Tagging._

sealed trait DatabaseAccess
sealed trait SecurityFilter

class DatabaseAccessActor extends Actor
class SecurityFilterActor extends Actor

val db: ActorRef @@ DatabaseAccess =
  wireActor[DatabaseAccessActor]("db").taggedWith[DatabaseAccess]
val filter: ActorRef @@ SecurityFilter =
  wireActor[SecurityFilterActor]("filter").taggedWith[SecurityFilter]

class UserFinderActor(
  databaseAccess: ActorRef @@ DatabaseAccess,
  securityFilter: ActorRef @@ SecurityFilter
) extends Actor
```

### Interceptors

```scala
import com.softwaremill.macwire._

class DatabaseAccess() {
  def query(): String = "result"
}

trait DatabaseInterceptor extends Interceptor[DatabaseAccess] {
  def intercept[T](target: DatabaseAccess)(f: DatabaseAccess => T): T = {
    println("Before")
    try f(target)
    finally println("After")
  }
}

trait AppModule {
  lazy val db = new DatabaseAccess
  lazy val interceptedDb = intercepted(db)(new DatabaseInterceptor {})
}
```

### Qualifiers

```scala
import com.softwaremill.macwire.Tagging._

// Define marker traits
sealed trait Production
sealed trait Test

// Tag instances
val db: Database @@ Production = new Database().taggedWith[Production]

// Use in wiring
class Service(db: Database @@ Production)
val service = wire[Service]
```

### Accessing Instances Dynamically

Add `"com.softwaremill.macwire" %% "util" % "2.6.7"`.

```scala
import com.softwaremill.macwire._

class MyApp {
  lazy val db = new Database
  lazy val service = wire[Service]
}

val wired = wiredInModule(new MyApp)

// Lookup by class
val db: Database = wired.lookup(classOf[Database])

// Lookup by interface
val service: MyService = wired.lookup(classOf[MyService])

// Wire class by name
val instance: AnyRef = wired.wireClassInstanceByName("com.example.Plugin")

// Register instances/instance factories
wired.registerInstance(new CustomComponent)
wired.registerFactory(classOf[FactoryComponent], createFactory _)
```

### Testing with Macwire

```scala
trait UserModule {
  lazy val db = wire[Database]
  lazy val service = wire[UserService]
}

// Test with mock
trait TestModule extends UserModule {
  override lazy val db = new MockDatabase()
}

// Test with real dependencies
class UserServiceSpec extends AnyFlatSpec with Matchers {
  "UserService" should "work" in {
    val module = new UserModule {}
    val service = module.service
    service.method() shouldEqual "expected"
  }
}
```

### Type Ascriptions

When referencing wired values within the same trait, use type ascriptions to help the type-checker:

```scala
class A()
class B(a: A)

trait Module {
  // Explicit type to avoid recursive type errors
  lazy val theA: A = wire[A]
  lazy val theB = new B(theA)
}
```

## Play-Guice Complete Reference

### Annotations

#### @Inject

Marks constructors, fields, or methods for injection.

**Constructor Injection (Recommended):**
```scala
import javax.inject._

class MyService @Inject() (db: Database, cache: Cache) {
  // Dependencies injected via constructor
}
```

**Field Injection (Use Carefully):**
```scala
import com.google.inject.Inject

class BaseController {
  @Inject
  protected var counter: Counter = _
}
```

**Method Injection:**
```scala
class MyService {
  @Inject
  def setLogger(logger: Logger): Unit = {
    this.logger = logger
  }
}
```

#### @Singleton

Marks a class to have a single instance per application.

```scala
import javax.inject._

@Singleton
class CacheService {
  private var cache = Map.empty[String, String]

  def get(key: String): Option[String] = cache.get(key)
  def put(key: String, value: String): Unit = cache += (key -> value)
}
```

#### @ImplementedBy

Specifies default implementation for a trait/interface.

```scala
import com.google.inject.ImplementedBy

@ImplementedBy(classOf[EnglishHello])
trait Hello {
  def sayHello(name: String): String
}

class EnglishHello extends Hello {
  def sayHello(name: String): String = s"Hello $name"
}

// Usage: injected directly as EnglishHello
```

#### @Named

Qualifies bindings for multiple instances of the same type.

```scala
import com.google.inject.name.Named
import javax.inject._

class PaymentService @Inject() (
  @Named("credit") creditProcessor: PaymentProcessor,
  @Named("debit") debitProcessor: PaymentProcessor
)
```

### Module Configuration

#### Basic Module

```scala
import com.google.inject.AbstractModule

class Module extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[Database]).to(classOf[RealDatabase])
    bind(classOf[Cache]).to(classOf[RedisCache])
  }
}
```

#### Qualified Bindings

```scala
import com.google.inject.name.Names

class Module extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[PaymentProcessor])
      .annotatedWith(Names.named("credit"))
      .to(classOf[CreditProcessor])

    bind(classOf[PaymentProcessor])
      .annotatedWith(Names.named("debit"))
      .to(classOf[DebitProcessor])
  }
}
```

#### Instance Bindings

```scala
class Module extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[Configuration]).toInstance(config)
  }
}
```

#### Provider Bindings

```scala
import com.google.inject.Provider

class DatabaseProvider extends Provider[Database] {
  override def get(): Database = {
    Database.connect("jdbc:...")
  }
}

class Module extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[Database]).toProvider(classOf[DatabaseProvider])
  }
}
```

#### @Provides Methods

```scala
import com.google.inject.Provides

class Module extends AbstractModule {
  @Provides
  def provideDatabase(config: Configuration): Database = {
    Database.connect(config.get[String]("db.url"))
  }
}
```

#### Eager Singletons

```scala
class Module extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[StartupService]).asEagerSingleton()
  }
}
```

### Scopes

#### Singleton Scope

```scala
@Singleton
class SingletonService {
  // One instance per application
}
```

#### Default Scope (Prototype)

```scala
class PrototypeService {
  // New instance per injection
}
```

#### Custom Scopes

```scala
import com.google.inject.{Scope, ScopeAnnotation}
import java.lang.annotation.{Retention, RetentionPolicy}

@Retention(RetentionPolicy.RUNTIME)
@ScopeAnnotation
class RequestScoped extends scala.annotation.StaticAnnotation

class RequestScope extends Scope {
  override def scope[T](key: BindingKey[T], provider: Provider[T]): Provider[T] = {
    new Provider[T] {
      override def get(): T = {
        // Get from request context or create
        RequestContext.get(key).getOrElse(provider.get())
      }
    }
  }
}

// Bind to custom scope
bind(classOf[RequestScopedService])
  .in(classOf[RequestScope])
```

### ApplicationLifecycle

```scala
import javax.inject._
import scala.concurrent.Future
import play.api.inject.ApplicationLifecycle

@Singleton
class DatabaseConnection @Inject() (lifecycle: ApplicationLifecycle) {
  val connection = Database.connect()

  lifecycle.addStopHook { () =>
    Future.successful(connection.close())
  }
}

// Multiple stop hooks called in reverse order
@Singleton
class ResourceManager @Inject() (lifecycle: ApplicationLifecycle) {
  val pool = ResourcePool.create()

  lifecycle.addStopHook { () =>
    Future.successful(pool.shutdown())
  }
}
```

### Testing with Play-Guice

```scala
import play.api.inject.guice.GuiceApplicationBuilder
import play.api.test._

// Override bindings
val app = new GuiceApplicationBuilder()
  .overrides(bind[Database].to[MockDatabase])
  .overrides(bind[Cache].to[InMemoryCache])
  .build()

val database = app.injector.instanceOf[Database]

// With Helpers
"UserService" should "store user" in new WithApplication(app) {
  val service = app.injector.instanceOf[UserService]
  service.store(User("test")) shouldEqual true
}
```

### Circular Dependencies

#### Using Provider

```scala
import javax.inject.{Inject, Provider}

class Foo @Inject() (bar: Bar)
class Bar @Inject() (baz: Baz)
class Baz @Inject() (fooProvider: Provider[Foo]) {
  def useFoo(): Foo = fooProvider.get()
}
```

#### Refactoring to Break Cycle

```scala
// Before (cycle)
class ServiceA @Inject() (serviceB: ServiceB)
class ServiceB @Inject() (serviceA: ServiceA)

// After (extract common dependency)
class CommonService

class ServiceA @Inject() (common: CommonService)
class ServiceB @Inject() (common: CommonService)
```

### Play Framework Integration

#### Enabling Guice

```scala
// build.sbt
libraryDependencies += guice
```

#### Module Registration

```scala
// application.conf
play.modules.enabled += "modules.DatabaseModule"
play.modules.enabled += "modules.AuthModule"

// Disable automatic Module loading
play.modules.disabled += "Module"
```

#### Custom ApplicationLoader

```scala
import play.api.inject._
import play.api.inject.guice._

class CustomApplicationLoader extends GuiceApplicationLoader() {
  override def builder(context: ApplicationLoader.Context): GuiceApplicationBuilder = {
    val extra = Configuration("custom.key" -> "value")
    initialBuilder
      .in(context.environment)
      .loadConfig(context.initialConfiguration.withFallback(extra))
      .overrides(overrides(context): _*)
  }
}

// application.conf
play.application.loader = "modules.CustomApplicationLoader"
```

#### Controller Injection

```scala
import javax.inject._

@Singleton
class HomeController @Inject() (
  cc: ControllerComponents,
  userService: UserService
) extends AbstractController(cc) {

  def index = Action { implicit request: Request[AnyContent] =>
    Ok(userService.getCurrentUser())
  }
}
```

#### Play's Built-in Modules

Play provides several built-in modules:
- **BuiltinModule** - Core Play components
- **WSModule** - HTTP client (if enabled)
- **CacheModule** - Caching support
- **I18nModule** - Internationalization

## Comparison: Compile-Time vs Runtime DI

### Macwire (Compile-Time)

**Pros:**
- Type-safe at compile time
- Zero runtime overhead
- Pure Scala (no Java dependencies)
- Fast compilation after initial wiring
- No reflection
- Easier debugging (generated code is visible)

**Cons:**
- Steeper learning curve for advanced patterns
- Less configuration flexibility
- Requires type ascriptions in some cases
- Manual Play Framework integration

### Play-Guice (Runtime)

**Pros:**
- Built-in Play Framework integration
- Annotation-based configuration
- Java-friendly
- Rich ecosystem (AOP, custom scopes)
- Dynamic configuration via modules

**Cons:**
- Runtime errors possible
- Reflection overhead
- Less type-safe than compile-time
- Debugging can be harder
- Slower startup due to reflection

## Performance Considerations

### Macwire

- **Zero runtime overhead**: Macros generate plain Scala code
- **Compilation cost**: Initial compilation is slower, but subsequent compiles are fast
- **No reflection**: All wiring is resolved at compile time
- **Memory**: No additional memory footprint beyond wired objects

### Play-Guice

- **Runtime overhead**: Reflection-based injection adds startup cost
- **Scoping**: Singleton scope reduces repeated instantiation cost
- **AOP**: Method interception adds performance overhead
- **Memory**: Guice injector maintains dependency graph

## Common Pitfalls

### Macwire

1. **Circular Dependencies**: Macwire cannot detect circular dependencies automatically
   ```scala
   // Wrong
   class A(b: B)
   class B(a: A)

   // Solution: Break the cycle
   class A(common: Common)
   class B(common: Common)
   ```

2. **Type Ascriptions**: Required when referencing wired values in same trait
   ```scala
   // Wrong (recursive type error)
   lazy val a = wire[A]
   lazy val b = new B(a)

   // Correct
   lazy val a: A = wire[A]
   lazy val b = new B(a)
   ```

3. **Generic Type Parameters**: Not propagated in autowire
   ```scala
   class B[X](a: A[X])
   // Wrong: autowire[B[Int]] won't propagate Int to A

   // Correct: Provide explicit generic dependency
   autowire[B[Int]](B[Int](_), aInt: A[Int])
   ```

4. **Implicit Parameters**: Ignored by MacWire, use normal implicit resolution

### Play-Guice

1. **Circular Dependencies**: Must use Provider to break cycles
   ```scala
   // Wrong
   class A @Inject() (b: B)
   class B @Inject() (a: A)

   // Correct
   class A @Inject() (b: B)
   class B @Inject() (a: Provider[A])
   ```

2. **Singleton State**: Be careful with mutable state in singletons
   ```scala
   @Singleton
   class CacheService {
     private var cache = Map.empty[String, String]
     // Ensure thread-safety!
   }
   ```

3. **Constructor Overloading**: Use @Inject on only one constructor
   ```scala
   class Database(url: String) {
     @Inject() def this(config: Configuration) = this(config.get[String]("db.url"))
   }
   ```

4. **Stop Hooks in Non-Singletons**: Memory leak risk
   ```scala
   // Wrong: non-singleton registering stop hook
   class Connection @Inject() (lifecycle: ApplicationLifecycle) {
     lifecycle.addStopHook { () => close() }  // Leak!
   }

   // Correct: make it a singleton
   @Singleton
   class Connection @Inject() (lifecycle: ApplicationLifecycle) {
     lifecycle.addStopHook { () => close() }
   }
   ```

## Best Practices

1. **Prefer Constructor Injection** over field or method injection
2. **Use Singletons** for stateless services and resources
3. **Avoid Circular Dependencies** by refactoring common code
4. **Use Interfaces/Traits** for testability and loose coupling
5. **Keep Modules Small** and focused on specific domains
6. **Test Your Wiring** in isolation before integration
7. **Use Type Annotations** to help MacWire resolve types
8. **Prefer Compile-Time DI** (MacWire) for type safety
9. **Use Runtime DI** (Guice) for Play Framework apps
10. **Document Your Wiring** with clear module names and organization

## Integration with Frameworks

### Akka with MacWire

```scala
import akka.actor.{ActorSystem, ActorRef}
import com.softwaremill.macwire.akkasupport._

class DatabaseAccess()
class UserFinderActor(db: DatabaseAccess) extends Actor

trait AkkaModule {
  lazy val system = ActorSystem("app")
  lazy val db = wire[DatabaseAccess]
  lazy val userFinder: ActorRef = wireActor[UserFinderActor]("userFinder")
}
```

### Play Framework with MacWire

```scala
import play.api._
import com.softwaremill.macwire._

class AppModule(environment: Environment, configuration: Configuration)
  extends BuiltInComponentsFromContext(context)
  with AppModule
  with AssetsComponents
  with NoHttpFiltersComponents {

  lazy val router = wire[Router]
}
```

### Http4s with MacWire

```scala
import com.softwaremill.macwire._
import org.http4s._
import org.http4s.server._

class UserServiceRoutes(userService: UserService)

trait HttpModule {
  lazy val userService = wire[UserService]
  lazy val routes: HttpRoutes[IO] = wire[UserServiceRoutes]
}
```

## Multi-Module Application Organization

### Feature-Based Modules

```scala
// Feature modules
trait DatabaseModule
trait AuthModule
trait PaymentModule
trait UserModule

// Combine for production
trait ProductionModule
  extends DatabaseModule
  with AuthModule
  with PaymentModule
  with UserModule

// Override for testing
trait TestModule extends ProductionModule {
  override lazy val db = new InMemoryDatabase()
}
```

### Layered Architecture

```scala
// Data layer
trait DataLayerModule {
  lazy val repository = wire[Repository]
}

// Service layer
trait ServiceLayerModule extends DataLayerModule {
  lazy val userService = wire[UserService]
}

// Presentation layer
trait PresentationLayerModule extends ServiceLayerModule {
  lazy val controller = wire[Controller]
}
```

### Environment-Specific Modules

```scala
trait DevModule {
  lazy val db = wire[InMemoryDatabase]
  lazy val logger = wire[ConsoleLogger]
}

trait ProdModule {
  lazy val db = wire[PostgresDatabase]
  lazy val logger = wire[FileLogger]
}

trait TestModule {
  lazy val db = wire[MockDatabase]
  lazy val logger = wire[SilentLogger]
}
```

## Advanced Patterns

### The "Thin Cake" Pattern

```scala
// Define components
trait DatabaseComponent {
  lazy val db = wire[Database]
}

trait UserRepositoryComponent {
  this: DatabaseComponent =>
  lazy val userRepo = wire[UserRepository]
}

trait UserServiceComponent {
  this: UserRepositoryComponent =>
  lazy val userService = wire[UserService]
}

// Assemble application
trait Application
  extends DatabaseComponent
  with UserRepositoryComponent
  with UserServiceComponent
```

### Parameterized Factories

```scala
class PaymentProcessor(config: PaymentConfig)

trait PaymentModule {
  lazy val baseConfig = wire[PaymentConfig]

  def creditProcessor(id: String): PaymentProcessor = {
    wire[PaymentProcessor]  // Uses baseConfig
  }

  // Or with custom config
  def customProcessor(config: PaymentConfig): PaymentProcessor = {
    new PaymentProcessor(config)
  }
}
```

### Resource Management

```scala
import com.softwaremill.macwire._
import scala.util.Using

trait AppModule {
  // Managed resources
  def withDatabase[T](f: Database => T): T = {
    Using.resource(new Database()) { db =>
      f(db)
    }
  }

  def withCache[T](f: Cache => T): T = {
    Using.resource(new Cache()) { cache =>
      f(cache)
    }
  }

  lazy val service = wire[Service]
}
```

### Dynamic Configuration

```scala
class DatabaseConfig(url: String, poolSize: Int)

trait ConfigModule {
  def dbConfig: DatabaseConfig
}

class ProdConfigModule extends ConfigModule {
  lazy val dbConfig = wire[DatabaseConfig]  // Reads from config file
}

class TestConfigModule extends ConfigModule {
  lazy val dbConfig = DatabaseConfig("jdbc:h2:mem:test", 1)
}

trait DatabaseModule {
  this: ConfigModule =>
  lazy val db = wire[Database]
}
```
