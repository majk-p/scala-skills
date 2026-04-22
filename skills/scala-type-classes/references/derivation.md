# Type Class Derivation Reference

Complete reference for Kittens (automatic type class derivation) and cats-tagless patterns.

## Kittens — Scala 2

### Basic Semiauto Derivation

```scala
import cats._
import cats.derived._

case class Person(name: String, age: Int, address: Address)
case class Address(street: String, city: String)

// Semiauto derivation (recommended)
implicit val showPerson: Show[Person] = semiauto.show
implicit val eqPerson: Eq[Person] = semiauto.eq
implicit val orderPerson: Order[Person] = semiauto.order
implicit val hashPerson: Hash[Person] = semiauto.hash

implicit val showAddress: Show[Address] = semiauto.show

// Using derived instances
val p = Person("Alice", 30, Address("123 Main St", "Springfield"))
p.show  // Person(name = Alice, age = 30, address = Address(street = 123 Main St, city = Springfield))

val p2 = Person("Alice", 30, Address("123 Main St", "Springfield"))
p === p2  // true

// Monoid derivation
implicit val monoidPerson: Monoid[Person] = semiauto.monoid
val emptyPerson: Person = Monoid[Person].empty
val combined = List(
  Person("Alice", 30, Address("123 Main St", "Springfield")),
  Person("Bob", 25, Address("456 Oak Ave", "Shelbyville"))
).combineAll

// Functor derivation
case class Box[A](value: A)
implicit val functorBox: Functor[Box] = semiauto.functor

Box(3).map(_ + 1)  // Box(4)

// Contravariant derivation
case class Encoder[A](encode: A => String)
implicit val encoderContravariant: Contravariant[Encoder] = semiauto.contravariant

val intEncoder: Encoder[Int] = Encoder(_.toString)
val stringEncoder: Encoder[String] = intEncoder.contramap(_.length)
stringEncoder.encode("hello")  // "5"
```

### Auto Derivation (Global)

```scala
import derived.auto.show._
import derived.auto.eq._

case class AutoDerived(x: Int, y: String)
// Automatically has Show and Eq instances
AutoDerived(42, "test").show  // AutoDerived(x = 42, y = test)
```

### Cached Derivation (Global Cache)

```scala
import derived.cached.show._
import derived.cached.eq._

// All derived instances are cached globally
```

### Advanced Derivation Patterns

```scala
import cats._
import cats.derived._

case class Person(name: String, address: Address)
case class Address(street: String, city: String)

// Recursive derivation
implicit val showPerson: Show[Person] = semiauto.show
implicit val showAddress: Show[Address] = semiauto.show

val p = Person("Alice", Address("123 Main St", "Springfield"))
p.show  // Works correctly with recursive structures

// Strict derivation (no recursive derivation)
case class StrictPerson(name: String, address: Address)

object StrictPerson:
  given Eq[StrictPerson] = strict.semiauto.eq
  given Show[StrictPerson] = strict.semiauto.show
```

## Kittens — Scala 3

### Using Derives Clause

```scala
import cats._
import cats.derived._

// Using derives clause (recommended)
case class Point(x: Int, y: Int) derives Eq, Show, Order, Hash, Semigroup

val p1 = Point(1, 2)
val p2 = Point(1, 2)
p1 === p2  // true

p1.show  // Point(x = 1, y = 2)

p1 |+| p2  // Point(x = 2, y = 4)
```

### Companion Object Derivation

```scala
import cats._
import cats.derived._

case class Person(name: String, age: Int)

object Person:
  given Show[Person] = semiauto.show
  given Eq[Person] = semiauto.eq
  given Order[Person] = semiauto.order

// Using derived instances
Person("Alice", 30).show  // Person(name = Alice, age = 30)
```

### Direct Semiauto Derivation

```scala
case class Person(name: String, age: Int)

given showPerson: Show[Person] = semiauto.show
given eqPerson: Eq[Person] = semiauto.eq
given orderPerson: Order[Person] = semiauto.order

// Using derived instances
Person("Alice", 30).show  // Person(name = Alice, age = 30)
```

### Enum Derivation

```scala
import cats._
import cats.derived._

enum Color derives Eq, Show:
  case Red, Green, Blue

Color.Red === Color.Green  // false
Color.Blue.show  // Blue
```

### Recursive Derivation

```scala
case class Recursive(value: Option[Recursive]) derives Eq
```

### Bifunctor Derivation

```scala
import cats._
import cats.derived._

case class BiContainer[L, R](left: L, right: R) derives Bifunctor

val bc = BiContainer(1, "hello")
bc.leftMap(_ + 1)  // BiContainer(2, "hello")
bc.rightMap(_.toUpperCase)  // BiContainer(1, "HELLO")
```

### Bitraverse Derivation

```scala
import cats._
import cats.derived._

case class BiPair[L, R](left: L, right: R) derives Bitraverse

val bp = BiPair(1, "hello")
bp.bitraverse(
  x => Option(x * 2),
  s => Option(s.length)
)  // Option(BiPair(2, 5))
```

## Type Class Support Matrix (Kittens)

### Monomorphic Types

| Type Class     | Case Classes          | Sealed Traits         | Singleton Types |
|---------------|----------------------|----------------------|----------------|
| Eq             | ∀ fields: Eq        | ∀ variants: Eq      | ✓              |
| Hash           | ∀ fields: Hash      | ∀ variants: Hash    | ✓              |
| Order          | ∀ fields: Order     | ∀ variants: Order   | ✓              |
| PartialOrder   | ∀ fields: PartialOrder | ∀ variants: PartialOrder | ✓ |
| Show           | ∀ fields: Show      | ∀ variants: Show    | ✓              |
| ShowPretty     | ∀ fields: ShowPretty | ∀ variants: ShowPretty | ✓ |
| Semigroup      | ∀ fields: Semigroup | ✗                    | ✗              |
| Monoid         | ∀ fields: Monoid   | ✗                    | ✗              |

### Polymorphic Types

| Type Class     | Case Classes          | Sealed Traits         | Constant Types        | Nested Types          |
|---------------|----------------------|----------------------|----------------------|----------------------|
| Functor        | ∀ fields: Functor   | ∀ variants: Functor  | for T: Monoid       | for F: Functor, G: Functor |
| Applicative   | ∀ fields: Applicative | ✗                | for T: Monoid       | for F: Applicative, G: Applicative |
| Apply          | ∀ fields: Apply      | ✗                | for T: Semigroup    | for F: Apply, G: Apply |
| Foldable      | ∀ fields: Foldable  | ∀ variants: Foldable | ✗                   | for F: Foldable, G: Foldable |
| Traverse      | ∀ fields: Traverse  | ∀ variants: Traverse | ✗                   | for F: Traverse, G: Traverse |
| Contravariant  | ∀ fields: Contravariant | ∀ variants: Contravariant | ✗ | for F: Functor, G: Contravariant |
| Invariant      | ∀ fields: Invariant  | ∀ variants: Invariant | ✗                   | for F: Invariant, G: Invariant |
| MonoidK        | ∀ fields: MonoidK   | ✗                    | for T: Monoid        | for F: MonoidK, G: Applicative |
| SemigroupK     | ∀ fields: SemigroupK | ✗                    | for T: Semigroup     | for F: SemigroupK, G: Apply |

## Cats Tagless Patterns

### Final Tagless Encoding

```scala
import cats.tagless._
import cats._
import cats.implicits._

// Define algebra with annotations
@finalAlg
@autoFunctorK
@autoSemigroupalK
@autoProductNK
trait ExpressionAlg[F[_]] {
  def num(i: String): F[Double]
  def divide(dividend: Double, divisor: Double): F[Double]
}

// Implement for Try
implicit object tryExpression extends ExpressionAlg[scala.util.Try] {
  def num(i: String) = scala.util.Try(i.toDouble)
  def divide(dividend: Double, divisor: Double) = scala.util.Try(dividend / divisor)
}

// Implement for Option
implicit object optionExpression extends ExpressionAlg[Option] {
  def num(i: String) = Some(i.toDouble)
  def divide(dividend: Double, divisor: Double) = if (divisor != 0) Some(dividend / divisor) else None
}

// Transform with FunctionK
val fk: scala.util.Try ~> Option = λ[scala.util.Try ~> Option](_.toOption)
val optionExpression = tryExpression.mapK(fk)

// Use transformed algebra
optionExpression.num("42")  // Some(42.0)
optionExpression.divide(10, 2)  // Some(5.0)
optionExpression.divide(10, 0)  // None
```

### Auto Derivation

```scala
import cats.tagless._
import cats._
import cats.implicits._

// Auto-derive when you have a function
implicit val tryToOption: scala.util.Try ~> Option = λ[scala.util.Try ~> Option](_.toOption)

// Automatically derive ExpressionAlg[Option] if ExpressionAlg[Try] exists
implicit val autoOption: ExpressionAlg[Option] = ???
// This works because tryExpression and tryToOption are in scope

// Can turn off auto derivation
@autoFunctorK(autoDerivation = false)
trait NoAutoDerive[F[_]] { ... }
```

### Vertical Composition

```scala
import cats.tagless._
import cats._
import cats.implicits._

// Base algebra
@finalAlg
trait DatabaseAlg[F[_]] {
  def query(id: Int): F[User]
  def save(user: User): F[Unit]
}

// Higher-level algebra that uses base
@finalAlg
trait UserServiceAlg[F[_]] {
  def getUser(id: Int): F[User]
  def updateUser(id: Int, name: String): F[Unit]
}

// Implement using lower-level algebra
class UserService[F[_]](
  implicit db: DatabaseAlg[F],
  F: Monad[F]
) extends UserServiceAlg[F] {
  def getUser(id: Int): F[User] = db.query(id)

  def updateUser(id: Int, name: String): F[Unit] = for {
    user <- db.query(id)
    _ <- db.save(user.copy(name = name))
  } yield ()
}
```

### Horizontal Composition

```scala
import cats.tagless._
import cats._
import cats.implicits._

@finalAlg
@autoSemigroupalK
trait LoggingAlg[F[_]] {
  def log(message: String): F[Unit]
}

@finalAlg
trait ValidationAlg[F[_]] {
  def validate(user: User): F[Either[String, User]]
}

// Product of algebras
type Combined[F[_]] = ProductK[LoggingAlg, ValidationAlg, F]

val combinedAlg: Combined[IO] = ???

// Use combined operations
combinedAlg.log("Processing").productK(combinedAlg.validate(user))
```

### Stack-Safe Operations with Free

```scala
import cats.tagless._
import cats._
import cats.implicits._
import cats.free.Free

@finalAlg
@autoFunctorK
trait Increment[F[_]] {
  def plusOne(i: Int): F[Int]
}

implicit object incTry extends Increment[scala.util.Try] {
  def plusOne(i: Int) = scala.util.Try(i + 1)
}

// Recursive program that may overflow stack
def program[F[_]: Monad: Increment](i: Int): F[Int] = for {
  j <- Increment[F].plusOne(i)
  result <- if (j < 10000) program[F](j) else Monad[F].pure(j)
} yield result

// Transform to Free for stack safety
implicit def toFree[F[_]]: F ~> Free[F, *] = λ[F ~> Free[F, *]](Free.liftF)

val freeProgram: Free[scala.util.Try, Int] = program[Free[scala.util.Try, *]](0)

// Run with interpreter
val result = freeProgram.foldMap(FunctionK.id[scala.util.Try])
// Success(10000)
```

### @autoFunctor and Related Annotations

```scala
import cats.tagless._
import cats._
import cats.implicits._

@autoFunctor
trait SimpleAlg[T] {
  def foo(a: String): T
  def bar(d: Double): Double
}

implicit object SimpleAlgInt extends SimpleAlg[Int] {
  def foo(a: String): Int = a.length
  def bar(d: Double): Double = 2 * d
}

// Map over the algebra
val mapped = SimpleAlg[Int].map(_ + 1)
mapped.foo("blah")  // 5
mapped.bar(2)  // 4.0 (unaffected)

@autoFlatMap
trait StringAlg[T] {
  def foo(a: String): T
}

implicit object LengthAlg extends StringAlg[Int] {
  def foo(a: String): Int = a.length
}

implicit object HeadAlg extends StringAlg[Char] {
  def foo(a: String): Char = a.headOption.getOrElse(' ')
}

val hintAlg = for {
  length <- LengthAlg
  head <- HeadAlg
} yield head.toString ++ "*" * (length - 1)

hintAlg.foo("Password")  // "P*******"

@autoInvariant
trait SimpleInvAlg[T] {
  def foo(a: T): T
}

implicit object SimpleInvAlgString extends SimpleInvAlg[String] {
  def foo(a: String): String = a.reverse
}

val mappedInv = SimpleInvAlg[String].imap(_.toInt)(_.toString)
mappedInv.foo(12)  // "21"

@autoContravariant
trait SimpleContraAlg[T] {
  def foo(a: T): String
}

implicit object SimpleContraAlgString extends SimpleContraAlg[String] {
  def foo(a: String): String = a.reverse
}

val mappedContra = SimpleContraAlgString].contramap[Int](_.toString)
mappedContra.foo(12)  // "21"
```

## Custom Derivation

### Creating a Custom Type Class with Derivation

```scala
import shapeless._
import shapeless.labelled._

trait Combinable[A] {
  def combine(x: A, y: A): A
}

object Combinable {
  def apply[A](implicit instance: Combinable[A]): Combinable[A] = instance

  // Basic instances
  implicit val intCombinable: Combinable[Int] = (x, y) => x + y
  implicit val stringCombinable: Combinable[String] = (x, y) => x ++ y

  // Generic derivation
  implicit def genericCombinable[A, R](
    implicit gen: LabelledGeneric.Aux[A, R],
    combiner: Lazy[Combiner[R]]
  ): Combinable[A] = (x, y) =>
    combiner.value.combine(gen.to(x), gen.to(y))
}

// Deriver trait
trait Combiner[R] {
  def combine(x: R, y: R): R
}

object Combiner {
  // Product combiner
  implicit val hnilCombiner: Combiner[HNil] = (_: HNil, _: HNil) => HNil

  implicit def hlistCombiner[H, T <: HList](
    implicit hCombinable: Lazy[Combinable[H]],
    tCombiner: Lazy[Combiner[T]]
  ): Combiner[H :: T] = (x, y) =>
    hCombinable.value.combine(x.head, y.head) ::
    tCombiner.value.combine(x.tail, y.tail)

  // Coproduct combiner
  implicit def cnilCombiner: Combiner[CNil] = (_: CNil, _: CNil) => CNil

  implicit def coproductCombiner[H, T <: Coproduct](
    implicit hCombinable: Lazy[Combinable[H]],
    tCombiner: Lazy[Combiner[T]]
  ): Combiner[H :+: T] = (x, y) =>
    (x, y) match {
      case (Inl(hx), Inl(hy)) => Inl(hCombinable.value.combine(hx, hy))
      case (Inr(tx), Inr(ty)) => Inr(tCombiner.value.combine(tx, ty))
      case _ => ???
    }
}
```

### Orphan Instances

```scala
import tf.tofu.derevo.cats._

@derive(decoder, encoder)
case class UserName(value: NonEmptyString)

object UserName {
  implicit val decoder: Decoder[UserName] = ???
  implicit val encoder: Encoder[UserName] = ???
}
```

### Higher-Kinded Derivations

```scala
@derive(decoder, encoder, show)
@newtype case class JwtToken(value: String)

object JwtToken {
  implicit val show: Show[JwtToken] = ???

  // Derive for F[JwtToken]
  implicit def showF[F[_]: Functor]: Show[F[JwtToken]] = ???
}
```

## Cats MTL — Monad Transformer Type Classes

### Ask — Reading Environment

```scala
import cats.mtl._
import cats.data._

// Definition
trait Ask[F[_], E] {
  def applicative: Applicative[F]
  def ask: F[E]
  def reader[A](f: E => A): F[A]
}

// Using with Kleisli
type K[A] = Kleisli[IO, Config, A]

val timeout = K { implicit config: Config => IO.pure(config.timeout) }

// Use local to modify environment
val modified = timeout.local(_.copy(timeout = 100))
```

### Local — Modifying Environment

```scala
import cats.mtl._

// Definition
trait Local[F[_], E] extends Ask[F, E] {
  def local[A](fa: F[A])(f: E => E): F[A]
}

// Use local to modify environment for a computation
def withTimeout[F[_], A](
  timeout: Int
)(fa: F[A]
)(implicit local: Local[F, Config]): F[A] =
  local.local(fa)(_.copy(timeout = timeout))

// Scope environment change
def scoped[F[_], A](config: Config)(fa: F[A])(implicit local: Local[F, Config]): F[A] =
  local.local(fa)(_ => config)
```

### Raise — Raising Errors

```scala
import cats.mtl._

// Definition
trait Raise[F[_], E] {
  def applicative: Applicative[F]
  def raise[A](e: E): F[A]
}

// Raise errors
def raiseError[F[_]](implicit raise: Raise[F, String]): F[Int] =
  raise.raise[Int]("Error occurred")

// With EitherT
type Result[A] = EitherT[IO, String, A]

val program = for {
  x <- EitherT.liftF(IO.pure(42))
  y <- if (x < 10) EitherT.leftT("Too small")
       else EitherT.rightT(x + 1)
} yield y
```

### Handle — Handling Errors

```scala
import cats.mtl._

// Definition
trait Handle[F[_], E] extends Raise[F, E] {
  def attemptWith[A](fa: F[A])(f: E => F[A]): F[A]
}

// Handle errors
def handleError[F[_]](implicit handle: Handle[F, String]): F[Int] =
  handle.attemptWith(raiseError[F]) { err =>
    Applicative[F].pure(-1)
  }

// Handle specific errors
def handleSpecific[F[_]](implicit handle: Handle[F, Exception]): F[Int] =
  handle.attemptWith(raiseError[F]) {
    case _: IllegalArgumentException => Applicative[F].pure(-1)
    case e => handle.raise(e)
  }
```

### Stateful — State Operations

```scala
import cats.mtl._

// Definition
trait Stateful[F[_], S] {
  def monad: Monad[F]
  def get: F[S]
  def set(s: S): F[Unit]
  def modify(f: S => S): F[Unit]
}

// Use state
def updateCounter[F[_]](implicit state: Stateful[F, Int]): F[Unit] =
  for {
    current <- state.get
    _ <- state.set(current + 1)
  } yield ()

// With StateT
type StateResult[A] = StateT[IO, Int, A]

val program: StateResult[Int] = for {
  current <- StateT.get[IO, Int]
  _ <- StateT.set[IO, Int](current + 1)
  result <- StateT.pure[IO, Int, Int](current + 2)
} yield result
```

### Tell — Logging

```scala
import cats.mtl._

// Definition
trait Tell[F[_], L] {
  def functor: Functor[F]
  def tell(l: L): F[Unit]
}

// Log messages
def logMessage[F[_]](implicit tell: Tell[F, String]): F[Unit] =
  for {
    _ <- tell.tell("Starting operation")
    _ <- tell.tell("Operation complete")
  } yield ()

// With Writer
type Logged[A] = Writer[String, A]

val loggedProgram = for {
  _ <- Writer.tell("Step 1\n")
  _ <- Writer.tell("Step 2\n")
} yield "Done"

val (log, result) = loggedProgram.run
```

### Listen — Reading Logs

```scala
import cats.mtl._

// Definition
trait Listen[F[_], L] extends Tell[F, L] {
  def listen[A](fa: F[A]): F[(L, A)]
}

// Listen to log
def withLog[F[_], A](implicit listen: Listen[F, String])(fa: F[A]): F[(String, A)] =
  listen(fa)
```

### Chronicle — Error Accumulation

```scala
import cats.mtl._

// Definition
trait Chronicle[F[_], E] {
  def applicative: Applicative[F]
  def confess[A](e: E): F[A]
  def dictate[A](fa: F[A])(f: E => F[A]): F[A]
}

// Accumulate errors
def accumulateErrors[F[_]](implicit chronicle: Chronicle[F, String]): F[Int] =
  for {
    _ <- chronicle.confess("Error 1")
    _ <- chronicle.confess("Error 2")
  } yield 42

// With Validated
type ValidatedResult[A] = Ior[String, A]

val validated = for {
  x <- Ior.left[String]("Error 1")
  y <- Ior.right[Int](42)
} yield (x, y)
// Ior.Left("Error 1")
```

### Combining Multiple MTL Effects

```scala
import cats.mtl._
import cats.data._

// Multiple effects in one type
type App[A] = EitherT[StateT[IO, Int, *], String, A]

val combined: App[Int] = for {
  // Stateful
  _ <- StateT.liftF[EitherT[String, *], Int, Unit](
    EitherT.liftF(IO.println("Getting state"))
  )

  // Raise
  x <- if (true) EitherT.leftT("Error")
       else EitherT.rightT(42)

  // Stateful again
  _ <- StateT.modify[EitherT[String, *], Int](_ + 1)
} yield x

// Better approach: use ReaderT for environment
type App2[A] = ReaderT[EitherT[StateT[IO, Int, *], String, *], Config, A]

val combined2: App2[Int] = ReaderT { implicit config =>
  for {
    _ <- StateT.liftF[EitherT[String, *], Int, Unit](
      EitherT.liftF(IO.println(s"Config timeout: ${config.timeout}"))
    )
    x <- if (config.timeout > 10) EitherT.leftT("Too large")
         else EitherT.rightT(config.timeout + 1)
    _ <- StateT.modify[EitherT[String, *], Int](_ + 1)
  } yield x
}
```

## Complete Tagless Final Patterns

### Algebras

```scala
// Define business logic as abstract operations
trait Users[F[_]] {
  def find(username: UserName): F[Option[UserWithPassword]]
  def create(username: UserName, password: EncryptedPassword): F[UserId]
  def delete(userId: UserId): F[Unit]
}

// Multiple interpreters
object Users {
  def inMemory[F[_]](implicit F: cats.effect.Sync[F]): Users[F] = ???
  def postgres[F[_]](postgres: Resource[F, Session[F]]): Users[F] = ???
}
```

### Smart Constructor Pattern

```scala
object Counter {
  def make[F[_]](implicit F: cats.effect.kernel.Ref.Make[F]): F[Counter[F]] =
    Ref.of[F, Int](0).map { ref =>
      new Counter[F] {
        def incr: F[Unit] = ref.update(_ + 1)
        def get: F[Int] = ref.get
      }
    }
}
```

### Capability Traits

Interface knows nothing about implementation details.

```scala
// Interface knows nothing about how incr/get are implemented
trait Counter[F[_]] {
  def incr: F[Unit]
  def get: F[Int]
}
```

### Implicit vs Explicit Parameters

**Implicit** (convenient for common cases):
```scala
final case class Checkout[F[_]](
  payments: PaymentClient[F],
  cart: ShoppingCart[F],
  orders: Orders[F],
  policy: RetryPolicy[F] // Implicit!
)(implicit
  bg: Background[F],
  logger: Logger[F],
  M: MonadThrow[F],
  R: Retry[F]
)
```

**Explicit** (clearer for unique configurations):
```scala
case class CheckoutConfig[F[_]](
  payments: PaymentClient[F],
  cart: ShoppingCart[F],
  orders: Orders[F],
  policy: RetryPolicy[F]
)

def makeCheckout[F[_]: Background: Logger: MonadThrow: Retry](
  config: CheckoutConfig[F]
): Checkout[F] = ???
```

### Parametricity

```scala
// Different interpreters for same logic
val testCheckout: Checkout[IO] = Checkout[IO](
  payments = TestPayment.client,
  cart = TestCart.impl,
  orders = TestOrders.impl,
  policy = testPolicy
)

val prodCheckout: Checkout[IO] = Checkout[IO](
  payments = ProdPayment.client,
  cart = ProdCart.impl,
  orders = ProdOrders.impl,
  policy = prodPolicy
)
```
