# Core Type Classes Reference

Complete API reference for Cats core type classes with code examples.

## Type Class Hierarchy

```
Functor
  |- Contravariant
  |- Invariant
  |- Apply
       |- Applicative
            |- Monad
                 |- MonadError
            |- Alternative
  |- FlatMap (deprecated in favor of Monad)
```

## Semigroup

A Semigroup is an algebraic structure with an associative binary operation.

```scala
import cats._
import cats.implicits._

// Definition
trait Semigroup[A] {
  def combine(x: A, y: A): A
}

// Built-in instances
Semigroup[Int].combine(2, 3)           // 5
Semigroup[String].combine("a", "b")      // "ab"
Semigroup[List[Int]].combine(List(1), List(2))  // List(1, 2)

// Syntax
2 |+| 3                                    // 5
"a" |+| "b"                                // "ab"
List(1, 2) |+| List(3, 4)                 // List(1, 2, 3, 4)

// Combining multiple
List(1, 2, 3).combineAll                // 6
Option(2).combineAllOption                 // Some(2)
None.combineAllOption[Int]                 // None

// Interleave (for collections)
List(1, 3, 5).interleave(List(2, 4))  // List(1, 2, 3, 4, 5)

// Custom instance
case class Vector(x: Int, y: Int)

given vectorSemigroup: Semigroup[Vector] = Semigroup.instance(
  (v1, v2) => Vector(v1.x + v2.x, v1.y + v2.y)
)

val v1 = Vector(1, 2)
val v2 = Vector(3, 4)
v1 |+| v2  // Vector(4, 6)

// Intersect semigroup
val intersectSemigroup = Semigroup.intersect[List[Int]]
intersectSemigroup.combine(List(1, 2, 3), List(2, 3, 4))  // List(2, 3)

// Union semigroup
val unionSemigroup = Semigroup.union[List[Int]]
unionSemigroup.combine(List(1, 2), List(3, 4))  // List(1, 2, 3, 4)

// First semigroup (always picks first)
val firstSemigroup = Semigroup.first[Int]
firstSemigroup.combine(1, 2)  // 1

// Last semigroup (always picks last)
val lastSemigroup = Semigroup.last[Int]
lastSemigroup.combine(1, 2)  // 2
```

## Monoid

A Monoid extends Semigroup with an identity element.

```scala
import cats._
import cats.implicits._

// Definition
trait Monoid[A] extends Semigroup[A] {
  def empty: A
}

// Built-in instances
Monoid[Int].empty                    // 0
Monoid[String].empty                  // ""
Monoid[List[Int]].empty               // List()
Monoid[Option[Int]].empty           // None

// Using empty identity
1 |+| Monoid[Int].empty               // 1
List(1, 2, 3) |+| List.empty[Int]  // List(1, 2, 3)

// Combining collections
List(1, 2, 3).combineAll           // 6
List("a", "b", "c").combineAll       // "abc"
List(Map("a" -> 1), Map("b" -> 2)).combineAll  // Map("a" -> 1, "b" -> 2)

// FoldMap - transform each element and combine
val lengths = List("hello", "world", "!").foldMap(_.length)  // 11
val sum = List("1", "2", "3").foldMap(_.toInt)  // 6

// Custom instance
case class Counter(count: Int)

given counterMonoid: Monoid[Counter] = Monoid.instance(
  Counter(0),
  (c1, c2) => Counter(c1.count + c2.count)
)

val counters = List(Counter(1), Counter(2), Counter(3))
counters.combineAll  // Counter(6)

// Dual monoid (reverses combine order)
val dual = Dual(List(1, 2))
Dual[Dual[List[Int]]].empty |+| dual  // Dual(List(2, 1))

// Product monoid (combine tuples)
val tupleMonoid = Monoid[(Int, String)]
tupleMonoid.empty  // (0, "")
(1, "a") |+| (2, "b")  // (3, "ab")
```

## Eq

Eq provides type-safe equality comparisons.

```scala
import cats._
import cats.implicits._

// Definition
trait Eq[A] {
  def eqv(x: A, y: A): Boolean
}

// Built-in instances
Eq[Int].eqv(1, 1)              // true
Eq[Int].eqv(1, 2)              // false
Eq[String].eqv("a", "a")        // true

// Syntax
1 === 1                           // true
1 =!= 2                           // true

// Comparing collections
List(1, 2, 3) === List(1, 2, 3)  // true
List(1, 2, 3) =!= List(1, 2)       // true

// Comparing options
Some(1) === Some(1)              // true
Some(1) === None                 // false
None[Int] === None[Int]           // true

// Case class comparison
case class Person(name: String, age: Int)

given personEq: Eq[Person] = Eq.by(p => (p.name, p.age))

val p1 = Person("Alice", 30)
val p2 = Person("Alice", 30)
val p3 = Person("Bob", 30)
p1 === p2  // true
p1 === p3  // false

// Eq by specific field
given personNameEq: Eq[Person] = Eq.by(_.name)
Person("Alice", 30) === Person("Alice", 40)  // true

// Eq from specific function
given personEqFrom: Eq[Person] = Eq.fromUniversalEquals

// Negation
val neq = Eq[Int].neqv(1, 2)  // true

// InspectEq - for debugging
val inspector = Eq[Int].inspect("eq", _ + 1, _ * 2)
inspector.eqv(1, 2)  // Prints: eq: 2 vs 4
```

## Show

Show provides string representation of values.

```scala
import cats._
import cats.implicits._

// Definition
trait Show[A] {
  def show(t: A): String
}

// Built-in instances
Show[Int].show(42)              // "42"
Show[String].show("hello")        // "\"hello\""
Show[List[Int]].show(List(1, 2)) // "List(1, 2)"

// Syntax
42.show                           // "42"
"hello".show                     // "\"hello\""
List(1, 2, 3).show             // "List(1, 2, 3)"

// Custom instance
case class Point(x: Int, y: Int)

given pointShow: Show[Point] = Show.show(p => s"Point(${p.x}, ${p.y})")

val pt = Point(3, 4)
pt.show  // "Point(3, 4)"

// Show from toString
given showFromToString[A]: Show[A] = Show.fromToString

// Contravariant Show (for functions)
val showInt: Int => String = Show[Int].show
showInt(42)  // "42"
```

## Order

Order provides total ordering comparisons.

```scala
import cats._
import cats.implicits._

// Definition
trait Order[A] extends PartialOrder[A] with Eq[A] {
  def compare(x: A, y: A): Int
}

// Built-in instances
Order[Int].compare(1, 2)        // -1
Order[Int].compare(2, 1)        // 1
Order[Int].compare(1, 1)        // 0

// Syntax
1 < 2                            // true
1 <= 2                           // true
1 > 2                            // false
1 >= 2                           // false
1 compare 2                      // -1
1 min 2                         // 1
1 max 2                         // 2

// Sorting
List(3, 1, 2).sorted           // List(1, 2, 3)
List(3, 1, 2).sorted(Order[Int].reverse)  // List(3, 2, 1)

// Between
1.between(0, 2)                // true
1.between(2, 4)                // false

// Clamp
1.clamp(0, 2)                  // 1
3.clamp(0, 2)                  // 2
-1.clamp(0, 2)                 // 0

// Custom instance
case class Score(value: Int)

given scoreOrder: Order[Score] = Order.by(_.value)

Score(1) < Score(2)             // true
List(Score(3), Score(1), Score(2)).sorted  // List(Score(1), Score(2), Score(3))

// Order from Ordering
val orderBy = Order.fromOrdering[Int]
```

## PartialOrder

PartialOrder provides partial ordering (some values may not be comparable).

```scala
import cats._
import cats.implicits._

// Definition
trait PartialOrder[A] extends Eq[A] {
  def partialCompare(x: A, y: A): Double
}

// Built-in instances
PartialOrder[Double].partialCompare(1.0, 2.0)  // -1.0
PartialOrder[Double].partialCompare(Double.NaN, 1.0)  // Double.NaN

// Syntax
1.0 partialCompare 2.0           // -1.0
1.0 tryCompare 2.0              // Some(-1.0)
Double.NaN tryCompare 1.0        // None

// Custom partial order
case class Interval(start: Int, end: Int)

given intervalPartialOrder: PartialOrder[Interval] = PartialOrder.by { i =>
  (i.start, i.end)
}

val i1 = Interval(1, 5)
val i2 = Interval(2, 6)
i1 partialCompare i2  // -1.0
```

## Functor

Functor provides mapping over values in a context.

```scala
import cats._
import cats.implicits._

// Definition
trait Functor[F[_]] {
  def map[A, B](fa: F[A])(f: A => B): F[B]
}

// Built-in instances
List(1, 2, 3).map(_ + 1)               // List(2, 3, 4)
Option(3).map(_ + 1)                      // Some(4)
None[Int].map(_ + 1)                      // None

// Lift function to functor
val lifted: Int => Option[Int] = Functor[Option].lift(_ + 1)
lifted(3)  // Some(4)

// Fmap (function-first style)
Functor[Option].fmap(Option(3))(_ + 1)  // Some(4)

// As (replace with constant)
val listOption: List[Option[Int]] = List(Some(1), Some(2), None)
Functor[List].as(listOption, None)  // List(None, None, None)

// Void (replace all values with ())
List(1, 2, 3).void  // List((), (), ())

// Custom instance
case class Box[A](value: A)

given boxFunctor: Functor[Box] = new Functor[Box] {
  def map[A, B](fa: Box[A])(f: A => B): Box[B] = Box(f(fa.value))
}

Box(3).map(_ + 1)  // Box(4)

// Compose functors
val listOptionFunctor = Functor[List] compose Functor[Option]
val lo = List(Some(1), Some(2))
listOptionFunctor.map(lo)(_ + 1)  // List(Some(2), Some(3))
```

## Contravariant

Contravariant functor for types with type parameters in contravariant position.

```scala
import cats._
import cats.implicits._

// Definition
trait Contravariant[F[_]] {
  def contramap[A, B](fa: F[A])(f: B => A): F[B]
}

// Built-in instances
// Show is contravariant
Show[Int].contramap[String](_.length).show("hello")  // "5"

// Function1 is contravariant in first parameter
val intToString: Int => String = _.toString
val stringToString: String => String = Contravariant[Int => *].contramap(intToString)(_.length)
stringToString("hello")  // "5"

// Contramap syntax
val showInt: Show[Int] = Show[Int]
val showString: Show[String] = showInt.contramap(_.length)
showString.show("hello")  // "5"

// Custom contravariant instance
case class Predicate[A](check: A => Boolean)

given predicateContravariant: Contravariant[Predicate] = new Contravariant[Predicate] {
  def contramap[A, B](fa: Predicate[A])(f: B => A): Predicate[B] =
    Predicate(b => fa.check(f(b)))
}

val isEven: Predicate[Int] = Predicate(_ % 2 == 0)
val isEvenLength: Predicate[String] = isEven.contramap(_.length)
isEvenLength.check("hello")  // false (5 is odd)
```

## Invariant

Invariant functor for types with type parameters in both positions.

```scala
import cats._
import cats.implicits._

// Definition
trait Invariant[F[_]] {
  def imap[A, B](fa: F[A])(f: A => B)(g: B => A): F[B]
}

// Built-in instances
val showInt: Show[Int] = Show[Int]
val showLong: Show[Long] = Invariant[Show].imap(showInt)(_.toLong)(_.toInt)
showLong.show(42L)  // "42"

// Custom instance
case class Codec[A](encode: A => String, decode: String => A)

given codecInvariant: Invariant[Codec] = new Invariant[Codec] {
  def imap[A, B](fa: Codec[A])(f: A => B)(g: B => A): Codec[B] =
    Codec(
      a => fa.encode(g(a)),
      s => f(fa.decode(s))
    )
}

val intCodec: Codec[Int] = Codec(_.toString, _.toInt)
val longCodec: Codec[Long] = intCodec.imap(_.toLong)(_.toInt)
```

## Apply

Apply extends Functor with the ability to apply functions in context.

```scala
import cats._
import cats.implicits._

// Definition
trait Apply[F[_]] extends Functor[F] {
  def ap[A, B](ff: F[A => B])(fa: F[A]): F[B]
}

// Using ap
val add: Option[Int => Int] = Some(_ + 1)
Apply[Option].ap(add)(Some(3))  // Some(4)

// Using mapN
val result1 = (Option(1), Option(2)).mapN(_ + _)  // Some(3)
val result2 = (Option(1), Option(2), Option(3)).mapN(_ + _ + _)  // Some(6)

// Using map2, map3, etc.
val result3 = Apply[Option].map2(Option(1), Option(2))(_ + _)  // Some(3)

// Using product
val tuple = (Option(1), Option(2)).tupled  // Some((1, 2))

// Tuple operations
val triple = (1, 2, 3)
triple.mapN(_ + _ + _)  // 6

// Using map with Apply syntax
import cats.syntax.apply._
val result4 = (Option(1), Option(2)).mapN(_ + _)  // Some(3)

// Ap syntax
val func = Some((i: Int) => i + 1)
val result5 = func.ap(Some(3))  // Some(4)
```

## Applicative

Applicative extends Apply with the ability to lift pure values.

```scala
import cats._
import cats.implicits._

// Definition
trait Applicative[F[_]] extends Apply[F] {
  def pure[A](x: A): F[A]
}

// Pure values
Applicative[Option].pure(42)      // Some(42)
Applicative[List].pure(42)         // List(42)

// Replicate
Applicative[Option].replicateA(3, 1)  // List(Some(1), Some(1), Some(1))
Applicative[List].replicateA(2, 1)   // List(List(1, 1))

// Unit
Applicative[List].unit                // List(())

// Custom instance
case class Id[A](value: A)

given idApplicative: Applicative[Id] = new Applicative[Id] {
  def pure[A](x: A): Id[A] = Id(x)
  def ap[A, B](ff: Id[A => B])(fa: Id[A]): Id[B] = Id(ff.value(fa.value))
}
```

## FlatMap

FlatMap provides flatMap/bind operation (deprecated in favor of Monad).

```scala
import cats._
import cats.implicits._

// Definition
trait FlatMap[F[_]] extends Apply[F] {
  def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B]
}

// Using flatMap
Option(3).flatMap(x => Option(x + 1))  // Some(4)
Option(3).flatMap(_ => None)           // None

// TailRecM for stack-safe recursion
import cats.syntax.all._

def sumList(list: List[Int]): Int = list.foldM(0)(_ + _)
sumList(List(1, 2, 3))  // 6

def factorial(n: Int): Int = (1 to n).foldM(1)(_ * _)
factorial(5)  // 120

// Flatten nested structures
List(List(1, 2), List(3, 4)).flatten  // List(1, 2, 3, 4)
Option(Option(1)).flatten  // Some(1)
Option(None).flatten  // None
```

## Monad

Monad extends FlatMap with Applicative.

```scala
import cats._
import cats.implicits._

// Definition
trait Monad[F[_]] extends FlatMap[F] with Applicative[F]

// For-comprehension
val result = for {
  x <- Option(3)
  y <- Option(4)
} yield x + y  // Some(7)

// ifM - conditional in monad context
val ifResult = Monad[Option].ifM(Option(true))(
  Option("yes"),
  Option("no")
)  // Some("yes")

// whileM - while loop
var counter = 0
Monad[Option].whileM(
  Option(counter < 3),
  Option(counter += 1)
)  // Some(())

// untilM - until loop
var i = 0
Monad[Option].untilM(
  Option(i >= 3),
  Option(i += 1)
)  // Some(())

// iterateWhileM
val iterated = Monad[List].iterateWhileM(1)(x => if (x < 5) Some(List(x, x + 1)) else None)
// List(1, 2, 3, 4, 5)

// iterateUntilM
val iterated2 = Monad[List].iterateUntilM(1)(x => if (x >= 5) Some(List(x)) else None)
// List(1, 2, 3, 4, 5)

// FilterM with effect
val filtered = List(1, 2, 3, 4).filterM(x => Option(x % 2 == 0))
// Some(List(2, 4))
```

## MonadError

MonadError provides error handling capabilities.

```scala
import cats._
import cats.implicits._

// Definition
trait MonadError[F[_], E] extends Monad[F] {
  def raiseError[A](e: E): F[A]
  def handleErrorWith[A](fa: F[A])(f: E => F[A]): F[A]
}

// Raising errors
val raised = MonadError[Option, Unit].raiseError[Int](())  // None
val raisedEither = MonadError[Either[String, *], String].raiseError[Int]("error")
// Left("error")

// Handling errors
val handled = Option(3).handleErrorWith[Unit, Int](_ => Option(0))  // Some(3)
val handled2 = None[Int].handleErrorWith[Unit, Int](_ => Option(0))  // Some(0)

// Ensure - always run even on error
val ensured = Option(3).ensure(new Exception("Too small"))(_ > 5)  // Some(3)
val ensured2 = Option(3).ensure(new Exception("Too small"))(_ < 5)  // None

// Adapt - convert error type
val adapted = MonadError[Option, String].adaptError[Unit, String](_ => "converted")

// Recover
val recovered = Option(3).recover { case () => 0 }  // Some(3)
val recovered2 = None[Int].recover { case () => 0 }  // Some(0)

// RecoverWith
val recovered3 = None[Int].recoverWith { case () => Option(0) }  // Some(0)
```

## Alternative

Alternative provides choice operations for Applicative Functors.

```scala
import cats._
import cats.implicits._

// Definition
trait Alternative[F[_]] extends Applicative[F] with MonoidK[F]

// OrElse
val orElse1 = Option(1).orElse(Option(2))  // Some(1)
val orElse2 = None[Int].orElse(Option(2))   // Some(2)

// Using <+>
val combined1 = Option(1) <+> Option(2)  // Some(1)
val combined2 = None[Int] <+> Option(2)  // Some(2)

// Guard
val filtered = List(1, 2, 3, 4).filterA(x => Alternative[List].guard(x % 2 == 0))
// List(2, 4)

// Separate
val separated = List(Some(1), None, Some(2), None).separate
// (List(1, 2), List(None, None))

// Unite
val united = List(Some(1), None, Some(2), None).unite
// List(1, 2)

// Optional
val optional1 = Option(1).optional  // Some(1)
val optional2 = None[Int].optional      // None
```

## Foldable

Foldable provides folding operations for data structures.

```scala
import cats._
import cats.implicits._

// Definition
trait Foldable[F[_]] {
  def foldLeft[A, B](fa: F[A], b: B)(f: (B, A) => B): B
  def foldRight[A, B](fa: F[A], lb: Eval[B])(f: (A, Eval[B]) => Eval[B]): Eval[B]
}

// Fold left
val fold1 = List(1, 2, 3).foldLeft(0)(_ + _)  // 6

// Fold right
val fold2 = List(1, 2, 3).foldRight(0)(_ + _)  // 6

// Fold
val fold3 = List(1, 2, 3).fold  // 6

// Find
val find1 = List(1, 2, 3).find(_ % 2 == 0)  // Some(2)
val find2 = List(1, 2, 3).find(_ > 10)   // None

// Exists
val exists1 = List(1, 2, 3).exists(_ % 2 == 0)  // true
val exists2 = List(1, 2, 3).exists(_ > 10)   // false

// Forall
val forall1 = List(1, 2, 3).forall(_ < 10)  // true
val forall2 = List(1, 2, 3).forall(_ > 0)   // true

// ToList
val list1 = Option(3).toList  // List(3)
val list2 = None[Int].toList  // List()

// Filter
val filtered1 = List(1, 2, 3, 4).filter(_ % 2 == 0)  // List(2, 4)

// FilterA - effectful filter
val filtered2 = List(1, 2, 3, 4).filterA(x => Option(x % 2 == 0))  // Some(List(2, 4))

// Partition
val partitioned = List(1, 2, 3, 4).partition(_ % 2 == 0)
// (List(2, 4), List(1, 3))

// Drop
val dropped = List(1, 2, 3, 4).drop(2)  // List(3, 4)

// Take
val taken = List(1, 2, 3, 4).take(2)  // List(1, 2)

// Intersect
val intersected = List(1, 2, 3).intersect(List(2, 3, 4))  // List(2, 3)

// Distinct
val distinct = List(1, 2, 2, 3, 3, 4).distinct  // List(1, 2, 3, 4)
```

## Traverse

Traverse combines Foldable and Functor, allowing traversal with effects.

```scala
import cats._
import cats.implicits._

// Definition
trait Traverse[F[_]] extends Functor[F] with Foldable[F] {
  def traverse[G[_]: Applicative, A, B](fa: F[A])(f: A => G[B]): G[F[B]]
}

// Sequence
val seq1 = List(Some(1), Some(2), Some(3)).sequence  // Some(List(1, 2, 3))
val seq2 = List(Some(1), None, Some(3)).sequence   // None

// Traverse
val trav1 = List(1, 2, 3).traverse(x => Some(x * 2))  // Some(List(2, 4, 6))
val trav2 = List(1, 2, 3).traverse(x => if (x == 2) None else Some(x * 2))
// None

// With cats-effect
import cats.effect._

val ioSeq = List(IO.pure(1), IO.pure(2), IO.pure(3)).sequence  // IO(List(1, 2, 3))
val ioTrav = List(1, 2, 3).traverse(x => IO.pure(x * 2))  // IO(List(2, 4, 6))

// Parallel traverse
val parTrav = List(1, 2, 3).parTraverse(x => IO.pure(x * 2))  // IO(List(2, 4, 6))

// Sequence with parallel
val parSeq = List(IO.pure(1), IO.pure(2), IO.pure(3)).parSequence  // IO(List(1, 2, 3))
```

## Error Handling Patterns

### Safe Traverse Operations

```scala
import cats.data.Validated
import cats.data.ValidatedNec

def traverseValidated[A, B, E](list: List[A])(f: A => Validated[E, B]): Validated[List[E], List[B]] =
  list.traverse(f).leftMap(_ :: Nil)

def parTraverseNec[A, B, E](list: List[A])(f: A => ValidatedNec[E, B]): ValidatedNec[E, List[B]] =
  list.traverse(f)
```

### MonadError Integration

```scala
import cats.MonadError

def handleWith[F[_], A, E](fa: F[A])(handler: E => F[A])(implicit F: MonadError[F, E]): F[A] =
  F.recoverWith(fa)(handler)

def attempt[F[_], A, E](fa: F[A])(implicit F: MonadError[F, E]): F[Either[E, A]] =
  F.attempt(fa)
```
