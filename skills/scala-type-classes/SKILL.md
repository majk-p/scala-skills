---
name: scala-type-classes
description: Use this skill when working with functional programming type classes in Scala. Covers core type classes (Semigroup, Monoid, Functor, Applicative, Monad, Eq, Show, Foldable, Traverse), advanced patterns (tagless final, monad transformers with cats-mtl, MonadError), automatic derivation (Kittens, cats-tagless), and practical utilities (Mouse, real-world integration, law testing). Trigger when the user mentions type classes, functors, monads, Semigroup, Monoid, Eq, Show, Foldable, Traverse, Applicative, derivation, Kittens, cats-tagless, tagless final, monad transformers, or needs to derive type class instances automatically — even if they don't explicitly name the library.
---

# Type Classes in Scala

Type classes provide ad-hoc polymorphism in Scala, letting you define composable behaviors across many types while maintaining type safety. The **Cats** library is the standard ecosystem for type class-based FP in Scala.

This skill covers the full spectrum: from core type classes (Semigroup, Monoid, Functor, etc.) through advanced patterns (tagless final, monad transformers) to automatic derivation and practical utilities.

## Quick Start

```scala
import cats._
import cats.implicits._

// Semigroup - combining values
val sum = 2 |+| 3                           // 5

// Monoid - combining with identity
val combined = List(1, 2, 3).combineAll     // 6

// Functor - mapping over structure
val mapped = List(1, 2, 3).map(_ * 2)       // List(2, 3, 4)

// Applicative - applying functions in context
val result = (Option(3), Option(4)).mapN(_ + _)  // Some(7)

// Monad - sequencing effects
val sequenced = for {
  x <- Option(3)
  y <- Option(4)
} yield x + y                                // Some(7)

// Traverse - effectful traversal
val traversed = List(1, 2, 3).traverse(x => Option(x * 2))  // Some(List(2, 4, 6))
```

## Core Concepts

### Semigroup & Monoid

Semigroup provides an associative `combine` operation. Monoid extends it with an identity element (`empty`).

```scala
// Combine with syntax
2 |+| 3                           // 5
"a" |+| "b"                       // "ab"
List(1, 2) |+| List(3, 4)         // List(1, 2, 3, 4)

// Monoid identity
Monoid[Int].empty                  // 0
Monoid[String].empty               // ""
Monoid[List[Int]].empty            // List()

// FoldMap — transform then combine
val lengths = List("hello", "world").foldMap(_.length)  // 10

// Custom instance
case class Vector2D(x: Int, y: Int)
given Semigroup[Vector2D] = Semigroup.instance((v1, v2) => Vector2D(v1.x + v2.x, v1.y + v2.y))
given Monoid[Vector2D] = Monoid.instance(Vector2D(0, 0), _ |+| _)
```

### Eq & Show

```scala
// Eq — type-safe equality (avoids == on unrelated types)
1 === 1         // true
1 =!= 2         // true
case class Person(name: String, age: Int)
given Eq[Person] = Eq.by(p => (p.name, p.age))

// Show — type-safe string representation
42.show         // "42"
given Show[Person] = Show.show(p => s"${p.name} (${p.age})")
```

### Order & PartialOrder

```scala
// Order — total ordering with syntax
1 compare 2     // -1
1 min 2         // 1
3.clamp(0, 2)   // 2

case class Score(value: Int)
given Order[Score] = Order.by(_.value)
```

### Functor

```scala
// Map over a context
Option(3).map(_ + 1)               // Some(4)

// Lift a function into the functor
val lifted = Functor[Option].lift((_: Int) + 1)
lifted(3)                           // Some(4)

// Compose functors
val lo = Functor[List] compose Functor[Option]
lo.map(List(Some(1), Some(2)))(_ + 1)  // List(Some(2), Some(3))

// Custom instance
case class Box[A](value: A)
given Functor[Box] = new Functor[Box] {
  def map[A, B](fa: Box[A])(f: A => B): Box[B] = Box(f(fa.value))
}
```

### Contravariant & Invariant

```scala
// Contravariant — contramap reverses direction (e.g., Show, Predicate)
Show[Int].contramap[String](_.length).show("hello")  // "5"

case class Predicate[A](check: A => Boolean)
given Contravariant[Predicate] = new Contravariant[Predicate] {
  def contramap[A, B](fa: Predicate[A])(f: B => A): Predicate[B] =
    Predicate(b => fa.check(f(b)))
}

// Invariant — needs both directions (e.g., Codec)
case class Codec[A](encode: A => String, decode: String => A)
given Invariant[Codec] = new Invariant[Codec] {
  def imap[A, B](fa: Codec[A])(f: A => B)(g: B => A): Codec[B] =
    Codec(b => fa.encode(g(b)), s => f(fa.decode(s)))
}
```

### Applicative & Apply

```scala
// Apply — ap and mapN
val add: Option[Int => Int] = Some(_ + 1)
Apply[Option].ap(add)(Some(3))      // Some(4)

// Tuple mapN (most common pattern)
(Option(1), Option(2)).mapN(_ + _)  // Some(3)
(Option(1), Option(2), Option(3)).mapN(_ + _ + _)  // Some(6)

// Applicative — pure
Applicative[Option].pure(42)        // Some(42)
```

### Monad

```scala
// For-comprehensions are flatMap chains
val result = for {
  x <- Option(3)
  y <- Option(4)
} yield x + y                       // Some(7)

// ifM — conditional in monad context
Monad[Option].ifM(Option(true))(Option("yes"), Option("no"))  // Some("yes")

// filterM — effectful filtering
List(1, 2, 3, 4).filterM(x => Option(x % 2 == 0))  // Some(List(2, 4))

// Stack-safe recursion with foldM
def sumList(list: List[Int]): Int = list.foldM(0)(_ + _)
```

### MonadError

```scala
// Raise and handle typed errors
val raised = MonadError[Either[String, *], String].raiseError[Int]("fail")  // Left("fail")

val handled = Either.right[String, Int](42).recover {
  case "fail" => 0
}

// ensure — validate and convert to error
Right(42).ensure(new Exception("Too small"))(_ > 10)  // Right(42)
Right(5).ensure(new Exception("Too small"))(_ > 10)   // Left(Exception(...))
```

### Foldable & Traverse

```scala
// Foldable — folding operations
List(1, 2, 3).foldLeft(0)(_ + _)    // 6
Option(3).toList                     // List(3)

// Traverse — effectful traversal
List(1, 2, 3).traverse(x => Option(x * 2))  // Some(List(2, 4, 6))
List(Some(1), Some(2), Some(3)).sequence     // Some(List(1, 2, 3))

// Parallel traverse (with cats-effect)
List(1, 2, 3).parTraverse(x => IO.pure(x * 2))  // IO(List(2, 4, 6))
```

### Alternative

```scala
// Choice with <+> (left-biased or)
Option(1) <+> Option(2)             // Some(1)
None[Int] <+> Option(2)             // Some(2)

// Guard for filtering in for-comprehensions
val filtered = List(1, 2, 3, 4).filterA(x => Alternative[List].guard(x % 2 == 0))
```

## Common Patterns

### Error Accumulation with Validated

```scala
import cats.data.ValidatedNec

def validateName(name: String): ValidatedNec[String, String] =
  if (name.nonEmpty) Validated.validNec(name) else Validated.invalidNec("Name is empty")

def validateAge(age: Int): ValidatedNec[String, Int] =
  if (age >= 18) Validated.validNec(age) else Validated.invalidNec("Too young")

// Accumulates all errors
val result = (validateName("Alice"), validateAge(25)).mapN(User.apply)
```

### Combining Values Safely

```scala
def safeCombineAll[A: Monoid](values: List[A]): A = values.combineAll

def combineOption[A: Semigroup](values: List[Option[A]]): Option[A] =
  values.combineAllOption
```

### Custom Type Classes

```scala
trait Combinable[A] {
  def combine(x: A, y: A): A
}

object Combinable {
  def apply[A](using inst: Combinable[A]): Combinable[A] = inst

  given Combinable[Int] = (x, y) => x + y
  given Combinable[String] = (x, y) => x ++ y
  given [A: Combinable]: Combinable[Option[A]] =
    (ox, oy) => (ox, oy).mapN(Combinable[A].combine)

  extension [A: Combinable](x: A)
    def |++|(y: A): A = Combinable[A].combine(x, y)
}
```

## Advanced Patterns

### Tagless Final Encoding

Define business logic as abstract algebras parameterized by effect type, then provide concrete interpreters.

```scala
// Algebra — abstract interface
trait UserRepository[F[_]] {
  def findById(id: Long): F[Option[User]]
  def create(user: User): F[User]
}

// Interpreter for production
class PostgresUserRepo[F[_]: Sync](session: Resource[F, Session[F]]) extends UserRepository[F] {
  def findById(id: Long): F[Option[User]] = ???
  def create(user: User): F[User] = ???
}

// Interpreter for testing
class InMemoryUserRepo[F[_]: Sync](ref: Ref[F, Map[Long, User]]) extends UserRepository[F] {
  def findById(id: Long): F[Option[User]] = ref.get.map(_.get(id))
  def create(user: User): F[User] = ref.update(_ + (user.id -> user)).as(user)
}
```

### Cats MTL — Monad Transformer Type Classes

Cats MTL provides composable effect capabilities without manually stacking transformers.

```scala
import cats.mtl._

// Ask — read from environment
def readTimeout[F[_]](using Ask[F, Config]): F[Int] = Ask[F, Config].reader(_.timeout)

// Local — modify environment locally
def withTimeout[F[_], A](timeout: Int)(fa: F[A])(using Local[F, Config]): F[A] =
  Local[F, Config].local(fa)(_.copy(timeout = timeout))

// Raise — raise typed errors
def fail[F[_]](using Raise[F, String]): F[Int] = Raise[F, String].raise("error")

// Stateful — mutable state
def updateCounter[F[_]](using Stateful[F, Int]): F[Unit] =
  for {
    current <- Stateful[F, Int].get
    _ <- Stateful[F, Int].set(current + 1)
  } yield ()

// Tell — write to log
def logMessage[F[_]](using Tell[F, Chain[String]]): F[Unit] =
  Tell[F, Chain[String]].tell(Chain.one("Something happened"))

// Combine effects — type aliases get complex but MTL type classes stay clean
type AppF[A] = Kleisli[IO, Config, Either[String, A]]
// Ask[AppF, Config], Raise[AppF, String] all available
```

### Combining Multiple MTL Effects

```scala
// Stack: ReaderT over EitherT over StateT over IO
type Stack[A] = ReaderT[EitherT[StateT[IO, Int, *], String, *], Config, A]

// Or better — just use the MTL constraints on F[_]
def program[F[_]: Monad: Ask[*, Config]: Raise[*, String]: Stateful[*, Int]]: F[Unit] =
  for {
    config <- Ask[F, Config].ask
    _ <- Stateful[F, Int].modify(_ + 1)
    _ <- if (config.debug) Raise[F, String].raise("debug not allowed") else Monad[F].unit
  } yield ()
```

## Derivation

### Kittens — Automatic Type Class Derivation

```scala
import cats.derived._

// Scala 3 — derives clause (recommended)
case class Point(x: Int, y: Int) derives Eq, Show, Order, Semigroup
enum Color derives Eq, Show:
  case Red, Green, Blue

// Scala 3 — companion object semiauto
case class Person(name: String, age: Int)
object Person:
  given Show[Person] = semiauto.show
  given Eq[Person] = semiauto.eq

// Scala 2 — semiauto (recommended)
implicit val showPerson: Show[Person] = semiauto.show
implicit val eqPerson: Eq[Person] = semiauto.eq
implicit val monoidPerson: Monoid[Person] = semiauto.monoid

// Polymorphic derivation
case class Box[A](value: A)
given Functor[Box] = semiauto.functor    // Box(3).map(_ + 1) == Box(4)

// Bifunctor derivation (Scala 3)
case class BiContainer[L, R](left: L, right: R) derives Bifunctor
```

**Derivation support matrix** (semiauto): Eq, Hash, Order, PartialOrder, Show, ShowPretty on case classes and sealed traits. Semigroup and Monoid on case classes only. Functor, Foldable, Traverse, Contravariant, Invariant on polymorphic case classes and sealed traits.

### Cats Tagless — Algebra Derivation

```scala
import cats.tagless._

// Auto-derive FunctorK for algebras
@finalAlg
@autoFunctorK
@autoSemigroupalK
trait ExpressionAlg[F[_]] {
  def num(i: String): F[Double]
  def divide(dividend: Double, divisor: Double): F[Double]
}

// Transform algebras with FunctionK
implicit val tryExpr: ExpressionAlg[Try] = new ExpressionAlg[Try] {
  def num(i: String) = Try(i.toDouble)
  def divide(d: Double, div: Double) = Try(d / div)
}

val fk: Try ~> Option = λ[Try ~> Option](_.toOption)
val optionExpr: ExpressionAlg[Option] = tryExpr.mapK(fk)

// Horizontal composition
type Combined[F[_]] = ProductK[LoggingAlg, ValidationAlg, F]
```

## Dependencies

```scala
libraryDependencies += "org.typelevel" %% "cats-core" % "2.+"
libraryDependencies += "org.typelevel" %% "cats-mtl" % "1.+"
libraryDependencies += "org.typelevel" %% "cats-tagless" % "0.+"
libraryDependencies += "org.typelevel" %% "mouse" % "1.+"
// For derivation (Kittens):
libraryDependencies += "org.typelevel" %% "cats-deriving" % "2.+"
```

## Related Skills

- **scala-fp-patterns** — for newtypes, refinement types, tagless final architecture, and state monad patterns
- **scala-async-effects** — for ZIO/cats-effect IO, fibers, and resource management used alongside type classes
- **scala-testing-property** — for property-based testing and law checking with Discipline

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/core-reference.md** — Complete API reference for all core type classes: Semigroup, Monoid, Eq, Show, Order, PartialOrder, Functor, Contravariant, Invariant, Apply, Applicative, Monad, MonadError, Alternative, Foldable, Traverse, FlatMap with full code examples and type class hierarchy
- **references/derivation.md** — Kittens derivation (Scala 2 and 3), support matrices, strict vs recursive derivation, cats-tagless patterns (vertical/horizontal composition, FunctionK transforms, autoFunctor/autoFlatMap/autoInvariant/autoContravariant), custom derivation with shapeless
- **references/examples.md** — Mouse utilities (Boolean, String, Option, Either, Try, numeric, F[Option], F[Either], nested structures, tuples, Map, List, Set), real-world patterns (repository with MonadError, validation, service layer with tagless final), testing with mocks and Discipline law checks, caching, error handling strategies
