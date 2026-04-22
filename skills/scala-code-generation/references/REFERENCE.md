# Code Generation & Metaprogramming - Complete Reference

Complete reference for code generation, metaprogramming, and generic programming libraries in Scala.

---

## Table of Contents

- [Magnolia Reference](#magnolia-reference)
- [Scalameta Reference](#scalameta-reference)
- [Simulacrum Reference](#simulacrum-reference)
- [Scalatex Reference](#scalatex-reference)
- [Kind-Projector Reference](#kind-projector-reference)
- [Macro Annotation Patterns](#macro-annotation-patterns)
- [Cross-Compilation Strategies](#cross-compilation-strategies)

---

## Magnolia Reference

Magnolia provides easy, fast, transparent generic derivation of typeclass instances for Scala 3.

### Core Types

```scala
package magnolia1

// Generic derivation context
trait Derivation[T[_]]:
  def join[T](ctx: CaseClass[T, ?]): T[T]
  def split[T](ctx: SealedTrait[T, ?]): T[T]

// Auto-derivation trait
trait AutoDerivation[T[_]] extends Derivation[T]:
  def autoDerived[T](using Type[T]): T[T]

// Semi-auto derivation
trait Derivation[T[_]]:
  def derived[T](using Type[T]): T[T]

// Case class context
trait CaseClass[Typeclass[_], Type]:
  def typeInfo: TypeInfo
  def params: Seq[Param[Typeclass, Type]]
  def isObject: Boolean
  def isCaseClass: Boolean

// Sealed trait context
trait SealedTrait[Typeclass[_], Type]:
  def typeInfo: TypeInfo
  def subtypes: Seq[Subtype[Typeclass, Type]]
  def isEnum: Boolean
  def isSealedTrait: Boolean

// Parameter context
trait Param[Typeclass[_], Type]:
  def label: String
  def index: Int
  def repeated: Boolean
  def typeclass: Typeclass[ParamType]
  def typeInfo: TypeInfo
  def deref(value: Type): ParamType
  def default: Option[Type]

// Subtype context
trait Subtype[Typeclass[_], Type]:
  def typeInfo: TypeInfo
  def typeclass: Typeclass[Subtype]
  def cast(value: Type): Subtype
  def anns: Seq[Any]
  def isType: Boolean
  def isObject: Boolean
  def isCaseClass: Boolean

// Type information
case class TypeInfo(
  owner: String,
  short: String,
  full: String,
  typeParams: Seq[TypeInfo]
  // Plus internal fields
)

// Choose method
sealed trait SealedTrait[Typeclass[_], Type]:
  def choose[Return](value: Type)(f: Subtype[Typeclass, Type] => Return): Return
}
```

### Basic Typeclass Derivation

```scala
import magnolia1.*

// Define typeclass
trait Eq[T]:
  extension (x: T) def ===(y: T): Boolean

// Create derivation
object Eq extends AutoDerivation[Eq]:
  def join[T](ctx: CaseClass[Eq, T]): Eq[T] = (x, y) =>
    ctx.params.forall { param =>
      param.typeclass.===(param.deref(x), param.deref(y))
    }

  def split[T](ctx: SealedTrait[Eq, T]): Eq[T] = (x, y) =>
    ctx.choose(x) { subx =>
      ctx.choose(y) { suby =>
        subx.typeclass.===(subx.cast(x), suby.cast(y))
      }
    }

  given Eq[Int] = _ == _
  given Eq[String] = _ == _
  given Eq[Boolean] = _ == _

// Use derivation
case class Person(name: String, age: Int)

// Auto derivation
given Eq[Person] = Eq.autoDerived[Person]

Person("Alice", 30) === Person("Alice", 30)  // true
```

### Product Types (Case Classes)

```scala
trait Show[T]:
  extension (x: T) def show: String

object Show extends AutoDerivation[Show]:
  def join[T](ctx: CaseClass[Show, T]): Show[T] = value =>
    val params = ctx.params.map { param =>
      val paramValue = param.deref(value)
      s"${param.label}=${param.typeclass.show(paramValue)}"
    }

    s"${ctx.typeInfo.short}(${params.mkString(", ")})"

// Nested case classes
case class Address(city: String, country: String)
case class User(name: String, address: Address)

given Show[Address] = Show.autoDerived[Address]
given Show[User] = Show.autoDerived[User]

User("Bob", Address("NYC", "USA")).show
// "User(name=Bob, address=Address(city=NYC, country=USA))"
```

### Sum Types (Sealed Traits/Enums)

```scala
sealed trait Shape
case class Circle(radius: Double) extends Shape
case class Rectangle(width: Double, height: Double) extends Shape

object ShapeShow extends AutoDerivation[Show]:
  def split[T](ctx: SealedTrait[Show, T]): Show[T] = value =>
    ctx.choose(value) { subtype =>
      s"${subtype.typeInfo.short}(${subtype.typeclass.show(subtype.cast(value))})"
    }

given Show[Shape] = ShapeShow.autoDerived[Shape]

Circle(5.0).show  // "Circle(5.0)"
```

### Recursive Types

```scala
case class TreeNode[T](value: T, left: Option[TreeNode[T]], right: Option[TreeNode[T]])

// IMPORTANT: Must assign to explicit variable for recursive types
given Show[Int] = _.toString

// Wrong: Will cause infinite recursion
// given Show[TreeNode[Int]] = Show.autoDerived[TreeNode[Int]]

// Correct: Explicit variable assignment
given showTreeNode: Show[TreeNode[Int]] = Show.autoDerived[TreeNode[Int]]
```

### Parameterized Types

```scala
case class Box[A](value: A)

given Show[Box[String]] = Show.autoDerived[Box[String]]

// Generic derivation works for any A: Show
given boxShow[A: Show]: Show[Box[A]] = Show.autoDerived[Box[A]]
```

### Covariant and Contravariant Positions

```scala
// Covariant typeclass (output position)
trait Encoder[-A]:
  def encode(a: A): String

object Encoder extends AutoDerivation[Encoder]:
  def join[T](ctx: CaseClass[Encoder, T]): Encoder[T] = value =>
    val encoded = ctx.params.map { param =>
      param.typeclass.encode(param.deref(value))
    }
    s"${ctx.typeInfo.short}(${encoded.mkString(", ")})"

  given Encoder[String] = identity
  given Encoder[Int] = _.toString

// Contravariant typeclass (input position)
trait Decoder[+A]:
  def decode(s: String): Either[String, A]

object Decoder extends AutoDerivation[Decoder]:
  def join[T](ctx: CaseClass[Decoder, T]): Decoder[T] = s =>
    // Implementation for contravariant types
    ???

  given Decoder[String] = Right(_)
  given Decoder[Int] = s => Try(s.toInt).toEither.left.map(_.getMessage)
```

### Combining Multiple Derivations

```scala
trait Encoder[T]:
  def encode(t: T): String

trait Decoder[T]:
  def decode(s: String): Either[String, T]

object Encoder extends AutoDerivation[Encoder]
object Decoder extends AutoDerivation[Decoder]

case class Data(id: Int, name: String)

// Derive both
given Encoder[Data] = Encoder.autoDerived[Data]
given Decoder[Data] = Decoder.autoDerived[Data]

val encoded = summon[Encoder[Data]].encode(Data(1, "test"))
val decoded = summon[Decoder[Data]].decode(encoded)
```

### Default Parameter Values

```scala
case class Config(
  host: String = "localhost",
  port: Int = 8080,
  debug: Boolean = false
)

// Compile with -Yretain-trees flag
// scalacOptions += "-Yretain-trees"

given Show[Config] = Show.autoDerived[Config]

Config().show  // "Config(host=localhost, port=8080, debug=false)"
```

### Annotation Access

```scala
case class Document(
  @fieldInfo("Unique identifier") id: String,
  @fieldInfo("User name") name: String
)

object Show extends AutoDerivation[Show]:
  def join[T](ctx: CaseClass[Show, T]): Show[T] = value =>
    ctx.params.map { param =>
      val info = param.anns.collectFirst { case a: fieldInfo => a.info }
      val value = param.typeclass.show(param.deref(value))
      s"${param.label}: $info -> $value"
    }.mkString(", ")
```

### Mutually Recursive Types

```scala
case class Company(name: String, employees: List[Person])
case class Person(name: String, company: Option[Company])

// Derive both simultaneously
given showPerson: Show[Person] = Show.autoDerived[Person]
given showCompany: Show[Company] = Show.autoDerived[Company]
```

### Semi-Auto Derivation

```scala
object Show extends Derivation[Show]:
  // No autoDerived method, only derived

// Explicitly request derivation
case class Custom(x: Int)
given Show[Custom] = Show.derived[Custom]

// Or customize after derivation
case class Special(value: Int)
given showSpecial: Show[Special] = {
  val base = Show.derived[Special]
  new Show[Special]:
    extension (s: Special) def show: String =
      s"Special(${base.show(s.value)})"
}
```

### Advanced Pattern: Combining Derivations

```scala
trait Encoder[T]
trait Hash[T]
trait Comparable[T]

object Encoder extends AutoDerivation[Encoder]
object Hash extends AutoDerivation[Hash]
object Comparable extends AutoDerivation[Comparable]

// Derive all for one type
case class User(id: Int, name: String)

given Encoder[User] = Encoder.autoDerived[User]
given Hash[User] = Hash.autoDerived[User]
given Comparable[User] = Comparable.autoDerived[User]

// Generic derivation for any type with all three
given encodeHashCompare[T: Encoder: Hash: Comparable]: Unit = ()
```

### Common Magnolia Gotchas

1. **Recursive types**: Must assign to explicit `given` variable
2. **Default values**: Need `-Yretain-trees` compiler flag
3. **Type parameters**: Work for any type with proper typeclass instances
4. **Variance**: Supports both covariant and contravariant typeclasses
5. **Enum support**: Works with Scala 3 enums out of the box

---

## Scalameta Reference

Scalameta is a library to read, analyze, transform, and generate Scala programs using AST (Abstract Syntax Trees).

### Installation

```scala
// build.sbt
libraryDependencies += "org.scalameta" %% "scalameta" % "4.15.0"

// For Scala.js or Scala Native
libraryDependencies += "org.scalameta" %%% "scalameta" % "4.15.0"
```

### Core Import

```scala
import scala.meta._
```

### AST Tree Types

```scala
// Root tree type
sealed trait Tree

// Main tree categories
sealed trait Stat extends Tree  // Statements
sealed trait Term extends Tree  // Terms/expressions
sealed trait Type extends Tree  // Types
sealed trait Pat extends Tree  // Patterns
sealed trait Ctor extends Tree // Constructors
sealed trait Decl extends Tree // Declarations
sealed trait Defn extends Tree  // Definitions
sealed trait Mod extends Tree  // Modifiers
sealed trait Lit extends Tree  // Literals
sealed trait Name extends Tree // Names
```

### Stat (Statement) Types

```scala
// Val definition
Defn.Val(
  mods: Seq[Mod],
  pats: Seq[Pat],
  decltpe: Option[Type],
  rhs: Option[Term]
)

// Var definition
Defn.Var(
  mods: Seq[Mod],
  pats: Seq[Pat],
  decltpe: Option[Type],
  rhs: Option[Term]
)

// Def definition
Defn.Def(
  mods: Seq[Mod],
  name: Term.Name,
  tparams: Seq[Type.Param],
  paramss: Seq[Seq[Term.Param]],
  decltpe: Option[Type],
  body: Term
)

// Object definition
Defn.Object(
  mods: Seq[Mod],
  name: Term.Name,
  templ: Template
)

// Class definition
Defn.Class(
  mods: Seq[Mod],
  name: Type.Name,
  tparams: Seq[Type.Param],
  ctor: Ctor.Primary,
  templ: Template
)

// Trait definition
Defn.Trait(
  mods: Seq[Mod],
  name: Type.Name,
  tparams: Seq[Type.Param],
  ctor: Ctor.Primary,
  templ: Template
)

// Import statement
Import(
  importers: Seq[Importer],
  importers: Seq[Importer]
)
```

### Term (Expression) Types

```scala
// Name (identifier)
Term.Name(value: String)

// Apply (function call)
Term.Apply(
  fun: Term,
  argClause: Term.ArgClause
)

// ApplyInfix (infix operator)
Term.ApplyInfix(
  lhs: Term,
  op: Term.Name,
  targClause: Type.ArgClause,
  argClause: Term.ArgClause
)

// ApplyType (type application)
Term.ApplyType(
  fun: Term,
  targClause: Type.ArgClause
)

// Select (method/field access)
Term.Select(
  qual: Term,
  name: Term.Name
)

// Block
Term.Block(stats: Seq[Stat])

// Function literal
Term.Function(
  params: Seq[Term.Param],
  body: Term
)

// If expression
Term.If(
  cond: Term,
  thenp: Term,
  elsep: Term
)

// Match expression
Term.Match(
  expr: Term,
  cases: Seq[Case]
)

// For loop
Term.For(
  enums: Seq[Enumerator],
  body: Term
)

// While loop
Term.While(
  expr: Term,
  body: Term
)

// Try expression
Term.Try(
  expr: Term,
  catchp: Seq[Case],
  finallyp: Option[Term]
)

// Return statement
Term.Return(expr: Term)

// Throw statement
Term.Throw(expr: Term)

// New expression
Term.New(
  init: Init
)
```

### Type Types

```scala
// Name type
Type.Name(value: String)

// Select type (path-dependent)
Type.Select(qual: Term, name: Type.Name)

// Project type (type projection)
Type.Project(qual: Type, name: Type.Name)

// Function type
Type.Function(
  params: Seq[Type.Param],
  res: Type
)

// Tuple type
Type.Tuple(args: Seq[Type])

// With type (intersection)
Type.With(lhs: Type, rhs: Type)

// And type (intersection)
Type.And(lhs: Type, rhs: Type)

// Or type (union)
Type.Or(lhs: Type, rhs: Type)

// Refine type (structural refinement)
Type.Refine(tpe: Type, stats: Seq[Stat])

// Existential type
Type.Existential(tpe: Type)

// Apply type (type parameter application)
Type.Apply(
  fun: Type,
  args: Seq[Type]
)

// Type parameter
Type.Param(
  mods: Seq[Mod],
  name: Name,
  tparams: Seq[Type.Param],
  default: Option[Type],
  variance: Variance,
  tpe: Option[Type],
  bounds: Seq[Type.Bounds]
)
```

### Pattern (Pat) Types

```scala
// Variable pattern
Pat.Var(name: Term.Name)

// Wildcard pattern
Pat.Wildcard()

// Bind pattern
Pat.Bind(lhs: Pat, rhs: Pat)

// Alternative pattern (|)
Pat.Alternative(lhs: Pat, rhs: Pat)

// Tuple pattern
Pat.Tuple(args: Seq[Pat])

// Extractor pattern
Pat.Extract(ref: Term, targs: Seq[Type], args: Seq[Pat])

// Interpolate pattern
Pat.Interpolate(prefix: Term, parts: Seq[Pat])

// Typed pattern
Pat.Typed(lhs: Pat, rhs: Type)

// Literal pattern
Pat.Lit(value: Lit)

// SeqWildcard pattern
Pat.SeqWildcard()
```

### Modifiers

```scala
// Private
Mod.Private(within: Option[Name])

// Protected
Mod.Protected(within: Option[Name])

// Final
Mod.Final()

// Sealed
Mod.Sealed()

// Override
Mod.Override()

// Case
Mod.Case()

// Implicit
Mod.Implicit()

// Lazy
Mod.Lazy()

// ValParam
Mod.ValParam()

// VarParam
Mod.VarParam()

// Inlined
Mod.Inlined()

// Open (Scala 3)
Mod.Open()

// Transparent (Scala 3)
Mod.Transparent()

// Annotation
Mod.Annot(body: Init)
```

### Literals

```scala
// Integer
Lit.Int(value: BigInt)

// Long
Lit.Long(value: BigInt)

// Float
Lit.Float(value: BigDecimal)

// Double
Lit.Double(value: BigDecimal)

// Null
Lit.Null()

// Boolean
Lit.Boolean(value: Boolean)

// Char
Lit.Char(value: Char)

// String
Lit.String(value: Predef.String)

// Symbol
Lit.Symbol(value: Symbol)

// Unit
Lit.Unit()

### Parsing

```scala
import scala.meta._

// Parse source file
val source = "object Main { val x = 42 }"
val tree = source.parse[Source].get

// Parse statement
val stat = "val x = 42".parse[Stat].get

// Parse expression
val term = "1 + 2".parse[Term].get

// Parse type
val tpe = "String with Int".parse[Type].get

// Parse pattern
val pat = "x @ Some(_)".parse[Pat].get

// Parse with dialect
val sbtSource = "val x = project"
val sbtTree = dialects.Sbt1(sbtSource).parse[Source].get

// Parse from virtual file (for better error messages)
val input = Input.VirtualFile("Example.scala", "val x = 42")
val tree = input.parse[Stat].get

// Parse from actual file
import java.nio.file._
val bytes = Files.readAllBytes(Paths.get("Test.scala"))
val input = Input.VirtualFile("Test.scala", new String(bytes))
val tree = input.parse[Source].get
```

### Quasiquotes

```scala
// Term quasiquotes (q"...")

// Simple term
val tree1 = q"val x = 42"

// Multi-line term
val tree2 = q"""
  object Main {
    def greet(name: String) =
      println(s"Hello, $name")
  }
"""

// Interpolation with $ (single expression)
val name = "World"
val tree3 = q"""println(s"Hello, $name")"""

// Interpolation with $$ (literal dollar)
val tree4 = q"""val price = 100$$USD"""

// Splicing lists with ..$ (flat)
val args = List(q"arg1", q"arg2", q"arg3")
val tree5 = q"function(..$args)"
// Result: function(arg1, arg2, arg3)

// Splicing lists with ...$ (curried)
val argLists = List(List(q"a", q"b"), List(q"c", q"d"))
val tree6 = q"function(...$argLists)"
// Result: function(a, b)(c, d)

// Type quasiquotes (t"...")
val tpe1 = t"List[String]"
val tpe2 = t"Map[String, Int]"

// Pattern quasiquotes (p"...")
val pat1 = p"Some(x)"
val pat2 = p"x @ Some(_)"

// Modifiers quasiquotes (m"...")
val mod1 = m"private"
val mod2 = m"private final"

// Name quasiquotes (name"...")
val name1 = name"MyClass"

// Guard against empty lists in type application
val typeArgs: Seq[Type] = List.empty[Type]
val tree7 =
  if typeArgs.isEmpty then q"function()"
  else q"function[..$typeArgs]()"

// Quasiquote with pattern matching
q"val x = 42" match {
  case q"val $name = $value" =>
    println(s"Name: $name, Value: $value")
}

// Wildcard patterns in quasiquotes
q"def foo(x: Int) = ???".transform {
  case q"def $name($params) = $body" =>
    println(s"Function: $name")
    tree
}
```

### Pattern Matching Trees

```scala
// Match on tree types
val tree = "val x = 42".parse[Stat].get

tree match {
  case Defn.Var(mods, pats, Some(decltpe), Some(rhs)) =>
    println(s"Variable: ${pats.head}, Type: $decltpe")

  case Defn.Def(_, name, _, _, body) =>
    println(s"Function: $name")

  case Defn.Object(_, name, _) =>
    println(s"Object: $name")

  case Lit.Int(n) =>
    println(s"Integer: $n")

  case _ =>
    println("Unknown tree")
}

// Nested pattern matching
q"val x = 1 + 2" match {
  case Defn.Var(
    _,
    Seq(Pat.Var(Term.Name("x"))),
    _,
    Some(Term.ApplyInfix(
      Term.Name("1"),
      Term.Name("+"),
      _,
      Term.ArgClause(Seq(Term.Name("2")))
    ))
  ) =>
    println("Matched!")

  case _ =>
    println("No match")
}
```

### Versioned Pattern Matching

```scala
// Scalameta trees evolve over time with versioned matchers

// Initial matcher (original fields)
q"function(arg1, arg2)".parse[Term].get match {
  case Term.Apply.Initial(fun, Term.ArgClause.Initial(List(arg1, arg2), None)) =>
    println(s"Fun: $fun, Args: $arg1, $arg2")
}

// After version matcher (fields added in specific version)
q"function(using arg1, arg2)".parse[Term].get match {
  case Term.Apply.After_4_6_0(
    fun,
    Term.ArgClause.Initial(List(arg1, arg2), Some(using))
  ) =>
    println(s"Fun: $fun, Args with using: $arg1, $arg2")
}

// Check which version to use
// .Initial - original tree structure
// .After_X_Y_Z - structure after version X.Y.Z
```

### Tree Traversal

```scala
// Simple traverse - visit every node
q"val x = 1; val y = 2".traverse {
  case Lit.Int(n) => println(s"Found integer: $n")
  case Term.Name(name) => println(s"Found name: $name")
}

// Collect values from all nodes
val allNames = q"val x = 1; val y = x + y".collect {
  case Term.Name(name) => name
}
// List("x", "y", "x", "y")

// Custom traverser
class MyTraverser extends Traverser:
  override def apply(tree: Tree): Unit = tree match
    case Term.Name("x") =>
      println("Found x - stopping recursion here")
      // Don't call super.apply to stop recursion

    case Term.Name(name) =>
      println(s"Found name: $name")
      super.apply(tree)

    case _ =>
      super.apply(tree)

val traverser = new MyTraverser
traverser(q"val x = 1; val y = x + 2")
// Found name: x
// Found x - stopping recursion here
// Found integer: 1
// Found name: y
```

### Tree Transformation

```scala
// Simple transform - modify matching nodes
val transformed = q"1 + 2".transform {
  case Lit.Int(n) => Lit.Int(n * 10)
}
// Result: 10 + 20

// Transform all function calls
val result = q"function(a, b, c)".transform {
  case Term.Apply(Term.Name("function"), args) =>
    q"transformed_function(..${args.values})"
}
// Result: transformed_function(a, b, c)

// Custom transformer
class DoubleNumbers extends Transformer:
  override def apply(tree: Tree): Tree = tree match
    case Lit.Int(n) => Lit.Int(n * 2)
    case Lit.Double(n) => Lit.Double(n * 2.0)
    case _ => super.apply(tree)

val transformer = new DoubleNumbers
val doubled = transformer(q"val x = 1; val y = 2.5")
// Result: val x = 2; val y = 5.0

// Transformer with controlled recursion
class NoRecurseDouble extends Transformer:
  override def apply(tree: Tree): Tree = tree match
    case Term.Apply(fun, args) =>
      // Don't recurse into transformed tree to avoid infinite loops
      Term.Apply(super.apply(fun), args)

    case _ =>
      super.apply(tree)
```

### Tree Equality

```scala
// Reference equality (default)
val tree1 = q"1 + 2"
val tree2 = q"1 + 2"

tree1 == tree2  // false (different references)
tree1 eq tree2  // false

// Structural equality via pattern matching
q"1 + 2" match {
  case q"1 + 2" => println("Structurally equal")
  case _ => println("Not equal")
}

// Structural equality via .structure
tree1.structure == tree2.structure  // true

// Structural equality via isEqual helper
import scala.meta.contrib._
tree1.isEqual(tree2)  // true
```

### Semantic Information

```scala
// Scalameta also provides semantic analysis via SemanticDB
// Not covered in this reference - see SemanticDB specification
```

### Pretty Printing

```scala
// Convert tree back to source code
val tree = q"val x = 42"
val code = tree.syntax  // "val x = 42"

// Get structure representation
val struct = tree.structure
// "Defn.Val(Nil, Pat.Var(Term.Name(\"x\")), None, Some(Lit.Int(42)))"

// Format with specific dialect
val formatted = tree.toString()  // Uses default dialect
val formattedSbt = dialects.Sbt1(tree).toString()
```

### Advanced Patterns

```scala
// Building complex trees with quasiquotes
def createClass(name: String, fields: Seq[(String, String)]): Defn.Class =
  val params = fields.map { case (fname, ftype) =>
    param"""$fname: $ftype"""
  }
  q"""
    class $name(..$params) {
      def toString: String = ???
    }
  """

val userClass = createClass("User", Seq("name" -> "String", "age" -> "Int"))

// Extracting all method names from a class
def extractMethods(tree: Defn.Class): Seq[String] =
  tree.templ.body.collect {
    case Defn.Def(_, name, _, _, _) => name.value
  }

// Renaming all occurrences of a variable
def rename(tree: Tree, oldName: String, newName: String): Tree =
  tree.transform {
    case Term.Name(`oldName`) => Term.Name(newName)
    case Pat.Var(Term.Name(`oldName`)) => Pat.Var(Term.Name(newName))
  }

// Adding logging to all methods
def addLogging(tree: Defn.Def): Defn.Def =
  tree match
    case Defn.Def(mods, name, tparams, paramss, Some(decltpe), body) =>
      q"""
        $mods def $name[..$tparams](...$paramss): $decltpe =
          println(s"Entering $name")
          try $body
          finally println(s"Exiting $name")
      """

    case _ => tree
```

### Scalameta Gotchas

1. **Tree equality**: Use `.structure` or `isEqual`, not `==`
2. **Empty type parameter lists**: Guard quasiquotes with conditionals
3. **Versioned matchers**: Use `.Initial` or `.After_X_Y_Z` correctly
4. **Transform recursion**: Be careful not to create infinite loops
5. **Comment preservation**: Transformations lose comments (use Scalafix instead)

---

## Simulacrum Reference

Simulacrum provides first-class syntax support for type classes in Scala 2.x.

### Installation

```scala
// build.sbt
libraryDependencies += "org.typelevel" %% "simulacrum" % "1.0.1"

// For Scala 2.11-2.12
addCompilerPlugin("org.scalamacros" % "paradise" % "2.1.0" cross CrossVersion.full)

// For Scala 2.13+
scalacOptions += "-Ymacro-annotations"
```

### @typeclass Annotation

```scala
import simulacrum._

@typeclass trait Semigroup[A] {
  @op("|+|") def append(x: A, y: A): A
}

// Generates the following:

trait Semigroup[A] {
  def append(x: A, y: A): A
}

object Semigroup {
  def apply[A](implicit instance: Semigroup[A]): Semigroup[A] = instance

  trait Ops[A] {
    def typeClassInstance: Semigroup[A]
    def self: A
    def |+|(y: A): A = typeClassInstance.append(self, y)
  }

  trait ToSemigroupOps {
    implicit def toSemigroupOps[A](target: A)(implicit tc: Semigroup[A]): Ops[A] =
      new Ops[A] {
        val self = target
        val typeClassInstance = tc
      }
  }

  trait AllOps[A] extends Ops[A] {
    def typeClassInstance: Semigroup[A]
  }

  object ops {
    implicit def toAllSemigroupOps[A](target: A)(implicit tc: Semigroup[A]): AllOps[A] =
      new AllOps[A] {
        val self = target
        val typeClassInstance = tc
      }
  }
}
```

### @op Annotation

```scala
@typeclass trait Functor[F[_]] {
  @op("map") def map[A, B](fa: F[A])(f: A => B): F[B]
}

// Methods annotated with @op become extension methods in Ops trait
// The string in @op specifies the symbol name
// @op("map") generates def map[A, B](fa: F[A])(f: A => B): F[B]
// @op(">>>") generates def >>>(fa: F[A]): F[B] (operator notation)
```

### Typeclass Inheritance

```scala
@typeclass trait Semigroup[A] {
  @op("|+|") def append(x: A, y: A): A
}

@typeclass trait Monoid[A] extends Semigroup[A] {
  def id: A
}

// Monoid.AllOps extends Semigroup.AllOps and Monoid.Ops
// Methods from Semigroup and Monoid are both available
implicit val monoidInt = new Monoid[Int] {
  def id = 0
  def append(x: Int, y: Int) = x + y
}

import Monoid.ops._
1 |+| 2  // Works (from Semigroup)
val empty = Monoid[Int].id  // Works (from Monoid)
```

### Higher-Kinded Typeclasses

```scala
@typeclass trait Functor[F[_]] {
  @op("map") def map[A, B](fa: F[A])(f: A => B): F[B]
}

implicit val listFunctor = new Functor[List] {
  def map[A, B](fa: List[A])(f: A => B) = fa.map(f)
}

implicit val optionFunctor = new Functor[Option] {
  def map[A, B](fa: Option[A])(f: A => B) = fa.map(f)
}

import Functor.ops._
List(1, 2, 3).map(_ * 2)  // List(2, 4, 6)
Some(5).map(_ * 2)  // Some(10)
```

### Import Strategies

```scala
// Import all operations
import Monoid.ops._
val x = 1 |+| 2
val empty = Monoid[Int].id

// Import selectively - create object with specific traits
object OnlyMap extends ToFunctorOps with ToApplicativeOps {}
import OnlyMap._
val mapped = list.map(f)  // map works, pure and flatMap don't

// Import all ops
import Monoid.AllOps._
val x = 1 |+| 2
val empty = id  // Can call id directly without Monoid[Int].id
```

### Typeclass Syntax Variations

```scala
// Single parameter typeclass
@typeclass trait Show[A] {
  def show(a: A): String
}

// Multi-parameter typeclass (not recommended)
// Simulacrum only supports single type parameter properly
@typeclass trait Compare[A] {
  def compare(x: A, y: A): Int
}

// Type constructor kind
@typeclass trait Functor[F[_]] {
  def map[A, B](fa: F[A])(f: A => B): F[B]
}

// Binary type constructor (not supported)
// Currently only unary type constructors are supported
```

### Method Variations

```scala
@typeclass trait Monad[F[_]] {
  @op("flatMap") def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B]
  @op("map") def map[A, B](fa: F[A])(f: A => B): F[B]
}

// flatMap and map become extension methods
// Can also use @op for infix operators
@typeclass trait Monoid[A] {
  @op("|+|") def combine(x: A, y: A): A
}

import Monoid.ops._
1 |+| 2 |+| 3  // Works as infix
```

### Simulacrum Gotchas

1. **Scala 3 only**: Use Scala 3's built-in support instead
2. **Unary type constructors**: Only F[_] is supported, not F[_, _]
3. **Override keyword**: Must use `override` when implementing supertype methods
4. **Method selection**: Not all methods become extension methods (only @op methods)
5. **Maintenance**: Only maintained for bug fixes, use simulacrum-scalafix for Scala 3

---

## Scalatex Reference

Scalatex provides programmable, typesafe document generation for Scala. **Note: Deprecated, use maintained fork at https://github.com/openmole/scalatex**

### Installation

```scala
// project/build.sbt
addSbtPlugin("com.lihaoyi" % "scalatex-sbt-plugin" % "0.3.11")

// build.sbt
scalatex.SbtPlugin.projectSettings
scalaVersion := "2.11.4"  // Only Scala 2.11.x supported
```

### Basic Syntax

```scala
// src/main/scalatex/Document.scalatex

// Indentation-based blocks
@div
  @h1
    Title
  @p
    Paragraph content

// Curly braces for inline content
@h1{Title}
@p{Content}

// Parentheses for expressions
@h1("Title")

// Interpolation
@p
  Result is @(1 + 2)
```

### Splicing and Interpolation

```scala
// Single value interpolation
val name = "World"
@p
  Hello, @name

// Expression interpolation
@p
  Sum is @(1 + 2 + 3)

// Block interpolation (multiple statements)
@p
  Result is @{
    val x = 10
    val y = 20
    x + y
  }

// Escaping
@p
  Use @("HTML") for code
```

### Loops

```scala
// For loop
@ul
  @for(i <- 0 until 5)
    @li
      Item @i

// Nested loops
@table
  @for(row <- 0 until 3)
    @tr
      @for(col <- 0 until 3)
        @td
          @(row * 3 + col)

// Filtered loop
@ul
  @for(i <- (1 to 10).filter(_ % 2 == 0))
    @li
      Even: @i
```

### Conditionals

```scala
// If-else
@div
  @if(condition)
    True branch
  @else
    False branch

// Nested conditionals
@div
  @if(x > 0)
    @if(x < 100)
      Valid range
    @else
      Too large
  @else
    Invalid
```

### Functions and Definitions

```scala
// Internal function definition
@def wrap(content: Frag) = {
  div(cls := "wrapper")(
    content
  )
}

@wrap{
  @p
    Wrapped content
}

// Function with multiple parameters
@def link(url: String, text: Frag) = {
  a(text, href := url)
}

@link("https://example.com", @b{Click me})

// Object definition
@object Constants {
  val title = "My Document"
  val version = "1.0"
}

@p
  @Constants.title v@Constants.version
```

### Imports

```scala
// Import standard library
@import scala.math._

@p
  Pi is @pi

// Import from your code
@import com.example.Utils._

@p
  Result is @calculate(1, 2)
```

### Custom Tags

```scala
// Define a tag with caption
@def imageWithCaption(src: String, caption: String) = {
  div(cls := "image-container")(
    img(src := src),
    p(cls := "caption")(
      caption
    )
  )
}

@imageWithCaption("photo.jpg", "A beautiful sunset")
```

### Sections

```scala
@import scalatex.site.Section

@object sect extends Section()

@sect{Main Section}
  @p
    Content here

  @sect{Subsection A}
    @p
      Subsection A content

  @sect{Subsection B}
    @p
      Subsection B content
```

### Table of Contents

```scala
@import scalatex.site.Section
@import scalatex.site.Tree

@object sect extends Section()

@sect{Document}
  @p
    Main content

  @sect{Section 1}
    @p
      Content 1

  @sect{Section 2}
    @p
      Content 2

@b{Table of Contents}
@{
  def renderTOC(tree: Tree[String]): Frag = {
    ul(
      tree.children.map { child =>
        li(a(child.value, href := s"#${sect.munge(child.value)}"))
      }
    )
  }
  renderTOC(sect.structure)
}
```

### Code Highlighting

```scala
@import Main._

// Inline code
@hl.scala"""val x = 42"""

// Multi-line code
@hl.scala"""
  def greet(name: String): String =
    s"Hello, $name"
"""

// Reference file
@hl.ref(wd / "src" / "Example.scala")

// Reference specific lines
@hl.ref(
  wd / "source.scala",
  start = "def test",
  end = "}"
)

// Specific language
@hl.scala"""
  val x = 42
"""
@hl.js"""
  function() { return 42; }
"""
```

### Links and Validation

```scala
// Internal reference
@sect{Target Section}
  @p
    Content

// Link to section
@p
  Go to @sect.ref{Target Section}

// External link
@lnk("https://example.com")
@lnk("Example Site", "https://example.com")

// Validate links (run: sbt "readme/run --validate")
```

### Scalatex Site Generation

```scala
val site = new scalatex.site.Site {
  def content = Map(
    "index.html" -> (defaultHeader, Main()),
    "about.html" -> (defaultHeader, About())
  )
}

site.renderTo(wd / "site" / "output")
```

### Scalatex Gotchas

1. **Scala 2 only**: Only supports Scala 2.11.x
2. **Deprecated**: Use maintained fork at https://github.com/openmole/scalatex
3. **HTML generation**: Based on Scalatags, generates HTML
4. **Type safety**: Full Scala type safety in templates

---

## Kind-Projector Reference

Kind-projector provides syntax for type lambdas in Scala 2.x. **Note: Scala 3 has built-in type lambda support.**

### Installation

```scala
// build.sbt
addCompilerPlugin("org.typelevel" % "kind-projector" % "0.13.2" cross CrossVersion.full)
```

### Inline Syntax

```scala
// Basic type lambda
Tuple2[*, Double]
// Expands to: ({type L[A] = Tuple2[A, Double]})#L

// Variance annotations
Either[Int, +*]          // Covariant
Function2[-*, Long, +*]   // Contravariant and covariant

// Higher-kinded
List[*]                  // λ[A] => List[A]
Option[*]                // λ[A] => Option[A]
```

### Underscore Syntax (Scala 2.13.6+)

```scala
// Enable underscore syntax
scalacOptions += "-P:kind-projector:underscore-placeholders"

// Same as * syntax
Tuple2[_, Double]        // λ[A] => Tuple2[A, Double]
Either[Int, +_]          // λ[+A] => Either[Int, A]
Function2[-_, Long, +_]   // λ[-A, +B] => Function2[A, Long, B]
```

### Function Syntax

```scala
// Lambda syntax
Lambda[A => (A, A)]
// Expands to: ({type L[A] = (A, A)})#L

// Multiple parameters
Lambda[(A, B) => Either[B, A]]
// λ[(A, B)] => Either[B, A]

// Variance with backticks
Lambda[`-A` => Function1[A, Double]]
Lambda[`+A` => Either[Int, A]]

// Higher-kinded parameters
Lambda[A[_] => List[A[Int]]
Lambda[(F[_], A) => F[A]]
```

### Advanced Type Lambdas

```scala
// Repeated parameters
Lambda[A => (A, A, A)]

// Complex return types
Lambda[(A, B) => Map[A, List[B]]]

// Nested type constructors
Lambda[F[_[+_]] => Q[F, List]]
```

### Polymorphic Lambda Values

```scala
// Value-level polymorphic lambda
val f = λ[List ~> Option](_.headOption)

val g = λ[Either[Unit, *] ~> Option](
  _.fold(_ => None, a => Some(a))
)

// Equivalent to:
val f = new (List ~> Option) {
  def apply[A](fa: List[A]): Option[A] = fa.headOption
}
```

### Type Lambda Gotchas

1. **Inline syntax limitations**: Can't express repeated params or reverse order
2. **Higher-kinded nesting**: `Future[List[*]]` doesn't work, use Lambda syntax
3. **Reserved identifiers**: Avoid `Lambda`, `λ`, `*`, `+*`, `-*`, etc.
4. **Scala 3**: Use built-in syntax instead

---

## Macro Annotation Patterns

Macro annotations allow compile-time code transformation in Scala 2.x.

### Basic Macro Annotation

```scala
import scala.annotation.StaticAnnotation
import scala.reflect.macros.blackbox.Context

class debug extends StaticAnnotation {
  def macroTransform(annottees: Any*): Any = macro debugImpl
}

object debug {
  def debugImpl(c: Context)(annottees: c.Expr[Any]*): c.Expr[Any] = {
    import c.universe._
    import c.universe.syntax._

    annottees.map { annottee =>
      val tree = annottee.tree
      val withDebug = q"""
        println(s"Debug: ${tree.toString}")
        $tree
      """
      c.Expr(withDebug)
    }
  }
}
```

### Macro Annotation on Method

```scala
@debug
def calculate(x: Int): Int = x * 2

// Expands to:
def calculate(x: Int): Int = {
  println(s"Debug: def calculate(x: Int): Int = x * 2")
  x * 2
}
```

### Macro Annotation on Class

```scala
@debug
class Calculator:
  def add(x: Int, y: Int): Int = x + y

// Expands to:
class Calculator:
  def add(x: Int, y: Int): Int = {
    println(s"Debug: class Calculator...")
    x + y
  }
```

### Parameterized Macro

```scala
class log(prefix: String) extends StaticAnnotation {
  def macroTransform(annottees: Any*): Any = macro logImpl
}

object log {
  def logImpl(c: Context)(prefix: c.Expr[String])(annottees: c.Expr[Any]*): c.Expr[Any] = {
    import c.universe._

    annottees.map { annottee =>
      annottee match {
        case Expr(q"""
          def $name(..$params): $tpe = $body
        """) =>
          q"""
            def $name(..$params): $tpe =
              println($prefix + ${name.toString})
              $body
          """

        case _ => annottee
      }
    }
  }
}
```

---

## Cross-Compilation Strategies

### Scala 2 vs Scala 3

| Feature | Scala 2 | Scala 3 |
|---------|-----------|-----------|
| Type lambdas | kind-projector | Built-in: `[A] => B` |
| Typeclass syntax | simulacrum | Built-in `extension` methods |
| Generic derivation | shapeless/magnolia (Scala 2) | magnolia/derives |
| Metaprogramming | Macro annotations | Inline/quote/splice |
| Quasiquotes | `q"..."`, `t"..."` | `q"..."`, `t"..."` (enhanced) |

### Shared Code Patterns

```scala
// Typeclass definition (both versions)

// Scala 2 with simulacrum
@typeclass trait Functor[F[_]] {
  def map[A, B](fa: F[A])(f: A => B): F[B]
}

// Scala 3
trait Functor[F[_]]:
  def [A, B](fa: F[A])(f: A => B): F[B]
```

### Migration Guide

**From Scala 2 to Scala 3:**

1. Remove simulacrum and kind-projector dependencies
2. Use built-in type lambda syntax
3. Replace `@typeclass` with standard trait + extension methods
4. Use Magnolia for Scala 3 instead of Scala 2 version
5. Replace macro annotations with inline/quote/splice
