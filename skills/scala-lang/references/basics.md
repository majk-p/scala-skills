# Scala 3 Basics Reference

## Imports

```scala
import scala.annotation.*
import scala.compiletime.*
import scala.collection.*
import scala.concurrent.*
import scala.language.{*, given}
```

### Import Aliasing

```scala
import scala.collection.immutable.{List as ImmutableList}
import scala.collection.mutable.{Map as MutableMap}
import scala.collection.mutable as Mut
import scala.util.{Try as Optional}
```

## Given/Using Syntax

```scala
// Define type class
trait Show[T]:
  def show(value: T): String

// Instances
given Show[Int] with
  def show(value: Int): String = value.toString

given Show[String] with
  def show(value: String): String = value

// Usage with using
def printShow[T](value: T)(using s: Show[T]): Unit =
  println(s.show(value))

// Summon explicitly
val intShow = summon[Show[Int]]

// Context bounds
def process[T: Show: Ordering](values: List[T]): Unit =
  val sorted = values.sorted
  sorted.foreach(v => println(summon[Show[T]].show(v)))
```

## Extension Methods

```scala
extension [A](list: List[A])
  def headOption: Option[A] = list.headOption
  def tailOption: Option[List[A]] = list.tailOption
  def partition(pred: A => Boolean): (List[A], List[A]) =
    list.partition(pred)

// Usage
List(1, 2, 3).headOption   // Some(1)
List(1, 2, 3).tailOption   // Some(List(2, 3))
```

## Structural Typing

```scala
type PersonLike = { def name: String; def age: Int }

val person = new { def name: String = "Alice"; def age: Int = 30 }

def greet(who: PersonLike): Unit =
  println(s"Hello, ${who.name}!")

greet(person)
```

## Smart Constructors

```scala
object Either:
  def left[A](value: A): Either[Error, A] = Left(value)
  def right[A](value: A): Either[Error, A] = Right(value)

object Option:
  def when[A](cond: Boolean)(value: => A): Option[A] =
    if cond then Some(value) else None
```

## Pattern Matching

### Basic Matching

```scala
def process(value: Any): String = value match
  case _: String  => "String"
  case _: Int     => "Int"
  case _: List[_] => "List"
  case _          => "Unknown"
```

### With Guards

```scala
def classify(n: Int): String = n match
  case n if n > 0 => "positive"
  case n if n < 0 => "negative"
  case _          => "zero"

def process(value: Any): Unit = value match
  case x: Int if x > 0 => println(s"Positive int: $x")
  case x: Int if x < 0 => println(s"Negative int: $x")
  case x: String       => println(s"String: $x")
  case _               => println("Other")
```

### Nested Patterns

```scala
case class Person(name: String, address: Address)
case class Address(street: String, city: String)

def greet(person: Person): String = person match
  case Person(name, Address(_, city)) => s"$name from $city"
```

### Sealed Trait Matching

```scala
sealed trait Notification
case class Email(sender: String, title: String, body: String) extends Notification
case class SMS(number: String, message: String) extends Notification
case class VoiceRecording(name: String, link: String) extends Notification

def notifyAll(notifications: Notification*): Unit = notifications.foreach
  case Email(sender, title, _)     => println(s"Email from $sender: $title")
  case SMS(number, message)        => println(s"SMS from $number: $message")
  case VoiceRecording(name, link)  => println(s"Voice from $name: $link")
```

## Option Handling

```scala
val some: Option[Int] = Some(1)
val none: Option[Int] = None

some.map(_ * 2)            // Some(2)
some.flatMap(x => Some(x)) // Some(1)
some.getOrElse(0)          // 1
some.orElse(Some(5))       // Some(1)
some.fold(0)(_ * 2)        // 2

// Pattern matching
maybeValue match
  case Some(value) => println(s"Found: $value")
  case None        => println("No value")
```

## Error Handling

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

## Collections

```scala
val list = List(1, 2, 3, 4, 5)
val doubled = list.map(_ * 2)
val filtered = list.filter(_ % 2 == 0)
val flat = list.flatMap(List(_, _ * 2))
val grouped = list.grouped(2).toList
val sorted = list.sorted
```

## Intersection and Union Types

```scala
// Intersection — members from both types
type Container[A, B] = A & B

trait Named { def name: String }
trait Aged { def age: Int }
type Person = Named & Aged

// Union — members from either type
type Numeric = Int | Float | Double
type EitherOr[A, B] = A | B

// Type aliases
type Person = { name: String; age: Int }
type Result[T] = Either[Error, T]
```

## Null Safety

```scala
val maybeNull: Option[String] = Some("hello")
val safe = maybeNull.map(_.toUpperCase)
val safeOrNull = maybeNull.orNull
```

## Inline and Const

```scala
// Compile-time constants
inline val configVersion: String = "1.0.0"
const val MAX_SIZE: Int = 100
const val PI: Double = 3.141592653589793

// Compile-time evaluation
inline def factorial(n: Int): Int =
  if n <= 1 then 1
  else n * factorial(n - 1)

// Inline with macro delegation
inline def optimized[T](value: T): T = ${ optimizedImpl[T]('value) }
```

## Build Configuration

### build.sbt

```scala
scalaVersion := "3.x"  // check for latest version

libraryDependencies ++= Seq(
  "org.scala-lang" % "scala3-library" % scalaVersion.value,
  "org.typelevel" %% "cats-core" % "2.10.+",       // check for latest version
  "org.scalameta" %% "munit" % "1.0.+"             // check for latest version
)
```

## Scala 2 to 3 Syntax Changes

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
