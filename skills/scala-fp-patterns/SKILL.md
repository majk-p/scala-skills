---
name: scala-fp-patterns
description: Use this skill when implementing advanced functional programming patterns in Scala including tagless final encoding, state management, newtypes, and refinement types. Covers capability traits, interpreters, effect polymorphism, MTL transformers, StateT, AtomicCell, Local, compile-time validation, and domain modeling with type safety. Trigger when the user mentions tagless final, capability traits, state monad, MTL, newtypes, refinement types, type-safe domain modeling, or effect polymorphism.
---

# Advanced Functional Programming Patterns in Scala

This skill covers four interconnected FP patterns that provide stronger type safety, better modularity, and more maintainable code: **newtypes**, **refinement types**, **tagless final encoding**, and **state management**.

## Newtypes for Domain Modeling

Newtypes prevent mixing conceptually different types at compile time. Unlike type aliases, the compiler rejects incorrect assignments.

```scala
import io.estatico.newtype.macros._

@newtype case class Username(value: String)
@newtype case class Email(value: String)
@newtype case class UserId(value: Long)

// Compiler prevents mixing
def greet(u: Username): String = s"Hello, ${u.value}"
greet(Username("alice"))  // OK
// greet(Email("test"))   // COMPILATION ERROR
```

### Why Not Type Aliases?

```scala
// Type alias — NO type safety
type UserId = Long
val userId: UserId = 123L
val age: Long = 25
val bad: UserId = age  // Compiles! BUG!

// Newtype — TYPE SAFE
@newtype case class UserId(value: Long)
val userId2 = UserId(123)
// val bad2: UserId = age  // COMPILATION ERROR
```

## Refinement Types for Validation

Refinement types add compile-time and runtime constraints to existing types.

### Built-in Refinements

```scala
import eu.timepit.refined.api.Refined
import eu.timepit.refined.auto._
import eu.timepit.refined.types.string.NonEmptyString
import eu.timepit.refined.numeric._

type Username = NonEmptyString
type PositiveInt = Int Refined Greater[0]

val valid: PositiveInt = 5  // OK
// val invalid: PositiveInt = -5  // COMPILATION ERROR
```

### Runtime Refinement

```scala
import eu.timepit.refined._
import eu.timepit.refined.api.Refined

def validateAge(age: Int): Either[String, Int Refined Positive] =
  refineV[Positive](age)

val result1 = validateAge(25)   // Right(25)
val result2 = validateAge(-5)   // Left("Predicate failed")
```

### Combining Multiple Refinements

```scala
import eu.timepit.refined.boolean._
import eu.timepit.refined.numeric._
import eu.timepit.refined.collection._

type StrongPassword = String Refined And[
  NonEmpty,
  Length[Greater[8]],
  Length[Less[50]]
]
```

### Combining Newtypes with Refinements

```scala
@newtype case class UserId(value: Long)

object UserId {
  def from(s: String): Either[String, UserId] =
    refineV[NonEmpty](s).map(u => UserId(u.value.toLong))
}
```

## Tagless Final Encoding

Tagless final separates interface from implementation using parameterized effect types. Define algebras as traits, implement interpreters for different effects, and write business logic that works for any effect type.

### Define Algebras

```scala
import cats.Monad
import cats.implicits._

trait UserRepository[F[_]] {
  def find(id: UserId): F[Option[User]]
  def save(user: User): F[Unit]
}

trait Logging[F[_]] {
  def info(message: String): F[Unit]
  def error(message: String, error: Throwable): F[Unit]
}
```

### Implement Interpreters

```scala
import cats.effect.Sync

// Production interpreter
object UserRepository {
  def impl[F[_]: Sync](xa: Transactor[F]): UserRepository[F] =
    new UserRepository[F] {
      def find(id: UserId): F[Option[User]] =
        sql"select * from users where id = ${id.value}".query[User].option.transact(xa)
      def save(user: User): F[Unit] =
        sql"insert into users values (${user.id}, ${user.name})".update.run.transact(xa).void
    }
}

// Test interpreter
object InMemoryUserRepo {
  def impl[F[_]: Sync]: UserRepository[F] = new UserRepository[F] {
    private var users = Map.empty[UserId, User]
    def find(id: UserId): F[Option[User]] = Sync[F].delay(users.get(id))
    def save(user: User): F[Unit] = Sync[F].delay { users = users + (user.id -> user) }
  }
}

// Logging interpreter
object Logging {
  def impl[F[_]: Sync]: Logging[F] = new Logging[F] {
    def info(message: String): F[Unit] = Sync[F].delay(println(s"[INFO] $message"))
    def error(message: String, error: Throwable): F[Unit] =
      Sync[F].delay(println(s"[ERROR] $message: ${error.getMessage}"))
  }
}
```

### Write Polymorphic Business Logic

```scala
// This works for IO, Task, or any F with the required capabilities
def registerUser[F[_]: Monad: UserRepository: Logging](
  name: Username,
  email: Email
): F[User] = for {
  _ <- Logging[F].info(s"Registering $name")
  user = User(UserId(0), name, email)
  _ <- UserRepository[F].save(user)
  _ <- Logging[F].info(s"Registered $name successfully")
} yield user
```

### Capability Composition

Combine multiple capability traits via context bounds:

```scala
trait AuthService[F[_]] {
  def generateToken(user: User): F[AuthToken]
  def validateToken(token: AuthToken): F[Option[User]]
}

trait EmailService[F[_]] {
  def sendWelcome(user: User): F[Unit]
}

def registerAndNotify[F[_]: Monad: UserRepository: AuthService: EmailService: Logging](
  name: Username, email: Email
): F[AuthToken] = for {
  user <- registerUser[F](name, email)
  token <- AuthService[F].generateToken(user)
  _ <- EmailService[F].sendWelcome(user)
} yield token
```

## State Management

### State Monad with StateT

For pure functional state transitions:

```scala
import cats.data.StateT
import cats.effect.IO

case class AppState(
  userBalance: Map[String, Int] = Map.empty,
  transactionCount: Int = 0
)

type App[A] = StateT[IO, AppState, A]

def updateBalance(userId: String, amount: Int): App[Unit] =
  StateT.modify { state =>
    val newBalance = state.userBalance.getOrElse(userId, 0) + amount
    state.copy(
      userBalance = state.userBalance + (userId -> newBalance),
      transactionCount = state.transactionCount + 1
    )
  }

val program: App[Unit] = for {
  _ <- updateBalance("alice", 100)
  _ <- updateBalance("bob", 200)
  _ <- updateBalance("alice", 50)
} yield ()

val (finalState, _) = program.run(AppState()).unsafeRunSync()
// finalState: AppState(userBalance=Map("alice" -> 150, "bob" -> 200), transactionCount=3)
```

### MTL Stateful for Effect-Polymorphic State

```scala
import cats.mtl.Stateful

def updateUserBalance[F[_]: Stateful[*[_], Map[String, Int]]](
  userId: String, amount: Int
): F[Unit] = for {
  current <- Stateful[F, Map[String, Int]].get
  _ <- Stateful[F, Map[String, Int]].set(current + (userId -> amount))
} yield ()
```

### AtomicCell for Concurrent State

```scala
import cats.effect.std.AtomicCell
import cats.effect.IO

def processConcurrently(): IO[Unit] = for {
  state <- AtomicCell.of[IO, Int](0)
  _ <- List.range(1, 6).traverse { i =>
    state.modify(_ + i)
  }
  finalValue <- state.get
  _ <- IO(println(s"Final: $finalValue"))
} yield ()
```

### Ref-based State

```scala
import cats.effect.Ref
import cats.effect.Sync

def createCounter[F[_]: Sync]: F[Ref[F, Int]] =
  Ref.of[F, Int](0)

def increment[F[_]: Sync](ref: Ref[F, Int]): F[Int] =
  ref.updateAndGet(_ + 1)
```

## Error Handling Patterns

### Hierarchical Error Types

```scala
sealed trait DomainError
case class NotFound(id: String) extends DomainError
case class ValidationError(message: String) extends DomainError
case class BusinessRuleError(error: String) extends DomainError

def validateUser[F[_]: MonadError[*[_], DomainError]](
  user: User
): F[Unit] =
  if (user.email.value.nonEmpty) ().pure[F]
  else MonadError[F, DomainError].raiseError(ValidationError("Empty email"))
```

### Error Accumulation with Validated

```scala
import cats.data.ValidatedNel

def validateAllFields(
  name: String, age: Int, email: String
): ValidatedNel[String, User] =
  (
    refineV[NonEmpty](name).toValidatedNel,
    refineV[Positive](age).toValidatedNel,
    refineV[NonEmpty](email).toValidatedNel
  ).mapN { (name, age, email) =>
    User(UserId(0), Username(name), Email(email))
  }
```

### EitherT for Effectful Error Handling

```scala
import cats.data.EitherT

def serviceOperation[F[_]: MonadError[*[_], AppError]](id: UserId): EitherT[F, AppError, Result] =
  for {
    result <- EitherT.right[F](findEntity(id))
    validated <- EitherT.fromEither[F](validate(result))
  } yield validated
```

## Decorator Pattern with Tagless Final

```scala
class CachedService[F[_]: Sync](delegate: Service[F], cache: Cache[F]) extends Service[F] {
  def getData(id: ID): F[Data] = cache.get(id).flatMap {
    case Some(value) => Sync[F].pure(value)
    case None => for {
      data <- delegate.getData(id)
      _ <- cache.set(id, data)
    } yield data
  }
}
```

## Dependencies

```scala
// check for latest version
// Newtypes
libraryDependencies += "io.estatico" %% "newtype" % "0.4.+"

// Refinement types
libraryDependencies += "eu.timepit" %% "refined" % "0.9.+"
libraryDependencies += "eu.timepit" %% "refined-cats" % "0.9.+"

// Cats Effect
libraryDependencies += "org.typelevel" %% "cats-effect" % "3.6.+"

// Cats MTL
libraryDependencies += "org.typelevel" %% "cats-mtl" % "1.3.+"
```

## Best Practices

1. Prefer newtypes over type aliases to prevent mixing conceptually different types
2. Use refinement types for compile-time validation where possible
3. Combine newtypes and refinements for maximum type safety
4. Use tagless final for modular, testable architectures
5. Implement multiple interpreters (production, test, mock)
6. Prefer explicit error types over exceptions
7. Use `MonadError` for effectful error handling
8. Prefer `AtomicCell` over `AtomicReference` for thread-safe state
9. Use `Validated` for error accumulation, `EitherT` for short-circuiting
10. Use `StateT` for pure state transitions, `Ref`/`AtomicCell` for concurrent state

## Related Skills

- **scala-type-classes** — for Functor, Monad, MonadError and other type class foundations
- **scala-async-effects** — for IO, Resource, fiber concurrency that underpin these patterns
- **scala-validation** — for Iron-based refinement types in Scala 3
- **scala-lang** — for Scala 3 features used in advanced type patterns

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/tagless-final.md** — Capability trait derivation, context passing, generic interpreters, composite components, recursive capability traits
- **references/state-management.md** — StateT deep dive, MTL transformers, Local, AtomicCell patterns, resource-safe state management
- **references/refinement-types.md** — Iron constraint type classes, opaque type newtypes, smart constructors, constraint composition, Cats Effect error accumulation, Circe serialization
