# Scala 3 Macros & Metaprogramming Reference

## Inline Methods

### Basic Inline

```scala
inline val configVersion: String = "1.0.0"
const val MAX_SIZE: Int = 100
const val PI: Double = 3.141592653589793

inline def factorial(n: Int): Int =
  if n <= 1 then 1
  else n * factorial(n - 1)

inline def power(base: Int, exp: Int): Int =
  if exp == 0 then 1
  else base * power(base, exp - 1)
```

### Inline with Macro Delegation

```scala
inline def optimized[T](value: T): T = ${ optimizedImpl[T]('value) }

private def optimizedImpl[T: Type](value: Expr[T])(using Quotes): Expr[T] =
  import quotes.*
  import quotes.reflect.*

  value match
    case Literal(Constant(_)) => value
    case _ => '{ ${value}.optimized }
```

## Macro Annotations

```scala
import scala.annotation.*

@Target({Field})
macro inline def compileTimeCheck(): Unit = ${ compileTimeCheckImpl }

private def compileTimeCheckImpl(using Quotes): Expr[Unit] =
  import quotes.*
  import quotes.reflect.*

  '{ println("Compile-time check executed") }

@compileTimeCheck()
class MyClass
```

## Quasi-Quotation

### Basic Quasi-Quotation

```scala
import scala.quoted.*

inline def optimized[T](value: T): T = ${ optimizedImpl[T]('value) }

private def optimizedImpl[T: Type](value: Expr[T])(using Quotes): Expr[T] =
  import quotes.*
  import quotes.reflect.*

  value match
    case Literal(Constant(_)) => value
    case _ => '{ ${value}.optimized }
```

### Complex Quasi-Quotation

```scala
inline def createList[T](values: T*): List[T] = ${ createListImpl[T]('values) }

private def createListImpl[T: Type](values: Expr[Seq[T]])(using Quotes): Expr[List[T]] =
  import quotes.*
  import quotes.reflect.*

  values match
    case Literal(ConstantSeq(_)) => values
    case _ => '{ ${values}.toList }
```

## TASTY Inspectors

### Basic Inspector

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

### Advanced Inspection

```scala
class CodeAnalyzer(using Quotes) extends Inspector:
  def inspectTree(tree: Tree): Unit = tree match
    case DefDef(name, typeParams, paramLists, returnType, body) =>
      println(s"Function: $name with type params: $typeParams")
      println(s"  Parameters: $paramLists")
      println(s"  Return type: $returnType")
    case ClassDef(name, typeParams, parents, self, body) =>
      println(s"Class: $name with type params: $typeParams")
      println(s"  Parents: $parents")
      println(s"  Self type: $self")
    case Literal(Constant(value)) =>
      println(s"Literal: $value")
    case _ => ()
```

### TASTY Pattern Matching

```scala
class TypeAnalyzer(using Quotes) extends Inspector:
  def inspectTree(tree: Tree): Unit = tree match
    case DefDef(name, typeParams, paramLists, returnType, body) =>
      println(s"Function: $name")
      println(s"Type params: ${typeParams.map(_.tpt.show)}")
      println(s"Return type: ${returnType.show}")
    case ClassDef(name, typeParams, parents, self, body) =>
      println(s"Class: $name")
      println(s"Parents: ${parents.map(_.show)}")
    case ValDef(name, tpe, init) =>
      println(s"Field: $name with type: ${tpe.show}")
    case Import(expr, selectors) =>
      println(s"Import: ${expr.show} with selectors: ${selectors}")
    case _ => ()
```

## Compile-Time Computations

### Compile-Time Pattern Matching

```scala
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

### Compile-Time Type Classification

```scala
inline def getTypeName[T: Type](value: T): String = ${ getTypeNameImpl[T]('value) }

private def getTypeNameImpl[T: Type](value: Expr[T])(using Quotes): Expr[String] =
  import quotes.*
  import quotes.reflect.*

  TypeRepr.of[T].show match
    case "Int"     => '{ "Integer" }
    case "String"  => '{ "String" }
    case "Boolean" => '{ "Boolean" }
    case "Double"  => '{ "Double" }
    case _         => '{ "Other" }
```

### Compile-Time List/Array Creation

```scala
inline def listify[T](values: T*): List[T] = ${ listifyImpl[T]('values) }

private def listifyImpl[T: Type](values: Expr[Seq[T]])(using Quotes): Expr[List[T]] =
  import quotes.*
  import quotes.reflect.*

  values match
    case Literal(ConstantSeq(values)) =>
      values match
        case ConstantSeq()            => '{ List.empty[T] }
        case ConstantSeq(x, xs @ _*) => '{ List(x, xs*) }
    case _ => '{ ${values}.toList }

inline def arrayOf[T](values: T*): Array[T] = ${ arrayOfImpl[T]('values) }

private def arrayOfImpl[T: Type](values: Expr[Seq[T]])(using Quotes): Expr[Array[T]] =
  import quotes.*
  import quotes.reflect.*

  values match
    case Literal(ConstantSeq(values)) =>
      values match
        case ConstantSeq()            => '{ Array.empty[T] }
        case ConstantSeq(x, xs @ _*) => '{ Array(x, xs*) }
    case _ => '{ ${values}.toArray }
```

## Compile-Time String Operations

```scala
inline def concatStrings(s1: String, s2: String): String = ${ concatStringsImpl('s1, 's2) }

private def concatStringsImpl(s1: Expr[String], s2: Expr[String])(using Quotes): Expr[String] =
  import quotes.*
  import quotes.reflect.*

  (s1, s2) match
    case (Literal(Constant(a)), Literal(Constant(b))) => '{ a + b }
    case _ => '{ ${s1} + ${s2} }

inline def stringLength(s: String): Int = ${ stringLengthImpl('s) }

private def stringLengthImpl(s: Expr[String])(using Quotes): Expr[Int] =
  import quotes.*
  import quotes.reflect.*

  s match
    case Literal(Constant(str)) => '{ ${str}.length }
    case _ => '{ ${s}.length }
```

## Compile-Time Number Operations

```scala
inline def add(a: Int, b: Int): Int = ${ addImpl('a, 'b) }

private def addImpl(a: Expr[Int], b: Expr[Int])(using Quotes): Expr[Int] =
  import quotes.*
  import quotes.reflect.*

  (a, b) match
    case (Literal(Constant(x)), Literal(Constant(y))) => '{ x + y }
    case _ => '{ ${a} + ${b} }

inline def multiply(a: Int, b: Int): Int = ${ multiplyImpl('a, 'b) }

private def multiplyImpl(a: Expr[Int], b: Expr[Int])(using Quotes): Expr[Int] =
  import quotes.*
  import quotes.reflect.*

  (a, b) match
    case (Literal(Constant(x)), Literal(Constant(y))) => '{ x * y }
    case _ => '{ ${a} * ${b} }

inline def modulo(a: Int, b: Int): Int = ${ moduloImpl('a, 'b) }

private def moduloImpl(a: Expr[Int], b: Expr[Int])(using Quotes): Expr[Int] =
  import quotes.*
  import quotes.reflect.*

  (a, b) match
    case (Literal(Constant(x)), Literal(Constant(y))) => '{ x % y }
    case _ => '{ ${a} % ${b} }
```

## Performance Optimizations

### Inline Methods

```scala
inline def optimize[T](value: T): T = value

inline def cached[T](key: String)(fn: => T): T = ${ cachedImpl[T]('key) }

private def cachedImpl[T: Type](key: Expr[String])(using Quotes): Expr[T] =
  import quotes.*
  import quotes.reflect.*

  '{ lazy val cached_${key.show} = ${fn}; cached_${key.show} }
```

### Compile-Time Constants

```scala
const val numbers = Array(1, 2, 3, 4, 5)

inline val config: String = "production"
inline val debugMode: Boolean = false

def shouldLog(using debug: Boolean): Boolean = debug
```

### Efficient Macro Implementation

```scala
inline def smartClone[T](obj: T): T = ${ smartCloneImpl[T]('obj) }

private def smartCloneImpl[T: Type](obj: Expr[T])(using Quotes): Expr[T] =
  import quotes.*
  import quotes.reflect.*

  obj match
    case Literal(Constant(value)) => obj
    case _ => '{ ${obj}.clone() }
```

## Macro Testing

```scala
import munit.*

class MacroTests extends FunSuite:
  test("inline factorial should work"):
    val result = factorial(10)
    assertEquals(result, 3628800)

  test("inline add should work"):
    val result = add(3, 4)
    assertEquals(result, 7)

  test("inline multiply should work"):
    val result = multiply(3, 4)
    assertEquals(result, 12)

  test("inline modulo should work"):
    val result = modulo(10, 3)
    assertEquals(result, 1)
```

## Required Imports for Macros

```scala
import scala.annotation.*
import scala.compiletime.*
import scala.language.experimental.*
import scala.quoted.*
import scala.tasty.inspector.*
```

## Build Configuration for Macros

```scala
scalaVersion := "3.x"  // check for latest version

libraryDependencies ++= Seq(
  "org.scala-lang" % "scala3-compiler" % scalaVersion.value,
  "org.scala-lang" % "scala3-library" % scalaVersion.value,
  "org.scala-lang" % "scala3-tasty-inspector" % scalaVersion.value,
  "org.scalameta" %% "munit" % "1.0.+"  // check for latest version
)
```
