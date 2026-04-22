# Scala 3 Advanced Types Reference

## Match Types

### Basic Match Types

```scala
type Elem[X] = X match
  case String      => Char
  case Array[t]    => t
  case Iterable[t] => t
  case Any         => X

type Bool[+T] = T match
  case Boolean => Boolean
  case Int     => Boolean
```

### Type-Level Conditionals

```scala
type If[Cond, TrueType, FalseType] = Cond match
  case true  => TrueType
  case false => FalseType
```

### Compile-Time Type Checks

```scala
def foo[T: <:< Int](value: T): Int = value

foo(42)     // Works
// foo("hello")  // Type error
```

### Literal Types

```scala
type StringType = String & Nothing
val text: StringType = "hello"  // Must be compile-time literal
// val notText: StringType = "hello" + " world"  // Won't compile
```

## GADTs

### Basic GADTs

```scala
sealed trait Box[T]
case class IntBox(x: Int) extends Box[Int]
case class StringBox(s: String) extends Box[String]

def getIntValue(box: Box[Int]): Int = box match
  case IntBox(x) => x
```

### Advanced GADTs with Expression Trees

```scala
sealed trait Expr[T]
case class Const(value: Int)                        extends Expr[Int]
case class Add(lhs: Expr[Int], rhs: Expr[Int])      extends Expr[Int]
case class IsZero(expr: Expr[Int])                  extends Expr[Boolean]
case class IfExpr[A](cond: Expr[Boolean],
                     thenExpr: Expr[A],
                     elseExpr: Expr[A])             extends Expr[A]

def eval[T](expr: Expr[T]): T = expr match
  case Const(v)        => v
  case Add(l, r)       => eval(l) + eval(r)
  case IsZero(e)       => eval(e) == 0
  case IfExpr(c, t, e) => if eval(c) then eval(t) else eval(e)
```

### Tree Structures with GADTs

```scala
sealed trait Tree[T]
case class Leaf[T](value: T) extends Tree[T]
case class Branch[T](left: Tree[T], right: Tree[T]) extends Tree[T]

def depth[T](tree: Tree[T]): Int = tree match
  case Leaf(_)      => 0
  case Branch(l, r) => 1 + math.max(depth(l), depth(r))
```

## Type-Level Combinators

### Type-Level Boolean Logic

```scala
type Not[X] = [Y] =>> X
type And[A, B] = [C] =>> A[B[C]] & B[A[C]]
type Or[A, B] = [C] =>> A | B

type If[Cond, TrueType, FalseType] = Cond match
  case true  => TrueType
  case false => FalseType
```

### Church Encoding

```scala
trait List[A]:
  def head: A
  def tail: List[A]
  def isEmpty: Boolean

type Nil[A] = [F[_]] =>> F[A]
type Cons[A] = [F[_]] =>> F[A] & F[List[A]]
```

## Dependent Types

### Dependent Function Types

```scala
// Function types that depend on values
def isPositive[T](x: T): T => Boolean = n => n > 0

// Dependent product types
type Option[+T] = [B] =>> Either[Error, T] & T =>> B

// Dependent sum types
type Either[+E, +A] = [B] =>> Either[E, B] & A =>> B
```

## Higher-Kinded Types

### Type Classes with Higher-Kinded Types

```scala
trait Functor[F[_]]:
  def map[A, B](fa: F[A])(f: A => B): F[B]

trait Monad[F[_]]:
  def pure[A](a: A): F[A]
  def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B]

// Using higher-kinded type classes
def liftF[F[_]: Monad, A](a: A): F[A] = summon[Monad[F]].pure(a)

def doSomething[F[_]: Monad]: F[Unit] =
  for
    x <- liftF[F, Int](1)
    y <- liftF[F, Int](2)
    result <- liftF[F, Int](x + y)
  yield result
```

### Context Bounds with Types

```scala
def process[T: Show: Ordering](values: List[T]): Unit =
  val sorted = values.sorted
  sorted.foreach(v => println(summon[Show[T]].show(v)))

def genericFunction[A: <:< String](value: A): String = value.toString
```

## Type-Safe Validation

```scala
import cats.data.*
import cats.syntax.all.*

def validateEmail(email: String): Either[NonEmptyList[String], String] =
  if email.contains("@") then Right(email)
  else Left(NonEmptyList.one("Email must contain @"))

def validateName(name: String): Either[NonEmptyList[String], String] =
  if name.nonEmpty then Right(name)
  else Left(NonEmptyList.one("Name cannot be empty"))

def validateUser(name: String, email: String): Either[NonEmptyList[String], User] =
  (validateName(name), validateEmail(email)).mapN((n, e) => User(n, e))
```

## Type-Safe API Endpoints

```scala
import sttp.tapir.*
import sttp.tapir.generic.auto.*

object MyEndpoints:
  val userEndpoint = endpoint
    .in("users" / path[String]("id"))
    .get(out(jsonBody[User]))

case class User(name: String, email: String)

def validateUser(name: String, email: String): Either[String, User] =
  if name.nonEmpty && email.contains("@")
  then Right(User(name, email))
  else Left("Invalid user data")
```

## Scala 2 to 3 Migration — Type System Changes

### Object Syntax

```scala
// Scala 2:
object A {
  type T = B
  def f(x: B) = x.toString
}

// Scala 3:
object A:
  type T = B
  def f(x: B): String = x.toString
```

### Implicit → Using

```scala
// Scala 2:
def foo(implicit x: A, y: B): C

// Scala 3:
def foo(using x: A, y: B): C
```

### Import Improvements

```scala
// Scala 2:
import scala.collection.mutable.Map

// Scala 3:
import scala.collection.mutable as Mutable
import scala.collection.mutable.{Map as MutableMap}
```

### Refactoring Checklist

1. Update object syntax to use `object A:`
2. Replace `implicit` parameters with `using`
3. Replace `implicitly` with `summon`
4. Use import aliasing for conflicting imports
5. Update function syntax to use `:` for return types
6. Use match types for type-level programming
7. Leverage given/using for type classes
8. Replace `implicit class` with `extension` methods
9. Use literal types for strict typing
