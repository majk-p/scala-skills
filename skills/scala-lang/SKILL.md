---
name: scala-lang
description: Use this skill when working with Scala 3 language features, syntax, type system, metaprogramming, or migrating from Scala 2. Covers import aliasing, given/using, structural types, intersection/union types, pattern matching, match types, GADTs, dependent types, inline methods, macros, TASTY inspectors, compile-time operations, and Scala 2-to-3 migration. Trigger when the user mentions Scala 3, Dotty, given/using, inline, macros, match types, GADTs, extension methods, structural types, Scala migration, type-level programming, metaprogramming, TASTY, or any Scala language feature question — even if they don't explicitly say "Scala 3".
---

# Scala 3 Language Features

Scala 3 (Dotty) is a modern version of Scala with improved syntax, a more powerful type system, and a new compiler written in Scala 3 itself. It maintains interoperability with Scala 2 while introducing significant language improvements.

## Quick Start

```scala
// Basic Scala 3 program
@main def hello(): Unit =
  val greeting = "Hello, Scala 3!"
  println(greeting)

  val numbers = List(1, 2, 3, 4, 5)
  val doubled = numbers.map(_ * 2)
  println(doubled)

// Given/using syntax
trait Show[T]:
  def show(value: T): String

given Show[Int] with
  def show(value: Int): String = value.toString

def printShow[T](value: T)(using s: Show[T]): Unit =
  println(s.show(value))

printShow(42)  // "42"
```

## Core Concepts

### New Syntax

Scala 3 uses optional braces with significant indentation, `using` instead of `implicit`, and cleaner control flow:

```scala
// Optional braces
object A:
  type T = B
  def f(x: B): String = x.toString

// if/then/else, for/do
if x > 0 then "positive" else "non-positive"
for x <- List(1, 2, 3) yield x * 2
```

### Import Aliasing

```scala
import scala.collection.immutable.{List as ImmutableList}
import scala.collection.mutable.{Map as MutableMap}
import scala.collection.mutable as Mut
```

### Given/Using (Type Classes)

```scala
// Define type class
trait Show[T]:
  def show(value: T): String

// Instances
given Show[Int] with
  def show(value: Int): String = value.toString

given Show[String] with
  def show(value: String): String = value

// Usage
def printShow[T](value: T)(using s: Show[T]): Unit =
  println(s.show(value))

// Context bounds
def process[T: Show: Ordering](values: List[T]): Unit =
  val sorted = values.sorted
  sorted.foreach(v => println(summon[Show[T]].show(v)))
```

### Extension Methods

```scala
extension [A](list: List[A])
  def headOption: Option[A] = list.headOption
  def tailOption: Option[List[A]] = list.tailOption

List(1, 2, 3).headOption  // Some(1)
```

### Intersection and Union Types

```scala
// Intersection — has members of both
trait Named { def name: String }
trait Aged { def age: Int }
type Person = Named & Aged

// Union — has members of either
type Numeric = Int | Float | Double
type Result[T] = Either[Error, T]
```

### Structural Typing

```scala
type PersonLike = { def name: String; def age: Int }

val person = new { def name: String = "Alice"; def age: Int = 30 }

def greet(who: PersonLike): Unit =
  println(s"Hello, ${who.name}!")
```

### Pattern Matching

```scala
// Type-based matching
def process(value: Any): String = value match
  case _: String => "String"
  case _: Int    => "Int"
  case _: List[_] => "List"
  case _         => "Unknown"

// With guards
def classify(n: Int): String = n match
  case n if n > 0 => "positive"
  case n if n < 0 => "negative"
  case _          => "zero"

// Nested patterns
case class Person(name: String, address: Address)
case class Address(street: String, city: String)

def greet(person: Person): String = person match
  case Person(name, Address(_, city)) => s"$name from $city"
```

## Common Patterns

### Option Handling

```scala
val maybeValue: Option[Int] = Some(42)

maybeValue match
  case Some(value) => println(s"Found: $value")
  case None        => println("No value")

val result = maybeValue.map(_ * 2)
val safe = maybeValue.getOrElse(0)
```

### Error Handling

```scala
import scala.util.*

val success: Try[Int] = Try(42 / 2)
val failure: Try[Int] = Try(42 / 0)

success.get              // 21
failure.getOrElse(-1)    // -1

Try("hello".toInt) match
  case Success(value) => println(s"Parsed: $value")
  case Failure(e)     => println(s"Failed: ${e.getMessage}")
```

### Smart Constructors

```scala
object Either:
  def left[A](value: A): Either[Error, A] = Left(value)
  def right[A](value: A): Either[Error, A] = Right(value)

object Option:
  def when[A](cond: Boolean)(value: => A): Option[A] =
    if cond then Some(value) else None
```

### Inline and Const

```scala
// Compile-time constants
inline val configVersion: String = "1.0.0"
const val MAX_SIZE: Int = 100

// Compile-time evaluation
inline def factorial(n: Int): Int =
  if n <= 1 then 1
  else n * factorial(n - 1)

// Inline with macro
inline def optimized[T](value: T): T = ${ optimizedImpl[T]('value) }
```

## Advanced Patterns

### Match Types

```scala
type Elem[X] = X match
  case String      => Char
  case Array[t]    => t
  case Iterable[t] => t
  case Any         => X

// Type-level conditionals
type If[Cond, TrueType, FalseType] = Cond match
  case true  => TrueType
  case false => FalseType
```

### GADTs

```scala
sealed trait Expr[T]
case class Const(value: Int)              extends Expr[Int]
case class Add(lhs: Expr[Int], rhs: Expr[Int]) extends Expr[Int]
case class IsZero(expr: Expr[Int])        extends Expr[Boolean]
case class IfExpr[A](cond: Expr[Boolean],
                     thenExpr: Expr[A],
                     elseExpr: Expr[A])  extends Expr[A]

def eval[T](expr: Expr[T]): T = expr match
  case Const(v)        => v
  case Add(l, r)       => eval(l) + eval(r)
  case IsZero(e)       => eval(e) == 0
  case IfExpr(c, t, e) => if eval(c) then eval(t) else eval(e)
```

### Dependent and Higher-Kinded Types

```scala
// Higher-kinded type classes
trait Functor[F[_]]:
  def map[A, B](fa: F[A])(f: A => B): F[B]

trait Monad[F[_]]:
  def pure[A](a: A): F[A]
  def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B]

def liftF[F[_]: Monad, A](a: A): F[A] = summon[Monad[F]].pure(a)
```

### Macros and Quoted Code

```scala
import scala.quoted.*

inline def classify[T](value: T): String = ${ classifyImpl[T]('value) }

private def classifyImpl[T: Type](value: Expr[T])(using Quotes): Expr[String] =
  import quotes.*
  import quotes.reflect.*

  value match
    case Literal(Constant(v: Int)) if v > 0 => '{ "positive" }
    case Literal(Constant(v: Int)) if v < 0 => '{ "negative" }
    case Literal(Constant(v: Int))           => '{ "zero" }
    case _                                   => '{ "other" }
```

### TASTY Inspectors

```scala
import scala.tasty.inspector.*

class MyInspector extends Inspector:
  def inspectTree(tree: Tree): Unit = tree match
    case DefDef(name, typeParams, paramLists, returnType, body) =>
      println(s"Found function: $name")
    case ClassDef(name, typeParams, parents, self, body) =>
      println(s"Found class: $name")
    case ValDef(name, tpe, init) =>
      println(s"Found field: $name")
    case _ => ()
```

## Scala 2 to 3 Migration

### Key Syntax Changes

```scala
// Scala 2:
def foo(implicit x: A, y: B): C

// Scala 3:
def foo(using x: A, y: B): C

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

### Migration Checklist

1. Replace `implicit` parameters with `using`
2. Replace `implicitly` with `summon`
3. Update brace syntax to optional-brace indentation
4. Use import aliasing for conflicting imports
5. Replace `implicit def` conversions with `given` instances
6. Update pattern matching to use new exhaustiveness checking
7. Replace `implicit class` with `extension` methods
8. Use `match types` instead of type projections where applicable

## Dependencies

```scala
// Scala 3 compiler and library — check for latest version
scalaVersion := "3.x"

// Core dependencies — check for latest version
libraryDependencies ++= Seq(
  "org.scala-lang" % "scala3-library" % scalaVersion.value,
  "org.typelevel" %% "cats-core" % "2.10.+",       // FP foundations
  "org.scalameta" %% "munit" % "1.0.+"             // Testing
)

// Macro support — check for latest version
libraryDependencies ++= Seq(
  "org.scala-lang" % "scala3-compiler" % scalaVersion.value,
  "org.scala-lang" % "scala3-tasty-inspector" % scalaVersion.value
)
```

## Related Skills

- **scala-async-effects** — ZIO and cats-effect for async, concurrency, and resource management
- **scala-streaming** — fs2 functional stream processing in Scala 3
- **scala-json-circe** — JSON encoding/decoding with circe in Scala 3
- **scala-fp-patterns** — tagless final, type class derivation, and FP patterns

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/basics.md** — Scala 3 syntax, imports, structural types, smart constructors, given/using, pattern matching, collections, option/try handling, null safety
- **references/advanced-types.md** — match types, GADTs, dependent types, intersection/union types, type-level programming, higher-kinded types, type class context bounds, type-safe validation
- **references/macros.md** — inline methods, macros, quoted code, TASTY inspectors, compile-time operations, compile-time string/number ops, macro testing, extension methods, pattern matching with guards
