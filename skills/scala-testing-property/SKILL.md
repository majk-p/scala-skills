---
name: scala-testing-property
description: Use this skill when writing property-based tests or checking type class laws in Scala using ScalaCheck and discipline. Covers property definition, generators, shrinking, conditional properties, law checking (Monoid, Functor, Applicative, Monad), MUnit integration, specs2 integration, stateful testing, and test configuration. Trigger when the user mentions property testing, ScalaCheck, generators, Arbitrary, laws, discipline, forAll, shrinking, or needs to verify algebraic properties of type class instances.
---

# Property-Based Testing in Scala

Property-based testing generates random inputs to verify properties that should hold for all valid values. Scala provides a rich ecosystem: ScalaCheck for property testing, Discipline for type class law verification, and integration with both MUnit and specs2.

## Quick Start

### ScalaCheck Standalone

```scala
import org.scalacheck.Properties
import org.scalacheck.Prop.forAll

object StringSpec extends Properties("String") {
  property("startsWith") = forAll { (a: String, b: String) =>
    (a + b).startsWith(a)
  }

  property("substring") = forAll { (a: String, b: String, c: String) =>
    (a + b + c).substring(a.length, a.length + b.length) == b
  }
}
```

### MUnit + ScalaCheck

```scala
import munit.ScalaCheckSuite

class MyTests extends ScalaCheckSuite {
  property("list reverse is idempotent") {
    forAll { (l: List[Int]) =>
      l.reverse.reverse == l
    }
  }
}
```

### specs2 + ScalaCheck

```scala
import org.specs2.mutable.Specification
import org.specs2.scalacheck.Prop.forAll

class PropertySpec extends Specification {
  "Properties" should {
    "list reverse is idempotent" in {
      forAll { (l: List[Int]) =>
        l.reverse.reverse == l
      }
    }
  }
}
```

### Discipline Law Checking

```scala
import munit.DisciplineSuite
import cats.kernel.laws.discipline.MonoidTests

class MonoidSpec extends DisciplineSuite {
  checkAll("List[Int].monoid", MonoidTests[List[Int]].monoid)
}
```

## Core Concepts

### Properties

Properties describe behavior that should hold for all valid inputs:

```scala
import org.scalacheck.Prop.forAll

// Simple property
val prop1 = forAll { (n: Int) => n + 0 == n }

// Multiple parameters
val prop2 = forAll { (a: Int, b: Int) => (a + b) == (b + a) }

// With custom generator
import org.scalacheck.Gen
val smallInt = Gen.choose(0, 10)
val prop3 = forAll(smallInt) { n => n >= 0 && n <= 10 }
```

### Generators (Gen)

```scala
import org.scalacheck.Gen._

// Built-in generators
val genInt: Gen[Int]     = choose(0, 100)
val genChar: Gen[Char]   = alphaChar
val genString: Gen[String] = alphaStr

// Choose from options
val vowel = oneOf('A', 'E', 'I', 'O', 'U')

// Weighted frequency
val weighted = frequency((1, 'A'), (2, 'E'), (1, 'I'))

// Compose with for-comprehension
val genTuple = for {
  x <- choose(0, 10)
  y <- choose(x, 20)  // y >= x
} yield (x, y)

// Containers
val genList: Gen[List[Int]]       = listOf(choose(0, 10))
val genNonEmpty: Gen[List[Int]]   = nonEmptyListOf(choose(0, 10))
val genListN: Gen[List[Int]]      = listOfN(5, choose(0, 10))
```

### Custom Generators

```scala
import org.scalacheck.{Arbitrary, Gen}

// Case class generator
case class Point(x: Int, y: Int)

val genPoint: Gen[Point] = for {
  x <- Gen.choose(-100, 100)
  y <- Gen.choose(-100, 100)
} yield Point(x, y)

// Arbitrary instance — enables forAll { (p: Point) => ... }
implicit val arbPoint: Arbitrary[Point] = Arbitrary(genPoint)

// Sealed trait
sealed trait Animal
case class Dog(name: String) extends Animal
case class Cat(name: String) extends Animal

val genAnimal: Gen[Animal] = Gen.oneOf(
  Gen.alphaStr.map(Dog),
  Gen.alphaStr.map(Cat)
)

// Recursive ADT
sealed abstract class Tree[+A]
case class Leaf[A](value: A) extends Tree[A]
case class Branch[A](left: Tree[A], right: Tree[A]) extends Tree[A]

def genTree[A](implicit arbA: Arbitrary[A]): Gen[Tree[A]] = Gen.lzy {
  Gen.sized { size =>
    if (size <= 1) arbA.arbitrary.map(Leaf(_))
    else Gen.frequency(
      (1, arbA.arbitrary.map(Leaf(_))),
      (3, for {
        left  <- Gen.resize(size / 2, genTree[A])
        right <- Gen.resize(size / 2, genTree[A])
      } yield Branch(left, right))
    )
  }
}
```

### Conditional Properties

Use implications for preconditions:

```scala
import org.scalacheck.Prop.{forAll, BooleanOperators}

val propDiv = forAll { (n: Int, d: Int) =>
  (d != 0) ==> (n % d == (n - d) % d)
}
```

### Combining Properties

```scala
val p1 = forAll { (n: Int) => n + 0 == n }
val p2 = forAll { (n: Int) => n * 1 == n }

val combinedAnd = p1 && p2   // both must pass
val combinedOr  = p1 || p2   // either passes
```

### Labeling and Classifying

```scala
val propLabeled = forAll { (n: Int, m: Int) =>
  val result = multiply(n, m)
  (result >= n)    :| "result >= first" &&
  (result >= m)    :| "result >= second" &&
  (result < n + m) :| "result < sum"
}

// Collect statistics on generated data
val propClassify = forAll { (l: List[Int]) =>
  classify(l.isEmpty, "empty", "non-empty") {
    classify(l.length > 5, "large", "small") {
      l.reverse.reverse == l
    }
  }
}
```

## Shrinking

When a property fails, ScalaCheck shrinks the input to find the minimal failing case:

```scala
import org.scalacheck.Shrink

// Custom shrinker
case class UserId(id: Int)
implicit val shrinkUserId: Shrink[UserId] = Shrink { userId =>
  Shrink.shrinkInt(userId.id).map(UserId(_))
}

// Disable shrinking for expensive types
implicit val noShrink: Shrink[ExpensiveType] = Shrink.shrinkAny

// Disable per-property
val prop = forAllNoShrink { (l: List[Int]) => l == l.distinct }
```

## Type Class Laws with Discipline

### Checking Built-in Laws

```scala
import cats.kernel.laws.discipline.MonoidTests
import cats.kernel.laws.discipline.SemigroupTests
import cats.laws.discipline.FunctorTests
import cats.laws.discipline.ApplicativeTests
import cats.laws.discipline.MonadTests
import munit.DisciplineSuite

class LawSpec extends DisciplineSuite {
  // Monoid: associativity + identity
  checkAll("List[Int].monoid", MonoidTests[List[Int]].monoid)

  // Functor: identity + composition
  checkAll("Option.functor", FunctorTests[Option].functor[Int, Int, String])

  // Applicative: identity + composition + interchange + homomorphism
  checkAll("Option.applicative", ApplicativeTests[Option].applicative[Int, Int, String])

  // Monad: associativity + identity + ap + pure
  checkAll("Option.monad", MonadTests[Option].monad[Int, Int, String])
}
```

### Manual Law Verification

```scala
class ManualLawSpec extends Specification {
  "Monoid laws" should {
    "associativity" in forAll { (a: Int, b: Int, c: Int) =>
      (a |+| b) |+| c == a |+| (b |+| c)
    }
    "left identity" in forAll { (a: Int) =>
      Monoid[Int].empty |+| a == a
    }
    "right identity" in forAll { (a: Int) =>
      a |+| Monoid[Int].empty == a
    }
  }
}
```

## Common Patterns

### Testing Collections

```scala
property("reverse twice returns original") {
  forAll { (l: List[Int]) => l.reverse.reverse == l }
}

property("append is associative") {
  forAll { (a: List[Int], b: List[Int], c: List[Int]) =>
    a ++ (b ++ c) == (a ++ b) ++ c
  }
}

property("concat preserves length") {
  forAll { (l1: List[Int], l2: List[Int]) =>
    (l1 ++ l2).length == l1.length + l2.length
  }
}
```

### Testing Pure Functions

```scala
property("add is commutative") {
  forAll { (x: Int, y: Int) => add(x, y) == add(y, x) }
}

property("add is associative") {
  forAll { (x: Int, y: Int, z: Int) =>
    add(add(x, y), z) == add(x, add(y, z))
  }
}
```

## Test Configuration

```scala
import org.scalacheck.Test.Parameters

val params = Parameters.default
  .withMinSuccessfulTests(100)
  .withMaxDiscardRatio(5)
  .withMaxSize(100)
  .withWorkers(4)
```

## Common Pitfalls

1. **Over-filtering with implications**: Don't use `(n == 42) ==>` — use `Gen.const(42)` instead
2. **Missing Arbitrary instances**: Define `Arbitrary[YourType]` before using `forAll { (x: YourType) => ... }`
3. **Using filter instead of custom generators**: `arbitrary[Int].filter(_ % 2 == 0)` discards half — use `Gen.choose(0, 100).map(_ * 2)`
4. **Ignoring shrinking**: Always define `Shrink` for custom types to get minimal failing cases
5. **Missing labels**: Label sub-properties with `:| "description"` for clearer failure messages

## Dependencies

```scala
// ScalaCheck — check for latest version
libraryDependencies += "org.scalacheck" %% "scalacheck" % "1.19.+" % Test

// MUnit integration
libraryDependencies += "org.scalameta" %% "munit" % "1.2.+" % Test
libraryDependencies += "org.typelevel" %%% "discipline-munit" % "2.0.+" % Test

// specs2 integration
libraryDependencies += "org.specs2" %% "specs2-scalacheck" % "5.7.+" % Test

// Discipline core (for law checking)
libraryDependencies += "org.typelevel" %% "discipline-core" % "1.7.+" % Test
```

## Related Skills

- **scala-testing-specs2** — BDD-style testing with specs2 matchers and DSL
- **scala-type-classes** — type class patterns that property tests verify
- **scala-build-tools** — sbt test configuration

## References

Load these when you need exhaustive API details or patterns not shown above:

- **references/scalacheck-reference.md** — Complete ScalaCheck API: properties, generators, combinators, sized generators, conditional generators, shrinking, stateful testing (Commands API), test execution and parameters
- **references/law-checking.md** — Complete Discipline law sets (Semigroup, Monoid, Functor, Applicative, Monad), manual law verification, specs2 law integration, custom law definitions
