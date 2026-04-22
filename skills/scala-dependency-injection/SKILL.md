---
name: scala-dependency-injection
description: Use this skill when implementing dependency injection in Scala applications. This includes using macwire for compile-time, type-safe DI wiring, or play-guice for runtime DI with Guice. Trigger when the user mentions dependency injection, DI, wiring, modules, or needs to manage dependencies between components.
---

# Dependency Injection in Scala

Dependency injection (DI) achieves Inversion of Control (IoC) by delegating object creation to a container or framework. Scala offers two main approaches:

- **macwire** — Zero-cost, compile-time, type-safe dependency injection via macros
- **play-guice** — Runtime DI using Google Guice integrated with Play Framework

## Quick Start

### Macwire

```scala
import com.softwaremill.macwire._

class DatabaseAccess()
class SecurityFilter()
class UserFinder(databaseAccess: DatabaseAccess, securityFilter: SecurityFilter)
class UserStatusReader(userFinder: UserFinder)

trait UserModule {
  lazy val databaseAccess   = wire[DatabaseAccess]
  lazy val securityFilter   = wire[SecurityFilter]
  lazy val userFinder       = wire[UserFinder]
  lazy val userStatusReader = wire[UserStatusReader]
}
```

### Play-Guice

```scala
import javax.inject._

class MyComponent @Inject() (ws: play.api.libs.ws.WSClient) {
  // ws is injected automatically
}

@Singleton
class CurrentSharePrice {
  private var price = 0
  def set(p: Int): Unit = price = p
  def get: Int = price
}

@ImplementedBy(classOf[EnglishHello])
trait Hello {
  def sayHello(name: String): String
}

class EnglishHello extends Hello {
  def sayHello(name: String): String = s"Hello $name"
}
```

## Macwire Core Patterns

### wire[] — Context-Dependent Wiring

`wire[]` looks for values in: enclosing block/method arguments, enclosing type (vals, defs), and parent types (via inheritance).

```scala
class Database()
class Service(db: Database)

trait AppModule {
  lazy val db = wire[Database]
  lazy val service = wire[Service]
}
```

### wireRec[] — Recursive Wiring

```scala
trait AppModule {
  lazy val userStatusReader = wireRec[UserStatusReader]
  // Generates: new UserStatusReader(new UserFinder(new Database(), new SecurityFilter()))
}
```

### autowire[] — Context-Free Wiring

```scala
val customDb = new Database("custom-connection")
val service = autowire[Service](customDb)

// Specify implementation classes
trait Database
class DatabaseImpl() extends Database
autowire[Service](classOf[DatabaseImpl])
```

### wireSet[] / wireList[] — Multi-Instance Wiring

```scala
trait Musician
class Singer() extends Musician
class Guitarist() extends Musician

trait BandModule {
  lazy val singer = wire[Singer]
  lazy val guitarist = wire[Guitarist]
  lazy val musicians = wireSet[Musician]     // Set[Singer, Guitarist]
  lazy val ordered = wireList[Musician]      // List (preserves order, Scala 3)
}
```

### Factories

```scala
class TaxCalculator(base: Double, db: Database)

trait TaxModule {
  lazy val db = wire[Database]
  def taxCalculator(base: Double) = wire[TaxCalculator]  // Runtime parameter
}

// Factory methods with wireWith
object C { def create(a: A): C = new C(a, 42) }
trait MyModule {
  lazy val a = wire[A]
  lazy val c = wireWith(C.create _)
}
```

### Composing Modules

```scala
// Inheritance
class SocialModule extends UserModule {
  lazy val socialService = wire[SocialService]
}

// Composition with imports
class SocialModule(userModule: UserModule) {
  import userModule._
  lazy val facebookAccess = wire[FacebookAccess]
}
```

## Play-Guice Core Patterns

### Constructor Injection

```scala
class MyComponent @Inject() (ws: WSClient) {
  // ws is injected automatically
}
```

### Custom Guice Modules

```scala
class Module(environment: Environment, configuration: Configuration) extends AbstractModule {
  override def configure(): Unit = {
    bind(classOf[Hello])
      .annotatedWith(Names.named("en"))
      .to(classOf[EnglishHello])

    bind(classOf[ApplicationStart]).asEagerSingleton()
  }
}
```

### Provider Injection (Breaking Cycles)

```scala
class Baz @Inject() (fooProvider: Provider[Foo]) {
  def useFoo(): Foo = fooProvider.get()
}
```

### ApplicationLifecycle for Cleanup

```scala
@Singleton
class MessageQueueConnection @Inject() (lifecycle: ApplicationLifecycle) {
  val connection = connectToQueue()
  lifecycle.addStopHook { () => Future.successful(connection.stop()) }
}
```

## Common Patterns

### Testing with Mocks

**Macwire:**
```scala
trait TestModule extends UserModule {
  override lazy val db = new MockDatabase()
}
```

**Play-Guice:**
```scala
val app = new GuiceApplicationBuilder()
  .overrides(bind[Database].to[MockDatabase])
  .build()
```

### Multi-Module Applications

**Macwire:**
```scala
trait AppModule extends DatabaseModule with AuthModule {
  lazy val app = wire[Application]
}
```

**Play-Guice:**
```hocon
# application.conf
play.modules.enabled += "modules.DatabaseModule"
play.modules.enabled += "modules.AuthModule"
```

### Qualifiers (Named Dependencies)

```scala
class PaymentService @Inject() (
  @Named("credit") creditProcessor: PaymentProcessor,
  @Named("debit") debitProcessor: PaymentProcessor
)
```

## Choosing the Right Library

| Feature | Macwire | Play-Guice |
|---------|---------|------------|
| **Type Safety** | Compile-time | Runtime |
| **Performance** | Zero runtime overhead | Reflection overhead |
| **Configuration** | Pure Scala | Java-based modules |
| **Play Integration** | Possible but manual | Built-in |

**Use Macwire when:** compile-time safety, pure Scala, zero runtime overhead matters.
**Use Play-Guice when:** Play Framework applications, Java interop, annotation-based configuration preferred.

## Dependencies

```scala
// Macwire
libraryDependencies ++= Seq(
  "com.softwaremill.macwire" %% "macros" % "2.6.+",
  "com.softwaremill.macwire" %% "util" % "2.6.+",
  "com.softwaremill.macwire" %% "proxy" % "2.6.+"
)

// Play-Guice (provided by sbt plugin)
libraryDependencies += guice
```

## Related Skills

- **scala-play** — for Play Framework applications that use Guice DI
- **scala-fp-patterns** — for tagless final patterns as an alternative to traditional DI
- **scala-async-effects** — for effect-based resource management and dependency lifecycle

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/REFERENCE.md** — Complete Macwire API reference (wire, wireRec, autowire, wireSet, wireList), Play-Guice module configuration details, advanced scoping patterns, testing strategies, performance considerations, common pitfalls and solutions
