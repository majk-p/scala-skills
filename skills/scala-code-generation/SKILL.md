---
name: scala-code-generation
description: Use this skill when working with code generation, metaprogramming, or type class derivation in Scala. This includes using magnolia for generic derivation, scalameta for metaprogramming, simulacrum for type class syntax, scalatex for document generation, kind-projector for type lambdas, and various code generation tools. Trigger when the user mentions metaprogramming, macros, code generation, generic derivation, AST manipulation, type lambdas, or automatic boilerplate generation.
---

# Code Generation & Metaprogramming in Scala

Code generation and metaprogramming in Scala enable automatic derivation of typeclass instances, generation of boilerplate code, AST manipulation, and compile-time code transformation.

**Key Libraries:**
- **magnolia** — Generic typeclass derivation for Scala 3
- **scalameta** — AST parsing, analysis, and transformation
- **simulacrum** — Typeclass syntax support (Scala 2.x)
- **scalatex** — Typesafe document generation
- **kind-projector** — Type lambda syntax (Scala 2.x)

## Quick Start

### Magnolia — Generic Derivation

```scala
import magnolia1.*

trait Show[T] { extension (x: T) def show: String }

object Show extends AutoDerivation[Show]:
  def join[T](ctx: CaseClass[Show, T]): Show[T] = value =>
    ctx.params.map(p => p.typeclass.show(p.deref(value)))
      .mkString(s"${ctx.typeInfo.short}(", ", ", ")")

  def split[T](ctx: SealedTrait[Show, T]): Show[T] = value =>
    ctx.choose(value)(sub => sub.typeclass.show(sub.cast(value)))

  given Show[Int] = _.toString

case class Person(name: String, age: Int)
given showPerson: Show[Person] = Show.derived[Person]
Person("Alice", 30).show  // "Person(Alice, 30)"
```

### Scalameta — AST Manipulation

```scala
import scala.meta._

val tree = "val x = 42".parse[Stat].get
tree.transform { case Lit.Int(n) => Lit.Int(n * 2) }
println(tree.syntax)  // "val x = 84"
```

### Simulacrum — Typeclass Syntax (Scala 2)

```scala
import simulacrum._

@typeclass trait Semigroup[A] { @op("|+|") def append(x: A, y: A): A }
implicit val semigroupInt = new Semigroup[Int] { def append(x: Int, y: Int) = x + y }

import Semigroup.ops._
1 |+| 2  // 3
```

### Kind-Projector — Type Lambdas (Scala 2)

```scala
Tuple2[*, Double]              // λ[A] => Tuple2[A, Double]
Either[Int, +*]             // λ[+A] => Either[Int, A]
Lambda[A => (A, A)]         // λ[A] => (A, A)
```

## Magnolia Core Patterns

### Auto-Derivation vs Semi-Auto

```scala
// Auto: object Show extends AutoDerivation[Show]
given Show[T] = Show.autoDerived[T]  // Searches automatically

// Semi-auto: object Show extends Derivation[Show]
given Show[T] = Show.derived[T]  // Explicitly requested
```

### Recursive Types

```scala
case class Tree[A](value: A, left: Option[Tree[A]], right: Option[Tree[A]])
given showTree[A: Show]: Show[Tree[A]] = Show.derived[Tree[A]]  // Must assign explicitly
```

## Scalameta Core Patterns

### Parsing

```scala
val sourceTree = "object Main { val x = 42 }".parse[Source].get
val exprTree = "1 + 2".parse[Term].get
val typeTree = "String with Int".parse[Type].get
val fileTree = Input.VirtualFile("Test.scala", "val x = 1").parse[Source].get
```

### Quasiquotes

```scala
q"val x = 42"                              // Single expression
q"""object Main { val x = $value }"""     // Multi-line with splice
q"function(..${List(q"a", q"b")})"      // Splice list
t"List[String]"                              // Type quasiquote
```

### Transformation

```scala
q"1 + 2".transform { case Lit.Int(n) => Lit.Int(n * 10) }  // 10 + 20

class MyTransformer extends Transformer {
  override def apply(tree: Tree): Tree = tree match {
    case Term.Name("x") => Term.Name("y")
    case _ => super.apply(tree)
  }
}
```

### Traversal

```scala
q"val x = 1; val y = 2".traverse {
  case Lit.Int(n) => println(s"Integer: $n")
}
```

## Simulacrum Core Patterns

### Typeclass Definition

```scala
@typeclass trait Semigroup[A] { @op("|+|") def append(x: A, y: A): A }
// Generates: trait Ops[A], ToSemigroupOps, AllOps[A], ops object
```

### Inheritance

```scala
@typeclass trait Monoid[A] extends Semigroup[A] { def id: A }
// Monoid.AllOps includes methods from Semigroup.Ops plus Monoid methods
```

### Import Strategies

```scala
import Monoid.ops._        // All operations
val x = 1 |+| 2

object OnlyMap extends ToFunctorOps {}  // Selective
import OnlyMap._; list.map(f)  // map works, flatMap doesn't
```

## Scalatex Core Patterns

```scala
@div                          // Indentation-based
  @h1 Title               // Curly braces
@h1("Title")                // Parentheses
@p Value is @(1 + 2)          // Interpolation

// Loops and conditionals
@ul @for(i <- 0 until 5) @li Item @i
@div @if(cond) True @else False

// Custom tags
@def code(lang: String, content: Frag) = div(cls := s"code-$lang")(pre(content))
```

## Cross-Compilation

| Feature | Scala 2 | Scala 3 |
|---------|-----------|-----------|
| Generic derivation | Simulacrum + shapeless | Magnolia (built-in) |
| Type lambdas | kind-projector | Built-in: `[A] => B` |
| Metaprogramming | Macro annotations | Inline/quote/splice |

## Performance & Pitfalls

**Performance:**
- Magnolia: Fast compilation, minimal runtime overhead
- Scalameta: Lightweight trees, transformations can be expensive
- Quasiquotes: Compile-time expansion, no runtime cost

**Common Pitfalls:**
1. Recursive types: Must assign to explicit `given`/`implicit` variable
2. Tree equality: Use `.structure` or pattern matching, not `==`
3. Empty type parameter lists: Guard quasiquotes with conditionals
4. Scalatex: Scala 2 only, deprecated (use maintained fork)

## Dependencies

```scala
libraryDependencies ++= Seq(
  "com.softwaremill.magnolia1_3" %% "magnolia" % "1.3.+",
  "org.scalameta" %% "scalameta" % "4.15.+",
  "org.typelevel" %% "simulacrum" % "1.0.+",
  compilerPlugin("org.typelevel" % "kind-projector" % "0.13.+" cross CrossVersion.full)
)

scalacOptions += "-Ymacro-annotations"  // Scala 2.13+
```

## Related Skills

- **scala-lang** — for Scala 3 inline/quote/splice macros and language-level metaprogramming
- **scala-type-classes** — for type class patterns that drive derivation use cases

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/REFERENCE.md** — Complete Magnolia reference with advanced derivation patterns, complete Scalameta reference with all tree types and operations, complete Simulacrum reference with @typeclass annotation details, complete Scalatex reference with site generation patterns, complete Kind-projector reference with all syntax variants, macro annotation examples, cross-compilation strategies
