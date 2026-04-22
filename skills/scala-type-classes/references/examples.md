# Type Class Examples Reference

Practical patterns, Mouse utilities, real-world integration, and testing with type classes.

## Mouse Utilities

### Boolean Utilities

```scala
import mouse.boolean._

// Convert boolean to Option
true.option("It's true!")  // Some("It's true!")
false.option("It's false!")  // None

// Execute effect conditionally
true.whenA(IO.println("Running"))  // IO(())
false.whenA(IO.println("Not running"))  // IO(())

false.unlessA(IO.println("Running"))  // IO(())
true.unlessA(IO.println("Not running"))  // IO(())

// ApplyIf
true.applyIf(IO(42))  // Some(IO(42))
false.applyIf(IO(42))  // None

// ApplyUnless
false.applyUnless(IO(42))  // Some(IO(42))
true.applyUnless(IO(42))  // None
```

### String Utilities

```scala
import mouse.string._

// Parse to primitives
"42".parseInt  // Right(42)
"3.14".parseFloat  // Right(3.14f)
"123L".parseLong  // Right(123L)
"1.234".parseDouble  // Right(1.234)
"true".parseBoolean  // Right(true)

// Parse with validation
"42".parseIntValidated  // Valid(42)
"abc".parseIntValidated  // Invalid(NumberFormatException)

// Safe parse
"42".parseIntEither  // Right(42)
"abc".parseIntEither  // Left(NumberFormatException)
```

### Option Utilities

```scala
import mouse.option._

// OrElse with default
val opt1: Option[Int] = Some(1)
opt1.orElseSome(0)  // Some(1)

val opt2: Option[Int] = None
opt2.orElseSome(0)  // Some(0)

// Apply function to option
opt1.applyF((x: Int) => x * 2)  // Some(2)

// Convert to Either
opt1.toLeft("none")  // Right(1)
opt2.toLeft("none")  // Left("none")

opt1.toRight("none")  // Left(1)
opt2.toRight("none")  // Right("none")
```

### Either Utilities

```scala
import mouse.either._

// Cata - fold over Either
val either: Either[String, Int] = Right(42)
either.cata(
  left => s"Error: $left",
  right => s"Success: $right"
)  // "Success: 42"

// Bifold - fold over both
either.bifold(
  left => List(s"Error: $left"),
  right => List(s"Value: $right")
)  // List("Value: 42")

// Ensure condition on success
Right(42).ensure(new Exception("Too small"))(_ > 10)  // Right(42)
Right(5).ensure(new Exception("Too small"))(_ > 10)  // Left(Exception(...))

// GetOrElse
Right(42).getOrElse(0)  // 42
Left("error").getOrElse(0)  // 0
```

### Try Utilities

```scala
import mouse.try._

// Cata - fold over Try
val tryResult = scala.util.Try(42)
tryResult.cata(
  value => s"Success: $value",
  error => s"Failed: $error"
)  // "Success: 42"

// To Either
tryResult.toEither  // Right(42)
scala.util.Try(throw new Exception("error")).toEither  // Left(Exception(...))

// To Option
tryResult.toOption  // Some(42)
scala.util.Try(throw new Exception("error")).toOption  // None
```

### Numeric Utilities

```scala
import mouse.int._
import mouse.long._
import mouse.double._

// Squared
5.squared  // 25

// Cubed
3.cubed  // 27

// To byte array
123456789.toByteArray  // Array(7, 91, -51, 21)

// To base64
123456789L.toBase64  // "AAAAAAdbzRU"
```

### Any Utilities

```scala
import mouse.any._

// Pipe operator
1 |> ((_: Int) + 2) |> ((_: Int) * 3)  // 9

// Equivalent to:
((1 + 2) * 3)  // 9

// ApplyIf
val condition = true
condition.applyIf(42)  // Some(42)
condition.applyUnless(42)  // None

!condition.applyIf(42)  // None
!condition.applyUnless(42)  // Some(42)
```

### F[Option[A]] Utilities

```scala
import mouse.foption._

// Map inside nested structure
val listOption = List(Option(1), Option(2), None)
listOption.mapIn(_ * 2)  // List(Some(2), Some(4), None)

// Sequence nested options
listOption.sequence  // Some(List(1, 2))
```

### F[Either[A, B]] Utilities

```scala
import mouse.feither._

// Map inside nested structure
val listEither = List(Right(1), Right(2), Left("error"))
listEither.mapIn(_ * 2)  // List(Right(2), Right(4), Left("error"))

// Sequence nested eithers
listEither.sequence  // Right(List(1, 2))
```

### Nested Structure Utilities

```scala
import mouse.fnested._

// Map over two-level nested structure
val listOption = List(Option(1), Option(2))
listOption.mapNested2(_ * 2)  // List(Some(2), Some(4))

// Map over three-level nested structure
val listOptionList = List(Option(List(1)), Option(List(2)))
listOptionList.mapNested3(_ * 2)  // List(Option(List(2)), Option(List(4)))
```

### Tuple Utilities

```scala
import mouse.ftuple._

// Get first element
(1, 2, 3, 4).head  // 1

// Get last element
(1, 2, 3, 4).last  // 4

// Get tail elements
(1, 2, 3, 4).tail  // (2, 3, 4)
```

### Map Utilities

```scala
import mouse.map._

// Map keys
val map = Map(1 -> 2, 3 -> 4)
map.mapKeys(_ * 2)  // Map(2 -> 2, 6 -> 4)

// Combine maps
val map1 = Map("a" -> 1)
val map2 = Map("b" -> 2)
map1 |+| map2  // Map("a" -> 1, "b" -> 2)
```

### List Utilities

```scala
import mouse.list._

// Tail or empty
List(1, 2, 3).tailOrEmpty  // List(2, 3)
Nil.tailOrEmpty  // List()

// Tail option
List(1, 2, 3).tailOption  // Some(NonEmptyList(2, 3))
Nil.tailOption  // None

// Group into chunks
List(1, 2, 3, 4, 5).grouped(2)  // List(List(1, 2), List(3, 4), List(5))
```

### Set Utilities

```scala
import mouse.set._

// Tail or empty
Set(1, 2, 3).tailOrEmpty  // Set(2, 3)
Set(1).tailOrEmpty  // Set()

// Tail option
Set(1, 2, 3).tailOption  // Some(NonEmptySet(2, 3))
Set(1).tailOption  // None
```

## Real-World Integration Patterns

### Repository Pattern with MonadError

```scala
import cats._
import cats.implicits._
import cats.effect.IO

case class User(id: Long, name: String, email: String)

trait UserRepository[F[_]] {
  def findById(id: Long): F[Option[User]]
  def create(user: User): F[User]
  def update(user: User): F[User]
}

class UserRepositoryImpl[F[_]: MonadError[*, String]](
  implicit database: Database[F]
) extends UserRepository[F] {
  def findById(id: Long): F[Option[User]] =
    database.query(s"SELECT * FROM users WHERE id = $id")
      .map(_.toOption)
      .handleErrorWith { e =>
        Monad[F].raiseError(s"Database error: $e")
      }

  def create(user: User): F[User] =
    database.execute(
      s"INSERT INTO users (name, email) VALUES ('${user.name}', '${user.email}')"
    )
      .handleErrorWith { e =>
        Monad[F].raiseError(s"Failed to create user: $e")
      }

  def update(user: User): F[User] =
    database.execute(
      s"UPDATE users SET name = '${user.name}', email = '${user.email}' WHERE id = ${user.id}"
    )
      .handleErrorWith { e =>
        Monad[F].raiseError(s"Failed to update user: $e")
      }
}
```

### Validation with Either

```scala
import cats._
import cats.implicits._

case class User(name: String, age: Int, email: String)

object UserValidator {
  def validate(name: String, age: Int, email: String): Either[String, User] =
    for {
      validatedName <- validateName(name)
      validatedAge <- validateAge(age)
      validatedEmail <- validateEmail(email)
    } yield User(validatedName, validatedAge, validatedEmail)

  private def validateName(name: String): Either[String, String] =
    if (name.nonEmpty && name.length >= 2) Right(name)
    else Left("Name must be at least 2 characters")

  private def validateAge(age: Int): Either[String, Int] =
    if (age >= 18) Right(age)
    else Left("Age must be at least 18")

  private def validateEmail(email: String): Either[String, String] =
    if (email.contains("@")) Right(email)
    else Left("Invalid email format")
}
```

### Service Layer with Tagless Final

```scala
import cats.tagless._
import cats._
import cats.implicits._
import cats.effect.IO

case class Order(id: Long, items: List[CartItem], total: BigDecimal)
case class CartItem(productId: String, quantity: Int, price: BigDecimal)

trait UserRepository[F[_]] {
  def findById(id: Long): F[Option[String]]
}

trait ProductService[F[_]] {
  def getProductPrice(productId: String): F[BigDecimal]
  def getProductStock(productId: String): F[Int]
}

trait OrderRepository[F[_]] {
  def createOrder(order: Order): F[Order]
}

@finalAlg
@autoFunctorK
trait OrderServiceAlg[F[_]] {
  def checkout(cart: List[CartItem], userId: Long): F[Order]
}

class OrderService[F[_]](
  implicit userRepo: UserRepository[F],
  productRepo: ProductService[F],
  orderRepo: OrderRepository[F],
  F: Monad[F]
) extends OrderServiceAlg[F] {
  def checkout(cart: List[CartItem], userId: Long): F[Order] = for {
    userName <- userRepo.findById(userId).flatMap {
      case Some(name) => F.pure(name)
      case None => F.raiseError(s"User $userId not found")
    }

    total <- cart.traverse { item =>
      productRepo.getProductPrice(item.productId).map(price => price * item.quantity)
    }.map(_.sum)

    order = Order(0, cart, total)
    savedOrder <- orderRepo.createOrder(order)
  } yield savedOrder
}
```

## Testing with Type Classes

### Mocking with cats-effect

```scala
import cats.effect.IO
import cats.effect.unsafe.implicits.global
import org.scalamock.scalatest.MockFactory
import org.scalatest.funsuite.AnyFunSuite

class UserServiceTest extends AnyFunSuite with MockFactory {
  test("Should create user successfully") {
    val mockUserRepo = mock[UserRepository[IO]]
    val mockProductService = mock[ProductService[IO]]

    (mockUserRepo.findById _).expects(1L).returning(IO.pure(Some("Alice")))
    (mockProductService.getProductPrice _).expects("item1").returning(IO.pure(10.0))
    (mockProductService.getProductPrice _).expects("item2").returning(IO.pure(20.0))
    (mockProductService.getProductStock _).expects("item1").returning(IO.pure(100))
    (mockProductService.getProductStock _).expects("item2").returning(IO.pure(50))
    (mockOrderRepo.createOrder _).expects(*).returning(IO.pure(Order(1, List(), 30.0)))

    val service = new OrderService(mockUserRepo, mockProductService, mockOrderRepo)
    val result = service.checkout(List(), 1L).unsafeRunSync()

    assert(result.id == 1)
  }
}
```

### Law Testing with Discipline

```scala
import cats._
import cats.kernel.laws.discipline._
import cats.laws.discipline._
import org.typelevel.discipline.scalatest.FunSuiteDiscipline
import org.scalatest.funsuite.AnyFunSuite
import org.scalacheck.Arbitrary

case class Counter(value: Int)

given counterMonoid: Monoid[Counter] = Monoid.instance(
  Counter(0),
  (c1, c2) => Counter(c1.value + c2.value)
)

given counterEq: Eq[Counter] = Eq.by(_.value)

given arbCounter: Arbitrary[Counter] = Arbitrary(for {
  value <- Arbitrary.arbitrary[Int]
} yield Counter(value))

class CounterLawsTest extends AnyFunSuite with FunSuiteDiscipline {
  checkAll("Counter.MonoidLaws", MonoidTests[Counter].monoid)
  checkAll("Counter.EqLaws", EqTests[Counter].eqv)
}
```

### No-Op Instances

```scala
val NoOpLogger: Logger[IO] = new Logger[IO] {
  def info(msg: String): IO[Unit] = IO.unit
  def error(msg: String): IO[Unit] = IO.unit
}

val NoOpBackground: Background[IO] = new Background[IO] {
  def schedule[A](fa: IO[A], duration: FiniteDuration): IO[Unit] = IO.unit
}
```

### Gen vs Arbitrary

```scala
// Prefer Gen for flexible, multiple generators per type
val personGen: Gen[Person] =
  for {
    n <- Gen.alphaStr
    a <- Gen.chooseNum(1, 100)
  } yield Person(n, a)

// Avoid Arbitrary - only one instance per type (coherence issues)
// implicit val arbPerson: Arbitrary[Person] = Arbitrary(personGen)
```

## Common Practical Patterns

### Error Handling Strategy

```scala
import cats._
import cats.implicits._

trait ErrorHandler[F[_]] {
  def handleError[A](error: String)(f: => F[A]): F[A]
}

object ErrorHandler {
  implicit def errorHandler[F[_]: Monad]: ErrorHandler[F] = new ErrorHandler[F] {
    def handleError[A](error: String)(f: => F[A]): F[A] = {
      try {
        f
      } catch {
        case e: Exception =>
          Monad[F].raiseError(s"$error: ${e.getMessage}")
      }
    }
  }
}
```

### Caching with Memoization

```scala
import cats.effect._
import cats.implicits._

object ComputationCache {
  def memoize[F[_]: Sync, A](fa: F[A]): F[A] =
    Sync[F].delay(new java.util.concurrent.ConcurrentHashMap[A, A]()).flatMap { cache =>
      Sync[F].delay(cache.computeIfAbsent(fa, (_: A) => fa))
    }
}
```

### Async Operations

```scala
import cats.effect._
import cats.implicits._

object AsyncOperations {
  def processInParallel[F[_]: Async](operations: List[F[Unit]]): F[Unit] =
    operations.parTraverse_(identity)
}
```

## Type Class Laws

### Semigroup Laws

```scala
import cats.kernel.laws._

// Associativity: (a |+| b) |+| c == a |+| (b |+| c)
val a = 1; val b = 2; val c = 3
assert(((a |+| b) |+| c) == (a |+| (b |+| c)))
```

### Monoid Laws

```scala
import cats.kernel.laws._

// Identity: a |+| empty == a, empty |+| a == a
val a = 5
val empty = Monoid[Int].empty
assert((a |+| empty) == a)
assert((empty |+| a) == a)
```

### Functor Laws

```scala
import cats.laws._

// Identity: fa.map(identity) == fa
// Composition: fa.map(f).map(g) == fa.map(f.andThen(g))
val list = List(1, 2, 3)
assert(list.map(identity) == list)

val f = (_: Int) * 2
val g = (_: Int) + 1
assert(list.map(f).map(g) == list.map(f.andThen(g)))
```

### Applicative Laws

```scala
import cats.laws._

// Identity: pure(id).ap(fa) == fa
// Homomorphism: pure(f).ap(pure(x)) == pure(f(x))
// Interchange: pure(f).ap(pure(x)) == pure(_.apply(x)).ap(pure(f))
// Composition: pure(_.apply).ap(pure(f)).ap(pure(x)) == pure(x).map(f)
```

### Monad Laws

```scala
import cats.laws._

// Left identity: pure(x).flatMap(f) == f(x)
// Right identity: m.flatMap(pure) == m
// Associativity: m.flatMap(f).flatMap(g) == m.flatMap(x => f(x).flatMap(g))
```
