# Law Checking Reference

Complete guide to type class law verification with Discipline, cats-laws, and specs2. Covers all standard law sets (Semigroup, Monoid, Functor, Applicative, Monad), manual verification patterns, specs2 integration, and custom law definitions. Supplements the main skill.

## Standard Law Sets with cats-laws

### Setup

```scala
import munit.DisciplineSuite
import cats.kernel.laws.discipline._
import cats.laws.discipline._
import cats.implicits._
```

### Semigroup Laws

A Semigroup must satisfy **associativity**: `(a |+| b) |+| c == a |+| (b |+| c)`

```scala
class SemigroupLawSpec extends DisciplineSuite {
  // Check associativity for Int addition
  checkAll("Int.Semigroup", SemigroupTests[Int].semigroup)

  // Check for custom type
  case class Concat(value: String)
  implicit val sg: Semigroup[Concat] = Semigroup.instance(
    (a, b) => Concat(a.value + b.value)
  )
  implicit val arb: Arbitrary[Concat] = Arbitrary(
    Gen.alphaStr.map(Concat(_))
  )
  implicit val eq: Eq[Concat] = Eq.fromUniversalEquals

  checkAll("Concat.Semigroup", SemigroupTests[Concat].semigroup)
}
```

### Monoid Laws

A Monoid extends Semigroup with **left identity** and **right identity**: `empty |+| a == a` and `a |+| empty == a`

```scala
class MonoidLawSpec extends DisciplineSuite {
  checkAll("Int.Monoid", MonoidTests[Int].monoid)
  checkAll("List[Int].Monoid", MonoidTests[List[Int]].monoid)
  checkAll("String.Monoid", MonoidTests[String].monoid)
  checkAll("Set[Int].Monoid", MonoidTests[Set[Int]].monoid)
}
```

### Functor Laws

A Functor must satisfy:
- **Identity**: `fa.map(identity) == fa`
- **Composition**: `fa.map(f).map(g) == fa.map(f.andThen(g))`

```scala
class FunctorLawSpec extends DisciplineSuite {
  // Requires Eq[Option[A]] and Arbitrary[Option[A]] (provided by cats)
  checkAll("Option.Functor", FunctorTests[Option].functor[Int, Int, String])

  // For custom functor
  case class Box[A](value: A)
  implicit val functorBox: Functor[Box] = new Functor[Box] {
    def map[A, B](fa: Box[A])(f: A => B): Box[B] = Box(f(fa.value))
  }
  implicit def arbBox[A](implicit arbA: Arbitrary[A]): Arbitrary[Box[A]] =
    Arbitrary(arbA.arbitrary.map(Box(_)))
  implicit def eqBox[A](implicit eqA: Eq[A]): Eq[Box[A]] =
    Eq.by(_.value)

  checkAll("Box.Functor", FunctorTests[Box].functor[Int, Int, String])
}
```

### Applicative Laws

An Applicative must satisfy:
- **Identity**: `pure(identity).ap(fa) == fa`
- **Composition**: `pure(compose).ap(ff).ap(fg).ap(fa) == ff.ap(fg.ap(fa))`
- **Homomorphism**: `pure(f).ap(pure(a)) == pure(f(a))`
- **Interchange**: `ff.ap(pure(a)) == pure((f: A => B) => f(a)).ap(ff)`

```scala
class ApplicativeLawSpec extends DisciplineSuite {
  checkAll("Option.Applicative",
    ApplicativeTests[Option].applicative[Int, Int, String])

  checkAll("List.Applicative",
    ApplicativeTests[List].applicative[Int, Int, String])
}
```

### Monad Laws

A Monad must satisfy:
- **Left identity**: `pure(a).flatMap(f) == f(a)`
- **Right identity**: `fa.flatMap(pure) == fa`
- **Associativity**: `fa.flatMap(f).flatMap(g) == fa.flatMap(a => f(a).flatMap(g))`

```scala
class MonadLawSpec extends DisciplineSuite {
  checkAll("Option.Monad",
    MonadTests[Option].monad[Int, Int, String])

  checkAll("List.Monad",
    MonadTests[List].monad[Int, Int, String])

  // Also inherits Applicative + Functor laws
  checkAll("Option.Monad (with base laws)",
    MonadTests[Option].monad[Int, Int, String])
}
```

### Additional Law Sets

```scala
// FlatMap: associativity + tailRecM consistency
checkAll("Option.FlatMap", FlatMapTests[Option].flatMap[Int, Int, String])

// Traverse: identity + composition + sequence fusion
checkAll("List.Traverse", TraverseTests[List].traverse[Int, Int, String, Int])

// Foldable: left/right fold consistency
checkAll("List.Foldable", FoldableTests[List].foldable[Int, Int])

// Alternative: monoid + applicative
checkAll("List.Alternative", AlternativeTests[List].alternative[Int, Int, String])

// MonadError: monad + error handling
checkAll("Either[String, *].MonadError",
  MonadErrorTests[Either[String, *], String].monadError[Int, Int, String])

// Semigroupal: compatibility with product + map
checkAll("Option.Semigroupal", SemigroupalTests[Option].semigroupal[Int, Int, String])
```

## Manual Law Verification

Use when Discipline isn't available or for non-cats type classes.

### Monoid Laws (Manual)

```scala
import org.specs2.mutable.Specification
import org.specs2.scalacheck.Prop.forAll
import cats.Monoid
import cats.implicits._

class ManualMonoidSpec extends Specification {
  "Monoid[Int]" should {
    "associativity" in forAll { (a: Int, b: Int, c: Int) =>
      (a |+| b) |+| c must_=== a |+| (b |+| c)
    }
    "left identity" in forAll { (a: Int) =>
      Monoid[Int].empty |+| a must_=== a
    }
    "right identity" in forAll { (a: Int) =>
      a |+| Monoid[Int].empty must_=== a
    }
  }
}
```

### Functor Laws (Manual)

```scala
class ManualFunctorSpec extends Specification {
  "Functor[Option]" should {
    "identity" in forAll { (fa: Option[Int]) =>
      fa.map(identity) must_=== fa
    }
    "composition" in forAll { (fa: Option[Int],
      f: Int => String, g: String => Boolean) =>
      fa.map(f).map(g) must_=== fa.map(f.andThen(g))
    }
  }
}
```

### Monad Laws (Manual)

```scala
class ManualMonadSpec extends Specification {
  "Monad[Option]" should {
    "left identity" in forAll { (a: Int, f: Int => Option[String]) =>
      Option(a).flatMap(f) must_=== f(a)
    }
    "right identity" in forAll { (fa: Option[Int]) =>
      fa.flatMap(Option(_)) must_=== fa
    }
    "associativity" in forAll { (fa: Option[Int],
      f: Int => Option[String], g: String => Option[Boolean]) =>
      fa.flatMap(f).flatMap(g) must_=== fa.flatMap(a => f(a).flatMap(g))
    }
  }
}
```

## specs2 Law Integration

### Using specs2 with Discipline

```scala
import org.specs2.mutable.Specification
import org.typelevel.discipline.specs2.mutable.Discipline
import cats.kernel.laws.discipline.MonoidTests

class Specs2MonoidSpec extends Specification with Discipline {
  checkAll("Int.Monoid", MonoidTests[Int].monoid)
}
```

### specs2-Style Property Law Checking

```scala
import org.specs2.ScalaCheck
import org.specs2.mutable.Specification

class Specs2PropertyLawSpec extends Specification with ScalaCheck {
  "Semigroup laws" ! prop { (a: String, b: String, c: String) =>
    // Associativity
    (a |+| b) |+| c must_=== a |+| (b |+| c)
  }

  "Monoid laws" should {
    "left identity" ! prop { (a: String) =>
      Monoid[String].empty |+| a must_=== a
    }
    "right identity" ! prop { (a: String) =>
      a |+| Monoid[String].empty must_=== a
    }
  }
}
```

## Custom Law Definitions

### Defining a Law Set with Discipline

```scala
import org.typelevel.discipline.Laws
import org.scalacheck.Prop.forAll
import cats.Eq

// Define laws for a custom type class
trait BoundedLaws[A] extends Laws {
  def bounded: RuleSet = new RuleSet {
    val name = "bounded"
    val bases = Nil
    val parents = Nil
    val props = Seq(
      "min <= max" -> forAll { (a: A) =>
        implicitly[Bounded[A]].min <= a &&
        a <= implicitly[Bounded[A]].max
      },
      "clamp within bounds" -> forAll { (a: A) =>
        val clamped = implicitly[Bounded[A]].clamp(a)
        clamped >= implicitly[Bounded[A]].min &&
        clamped <= implicitly[Bounded[A]].max
      }
    )
  }
}

object BoundedLaws {
  def apply[A: Bounded: Arbitrary: Eq]: BoundedLaws[A] =
    new BoundedLaws[A] {}
}
```

### Hierarchical Law Sets

```scala
// Parent laws
trait AdditiveSemigroupLaws[A] extends Laws {
  def additive: RuleSet = new RuleSet {
    val name = "additiveSemigroup"
    val bases = Nil
    val parents = Nil
    val props = Seq(
      "commutative" -> forAll { (a: A, b: A) =>
        add(a, b) == add(b, a)
      }
    )
  }
  def add(a: A, b: A): A
}

// Child laws inherit parent
trait AdditiveMonoidLaws[A] extends AdditiveSemigroupLaws[A] {
  override def additive: RuleSet = new RuleSet {
    val name = "additiveMonoid"
    val bases = Seq("additiveSemigroup" -> super.additive)
    val parents = Seq(super.additive)
    val props = Seq(
      "identity" -> forAll { (a: A) =>
        add(a, zero) == a && add(zero, a) == a
      }
    )
  }
  def zero: A
}
```

### Testing Custom Laws

```scala
import munit.DisciplineSuite

class BoundedIntSpec extends DisciplineSuite {
  implicit val boundedInt: Bounded[Int] = new Bounded[Int] {
    def min: Int = 0
    def max: Int = 100
    def clamp(a: Int): Int = math.max(min, math.min(a, max))
  }

  // Check custom laws
  checkAll("Bounded[Int]", BoundedLaws[Int].bounded)
}
```

## Required Instances for Law Checking

Discipline law checks require these type class instances:

| Law Check | Required Instances |
|---|---|
| `SemigroupTests[A].semigroup` | `Semigroup[A]`, `Arbitrary[A]`, `Eq[A]` |
| `MonoidTests[A].monoid` | `Monoid[A]`, `Arbitrary[A]`, `Eq[A]` |
| `FunctorTests[F].functor` | `Functor[F]`, `Arbitrary[K]` for 3 types, `Eq[F[K]]` |
| `ApplicativeTests[F].applicative` | `Applicative[F]`, same as Functor + `Eq[K => K]` |
| `MonadTests[F].monad` | `Monad[F]`, same as Applicative |
| `TraverseTests[F].traverse` | `Traverse[F]`, `Applicative[F]`, multiple `Arbitrary`/`Eq` |

### Providing Instances for Custom Types

```scala
case class Wrapper(value: Int)

// Eq — structural equality
implicit val eqWrapper: Eq[Wrapper] = Eq.by(_.value)

// Arbitrary — random generation
implicit val arbWrapper: Arbitrary[Wrapper] =
  Arbitrary(Gen.choose(0, 100).map(Wrapper(_)))

// Shrink — minimize failing cases
implicit val shrinkWrapper: Shrink[Wrapper] =
  Shrink.shrinkIntegral.map(Wrapper(_))

// Now law checks work
checkAll("Wrapper.Monoid", MonoidTests[Wrapper].monoid)
```

## Law Checking with Function Generators

Higher-kinded laws need `Arbitrary` for functions:

```scala
import cats.laws.discipline.eq._
import cats.laws.discipline.arbitrary._

// cats-laws provides these for common types:
// Arbitrary[Int => Int], Eq[Option[Int]], etc.

// For custom function types:
implicit def arbFunction[A: Arbitrary, B: Arbitrary]: Arbitrary[A => B] =
  Arbitrary(for {
    b <- Arbitrary.arbitrary[B]
  } yield (_: A) => b)

// Use ExhaustiveCheck for finite-domain functions (enums)
import cats.laws.discipline.ExhaustiveCheck
```

## Dependencies

```scala
// cats-laws provides FunctorTests, ApplicativeTests, MonadTests, etc.
libraryDependencies += "org.typelevel" %% "cats-laws" % "2.+" % Test

// cats-kernel-laws provides SemigroupTests, MonoidTests, etc.
libraryDependencies += "org.typelevel" %% "cats-kernel-laws" % "2.+" % Test

// discipline-core — law definition framework
libraryDependencies += "org.typelevel" %% "discipline-core" % "1.7.+" % Test

// Integration with test framework (pick one):
libraryDependencies += "org.typelevel" %%% "discipline-munit" % "2.0.+" % Test
libraryDependencies += "org.typelevel" %% "discipline-specs2" % "1.7.+" % Test
```
